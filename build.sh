#!/bin/bash

set -e

IMAGE=orrisroot/php
REGISTORY=docker.io/${IMAGE}
ENGINE=${ENGINE:-podman}
VERSIONS=("8.2" "8.3" "8.4" "8.5")
FLAVORS=("apache" "fpm")

VERSION=$1
FLAVOR=$2

# Pull only when the base image changed (newer), or always with PULL_POLICY=always.
PULL_POLICY=${PULL_POLICY:-newer}
# Abort when fewer than MIN_REMAINING Docker Hub pulls remain.
MIN_REMAINING=${MIN_REMAINING:-20}
# Retry on transient Docker Hub auth errors.
RETRIES=${RETRIES:-3}
RETRY_DELAY=${RETRY_DELAY:-15}
AUTH_FAILURE_PATTERN='unable to retrieve auth token: invalid username/password: unauthorized|too many requests to registry'

check_rate_limit () {
  local headers remain limit source token tmp code base
  [ "${SKIP_RATE_CHECK}" = "1" ] && return 0
  command -v curl > /dev/null 2>&1 || return 0

  base="library/php:${VERSION}-${FLAVOR}"
  tmp=$(mktemp)
  trap "rm -f ${tmp}" EXIT

  # Try an authenticated token once; fall back to an anonymous token on
  # any failure (retrying with bad credentials would waste the quota).
  token=""
  auth_entry=""
  if command -v jq > /dev/null 2>&1; then
    for f in "${XDG_RUNTIME_DIR}/containers/auth.json" \
             "${HOME}/.config/containers/auth.json" \
             "${HOME}/.docker/config.json"; do
      [ -f "${f}" ] || continue
      auth_entry=$(jq -r '.auths["https://index.docker.io/v1/"].auth // empty' "${f}" 2>/dev/null)
      [ -n "${auth_entry}" ] && break
    done
  fi

  if [ -n "${auth_entry}" ]; then
    code=$(curl -s -o "${tmp}" -w '%{http_code}' \
      -H "Authorization: Basic ${auth_entry}" \
      "https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/php:pull")
    if [ "${code}" = "200" ]; then
      token=$(sed -n 's/.*"token":"\([^"]*\)".*/\1/p' "${tmp}")
    else
      echo "Warning: Docker Hub credentials rejected (HTTP ${code}); using the anonymous quota for the rate check." >&2
    fi
  fi

  if [ -z "${token}" ]; then
    code=$(curl -s -o "${tmp}" -w '%{http_code}' \
      "https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/php:pull")
    [ "${code}" = "200" ] || { echo "Warning: failed to obtain a Docker Hub token; skipping rate-limit check." >&2; rm -f "${tmp}"; trap - EXIT; return 0; }
    token=$(sed -n 's/.*"token":"\([^"]*\)".*/\1/p' "${tmp}")
  fi

  headers=$(curl -sI -H "Authorization: Bearer ${token}" \
    "https://registry-1.docker.io/v2/${base}/manifests/$(echo ${base} | cut -d: -f2)")

  remain=$(printf '%s\n' "${headers}" | grep -i '^ratelimit-remaining:' | head -1 | tr -d '\r' | awk -F'[:;]' '{gsub(/ /,"",$2); print $2}')
  limit=$(printf '%s\n' "${headers}" | grep -i '^ratelimit-limit:' | head -1 | tr -d '\r' | awk -F'[:;]' '{gsub(/ /,"",$2); print $2}')
  source=$(printf '%s\n' "${headers}" | grep -i '^docker-ratelimit-source:' | head -1 | tr -d '\r' | awk -F': ' '{print $2}')

  if [ -z "${remain}" ]; then
    echo "Warning: no rate-limit header returned; skipping the quota guard." >&2
  else
    echo "Docker Hub pull rate limit: ${remain} remaining of ${limit} (${source})" >&2
    if [ "${remain}" -lt "${MIN_REMAINING}" ]; then
      echo "Error: Docker Hub pull rate limit nearly exhausted (${remain} left < ${MIN_REMAINING}); aborting." >&2
      echo "Wait for the window to reset, log in with a valid account, or upgrade the Docker Hub subscription." >&2
      rm -f "${tmp}"
      trap - EXIT
      exit 2
    fi
  fi
  rm -f "${tmp}"
  trap - EXIT
}

build_image () {
  local TAG="${VERSION}-${FLAVOR}"
  local PULL_OPT attempt rc logfile IMAGE_ID VERSION_
  pushd ${VERSION}/${FLAVOR}

  if [ "${ENGINE}" = "podman" ]; then
    PULL_OPT="--pull=${PULL_POLICY}"
  else
    PULL_OPT=""
    [ "${PULL_POLICY}" = "always" ] && PULL_OPT="--pull"
  fi

  logfile=$(mktemp)
  for attempt in $(seq 0 ${RETRIES}); do
    # shellcheck disable=SC2086
    if ${ENGINE} build ${PULL_OPT} --force-rm --progress=plain \
         -t ${REGISTORY}:${TAG} . > "${logfile}" 2>&1; then
      break
    fi
    rc=$?
    tail -20 "${logfile}" >&2
    if [ ${attempt} -ge ${RETRIES} ] \
       || ! grep -qE "${AUTH_FAILURE_PATTERN}" "${logfile}"; then
      rm -f "${logfile}"
      popd
      return ${rc}
    fi
    echo "Transient Docker Hub auth error; retry $((attempt+1))/${RETRIES} after ${RETRY_DELAY}s ..." >&2
    sleep ${RETRY_DELAY}
  done
  rm -f "${logfile}"

  IMAGE_ID=$(${ENGINE} images ${REGISTORY}:${TAG} -q)
  VERSION_=$(${ENGINE} run --rm -t ${REGISTORY}:${TAG} php -r "echo phpversion();")
  ${ENGINE} tag ${IMAGE_ID} ${REGISTORY}:${VERSION_}-${FLAVOR}
  popd
}

usage () {
  echo "Usage: $(basename $1) VERSION FLAVOR"
  echo "options:"
  echo -n "  - VERSION: "
  echo "${VERSIONS[*]}" | sed -e 's/ /, /g'
  echo -n "  - FLAVOR:  "
  echo "${FLAVORS[*]}" | sed -e 's/ /, /g'
}

cd $(dirname $0)
ROOT_DIR=$(pwd)

# Per-target lock: serialize same-target builds (overlapping runs).
LOCK_DIR="${ROOT_DIR}/.locks"
LOCKFILE="${LOCK_DIR}/${VERSION}-${FLAVOR}.lock"
mkdir -p "${LOCK_DIR}"
LOCK_OPTS=""
[ -n "${LOCK_TIMEOUT}" ] && LOCK_OPTS="-w ${LOCK_TIMEOUT}"

# Skip rebuild when inputs are unchanged since the last successful build.
SKIP_IF_UNCHANGED=${SKIP_IF_UNCHANGED:-1}
STATE_DIR="${ROOT_DIR}/.state"
STATE_FILE="${STATE_DIR}/${VERSION}-${FLAVOR}"
mkdir -p "${STATE_DIR}"

# Fingerprint: FROM line + build context + local base image ID.
compute_fingerprint () {
  local dir="${VERSION}/${FLAVOR}"
  local from_line from_ref local_id base_ctx
  from_line=$(grep -m1 '^FROM ' "${dir}/Dockerfile")
  from_ref=$(echo "${from_line}" | awk '{print $2}')
  local_id=$(${ENGINE} image inspect --format '{{.Id}}' "${from_ref}" 2>/dev/null || echo "base-not-local")
  base_ctx=$(find "${dir}" -type f | sort | xargs -r sha256sum | sha256sum | cut -d' ' -f1)
  printf '%s\n%s\n%s\n' "${from_line}" "${local_id}" "${base_ctx}" | sha256sum | cut -d' ' -f1
}

if [ "${ENGINE}" != "podman" ] && [ "${ENGINE}" != "docker" ]; then
  echo "Error: ENGINE must be podman or docker (got '${ENGINE}')." 1>&2
  exit 2
fi

if ! (printf '%s\n' "${VERSIONS[@]}" | grep -qx "${VERSION}"); then
  usage $0
  exit 1
fi
if ! (printf '%s\n' "${FLAVORS[@]}" | grep -qx "${FLAVOR}"); then
  usage $0
  exit 1
fi

check_rate_limit

# Acquire the per-target lock (released on exit / Ctrl-C).
exec {LOCK_FD}>"${LOCKFILE}"
if ! flock ${LOCK_OPTS} ${LOCK_FD}; then
  echo "Error: another build of ${VERSION}-${FLAVOR} is still running; gave up after ${LOCK_TIMEOUT}s." >&2
  exit 3
fi

release_lock () {
  flock -u ${LOCK_FD} 2>/dev/null || true
  exec {LOCK_FD}>&- 2>/dev/null || true
}
trap release_lock EXIT INT TERM

skip_if_unchanged () {
  [ "${SKIP_IF_UNCHANGED}" = "1" ] || return 1
  [ "${PULL_POLICY}" = "always" ] && return 1
  [ -f "${STATE_FILE}" ] || return 1
  local new_fp
  new_fp=$(compute_fingerprint)
  if [ "$(cat "${STATE_FILE}")" = "${new_fp}" ]; then
    echo "Nothing changed for ${VERSION}-${FLAVOR} since the last successful build; skipping." >&2
    return 0
  fi
  return 1
}

if skip_if_unchanged; then
  release_lock
  trap - EXIT INT TERM
  exit 0
fi

if build_image ${IMAGE} ${VERSION} ${FLAVOR}; then
  compute_fingerprint > "${STATE_FILE}"
else
  rc=$?
  release_lock
  trap - EXIT INT TERM
  exit ${rc}
fi
release_lock
trap - EXIT INT TERM

echo Done! To push all built images to Docker Hub:
echo "  ${ENGINE} login"
echo "  ./push-all.sh"
