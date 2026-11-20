#!/bin/bash

set -euo pipefail

DIR=$(cd "$(dirname "$0")" && pwd)

for dockerfile in "${DIR}"/[0-9]*/*/Dockerfile; do
  [ -f "${dockerfile}" ] || continue
  flavor_dir=$(dirname "${dockerfile}")
  flavor=$(basename "${flavor_dir}")
  version=$(basename "$(dirname "${flavor_dir}")")
  "${DIR}/build.sh" "${version}" "${flavor}"
done
