#!/bin/bash

IMAGE=orrisroot/php
REGISTORY=docker.io/${IMAGE}
VERSIONS=("7.4" "8.0" "8.1")
FLAVORS=("apache" "fpm")

VERSION=$1
FLAVOR=$2

build_image () {
  IMAGE=$1
  VERSION=$2
  TYPE=$3
  TAG="${VERSION}-${TYPE}"
  pushd ${VERSION}/${TYPE}
  docker build --pull --force-rm -t ${IMAGE}:${TAG} .
  IMAGE_ID=$(docker image ls ${IMAGE}:${TAG} -q)
  VERSION_=$(docker run --rm -it ${IMAGE}:${TAG} php -r "echo phpversion();")
  docker image tag ${IMAGE_ID} ${IMAGE}:${VERSION_}-${TYPE}
  popd
}

usage () {
  echo "Usage: $(basename $1) VERSION FLAVOR"
  echo "options:"
  echo "  - VERSION: 7.4, 8.0, 8.1"
  echo "  - FLAVOR:  apache, fpm"
}

cd $(dirname $0)

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
echo docker login
echo docker image push --all-tags ${IMAGE}

