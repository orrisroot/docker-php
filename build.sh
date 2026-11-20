#!/bin/bash

set -euo pipefail

IMAGE="docker.io/orrisroot/php"
ENGINE="${ENGINE:-podman}"
DIR=$(cd "$(dirname "$0")" && pwd)
VERSION="${1:-}"
FLAVOR="${2:-}"

usage () {
  echo "Usage: $(basename "$0") VERSION FLAVOR" >&2
  echo "Available targets:" >&2
  for dockerfile in "${DIR}"/[0-9]*/*/Dockerfile; do
    [ -f "${dockerfile}" ] || continue
    local flavor_dir
    flavor_dir=$(dirname "${dockerfile}")
    echo "  $(basename "$(dirname "${flavor_dir}")") $(basename "${flavor_dir}")" >&2
  done
}

if [ "${ENGINE}" != "podman" ] && [ "${ENGINE}" != "docker" ]; then
  echo "Error: ENGINE must be podman or docker (got '${ENGINE}')." >&2
  exit 2
fi

if ! [[ "${VERSION}" =~ ^[0-9]+\.[0-9]+$ ]] \
  || ! [[ "${FLAVOR}" =~ ^[a-z0-9-]+$ ]] \
  || [ ! -f "${DIR}/${VERSION}/${FLAVOR}/Dockerfile" ]; then
  usage
  exit 1
fi

TARGET_DIR="${DIR}/${VERSION}/${FLAVOR}"
TAG="${VERSION}-${FLAVOR}"

if ! "${ENGINE}" build --force-rm -t "${IMAGE}:${TAG}" "${TARGET_DIR}"; then
  echo "Build error occurred." >&2
  exit 1
fi

FULL_VERSION=$("${ENGINE}" run --rm "${IMAGE}:${TAG}" php -r 'echo PHP_VERSION;')
version_regex="^${VERSION//./\\.}\\.[0-9]+$"
if ! [[ "${FULL_VERSION}" =~ ${version_regex} ]]; then
  echo "Unexpected PHP version '${FULL_VERSION}' for ${TAG}." >&2
  exit 1
fi

"${ENGINE}" tag "${IMAGE}:${TAG}" "${IMAGE}:${FULL_VERSION}-${FLAVOR}"

echo ""
echo "Done! Built ${IMAGE}:${TAG} and ${IMAGE}:${FULL_VERSION}-${FLAVOR}."
