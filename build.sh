#!/bin/bash

set -e

IMAGE=orrisroot/php
REGISTORY=docker.io/${IMAGE}
ENGINE=${ENGINE:-podman}
VERSIONS=("8.2" "8.3" "8.4" "8.5")
FLAVORS=("apache" "fpm")

VERSION=$1
FLAVOR=$2

build_image () {
  local TAG="${VERSION}-${FLAVOR}"
  pushd ${VERSION}/${FLAVOR}
  ${ENGINE} build --pull --force-rm --progress=plain -t ${REGISTORY}:${TAG} .
  local IMAGE_ID=$(${ENGINE} images ${REGISTORY}:${TAG} -q)
  local VERSION_=$(${ENGINE} run --rm -t ${REGISTORY}:${TAG} php -r "echo phpversion();")
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

build_image ${IMAGE} ${VERSION} ${FLAVOR}

echo Done! To push built images, run the following command.
echo ${ENGINE} login
if [ "${ENGINE}" = "docker" ]; then
  echo ${ENGINE} image push --all-tags ${REGISTORY}
else
  echo ${ENGINE} push ${REGISTORY}:${VERSION}-${FLAVOR}
fi

