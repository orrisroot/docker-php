#!/bin/bash

# Push all locally built orrisroot/php images to Docker Hub.
# Skips a tag when the copy on Docker Hub is newer (build date) than local.
# Options:
#   ONLY_VERSIONED=1  only the 8.x.y-{flavor} tags
#   ONLY_MAJOR=1      only the 8.x-{flavor} tags
#   DRY_RUN=1         list tags without pushing
#   FORCE=1           push even if the remote is newer
#   SKIP_STALE_CHECK=1  don't compare with the remote
# Requires: podman login docker.io  (or: docker login)

set -e

IMAGE=orrisroot/php
REGISTORY=docker.io/${IMAGE}
ENGINE=${ENGINE:-podman}

if [ "${ENGINE}" != "podman" ] && [ "${ENGINE}" != "docker" ]; then
  echo "Error: ENGINE must be podman or docker (got '${ENGINE}')." 1>&2
  exit 2
fi

# Auth file for skopeo (same approach as check.sh).
SKOPEO_OPTS="--retry-times 3 --retry-delay 5s"
AUTH_FILE=""
if command -v skopeo > /dev/null 2>&1; then
  for F in "${XDG_RUNTIME_DIR}/containers/auth.json" \
           "${HOME}/.config/containers/auth.json" \
           "${HOME}/.docker/config.json"; do
    if [ -f "${F}" ] \
      && command -v jq > /dev/null 2>&1 \
      && jq -e '.auths["https://index.docker.io/v1/"]' "${F}" > /dev/null 2>&1; then
      AUTH_FILE=$(mktemp)
      jq '{auths: {"https://index.docker.io/v1/": .auths["https://index.docker.io/v1/"]}}' \
        "${F}" > "${AUTH_FILE}"
      SKOPEO_OPTS="--authfile ${AUTH_FILE} ${SKOPEO_OPTS}"
      trap "rm -f ${AUTH_FILE}" EXIT
      break
    fi
  done
fi

# Collect local tags (8.x-{flavor} and 8.x.y-{flavor}).
mapfile -t ALL_TAGS < <(
  ${ENGINE} images --format '{{.Repository}}:{{.Tag}}' \
    | grep "^${REGISTORY}:" \
    | sed -E 's#^docker.io/##' \
    | sed 's#^[^:]*:##' \
    | sort
)

if [ ${#ALL_TAGS[@]} -eq 0 ]; then
  echo "Error: no local images tagged ${REGISTORY}:* found." >&2
  echo "Build first, e.g. ./build-all.sh" >&2
  exit 1
fi

TAGS=()
for TAG in "${ALL_TAGS[@]}"; do
  is_versioned=0
  is_major=0
  [[ "${TAG}" =~ ^[0-9]+\.[0-9]+\.[0-9]+- ]] && is_versioned=1
  [[ "${TAG}" =~ ^[0-9]+\.[0-9]+- ]] && is_major=1

  case "${ONLY_VERSIONED:-0}${ONLY_MAJOR:-0}" in
    10) [ ${is_versioned} -eq 1 ] && TAGS+=("${TAG}") ;;
    01) [ ${is_major} -eq 1 ] && TAGS+=("${TAG}") ;;
    *)  TAGS+=("${TAG}") ;;
  esac
done

echo "Pushing ${#TAGS[@]} tags for ${REGISTORY} (ENGINE=${ENGINE}):"
for TAG in "${TAGS[@]}"; do
  echo "  ${TAG}"
done

if [ "${DRY_RUN:-0}" = "1" ]; then
  echo "(dry run - not pushing)"
  exit 0
fi

# Return 0 (skip) when the remote copy is newer than local, else 1 (push).
need_push () {
  local TAG=$1
  [ "${SKIP_STALE_CHECK:-0}" = "1" ] && return 1
  [ "${FORCE:-0}" = "1" ] && return 1
  command -v skopeo > /dev/null 2>&1 || { echo "  (skopeo not found - pushing without comparison)" >&2; return 1; }

  local LOCAL_CREATED REMOTE_CREATED
  if command -v jq > /dev/null 2>&1; then
    LOCAL_CREATED=$(${ENGINE} image inspect "${REGISTORY}:${TAG}" 2>/dev/null | jq -r '.[0].Created')
  else
    LOCAL_CREATED=$(${ENGINE} image inspect "${REGISTORY}:${TAG}" --format '{{.Created}}' 2>/dev/null)
  fi
  [ -n "${LOCAL_CREATED}" ] || return 1

  REMOTE_CREATED=$(skopeo inspect --config ${SKOPEO_OPTS} \
    "docker://${REGISTORY}:${TAG}" 2>/dev/null | jq -r '.created // empty')
  [ -n "${REMOTE_CREATED}" ] || { echo "  (no remote tag ${TAG} - pushing)" >&2; return 1; }

  local LOCAL_EPOCH REMOTE_EPOCH
  LOCAL_EPOCH=$(date -d "${LOCAL_CREATED}" +%s 2>/dev/null || echo "")
  REMOTE_EPOCH=$(date -d "${REMOTE_CREATED}" +%s 2>/dev/null || echo "")
  [ -n "${LOCAL_EPOCH}" ] && [ -n "${REMOTE_EPOCH}" ] || return 1

  if [ "${REMOTE_EPOCH}" -gt "${LOCAL_EPOCH}" ]; then
    echo "  remote (${REMOTE_CREATED}) is NEWER than local (${LOCAL_CREATED}) - skipping ${TAG}" >&2
    return 0
  fi
  return 1
}

FAIL=0
SKIPPED=0
PUSHED=0
for TAG in "${TAGS[@]}"; do
  if need_push "${TAG}"; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi
  echo "Pushing ${REGISTORY}:${TAG} ..."
  if ! ${ENGINE} push "${REGISTORY}:${TAG}"; then
    echo "  push of ${TAG} failed" >&2
    FAIL=1
    continue
  fi
  PUSHED=$((PUSHED + 1))
done

echo ""
echo "Pushed: ${PUSHED}, skipped (remote is newer): ${SKIPPED}"
if [ ${FAIL} -ne 0 ]; then
  echo "Some pushes failed." >&2
  exit 1
fi

echo "All ${#TAGS[@]} images pushed."
