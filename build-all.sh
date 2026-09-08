#!/bin/bash

IMAGE=orrisroot/php
REGISTORY=docker.io/${IMAGE}
ENGINE=${ENGINE:-podman}
export ENGINE
VERSIONS=("8.2" "8.3" "8.4")
FLAVORS=("apache" "fpm")

cd $(dirname $0)

[ ! -d logs ] && mkdir -p logs

for VERSION in "${VERSIONS[@]}"; do
  for FLAVOR in "${FLAVORS[@]}"; do
    ./build.sh ${VERSION} ${FLAVOR} > logs/${VERSION}-${FLAVOR}.log 2>&1 &
  done
done

wait

echo Done! To push built images, run the following command.
echo ${ENGINE} login
if [ "${ENGINE}" = "docker" ]; then
  echo ${ENGINE} image push --all-tags ${REGISTORY}
else
  echo ${ENGINE} push ${REGISTORY}:VERSION-FLAVOR
fi
