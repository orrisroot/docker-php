#!/bin/bash

IMAGE=orrisroot/php
REGISTORY=docker.io/${IMAGE}
ENGINE=${ENGINE:-podman}
export ENGINE
VERSIONS=("8.2" "8.3" "8.4" "8.5")
FLAVORS=("apache" "fpm")

# Serial by default: parallel builds race on Docker Hub token requests and
# transiently fail. Raise it with MAX_PARALLEL if you must parallelize.
MAX_PARALLEL=${MAX_PARALLEL:-1}

cd $(dirname $0)

[ ! -d logs ] && mkdir -p logs

wait_jobs () {
  local pid rc=0
  for pid in "$@"; do
    wait ${pid} || rc=1
  done
  return ${rc}
}

JOBS=()
ITER=0
FAIL=0
for VERSION in "${VERSIONS[@]}"; do
  for FLAVOR in "${FLAVORS[@]}"; do
    ./build.sh ${VERSION} ${FLAVOR} > logs/${VERSION}-${FLAVOR}.log 2>&1 &
    JOBS+=("$!")
    ITER=$(( ITER + 1 ))
    if [ ${ITER} -ge ${MAX_PARALLEL} ]; then
      wait_jobs "${JOBS[@]}" || FAIL=1
      JOBS=()
      ITER=0
    fi
  done
done
wait_jobs "${JOBS[@]}" || FAIL=1

if [ ${FAIL} -ne 0 ]; then
  echo "Some builds failed. See logs/ for the details." 1>&2
  exit 1
fi

echo Done! To push all built images to Docker Hub:
echo "  ${ENGINE} login"
echo "  ./push-all.sh"
