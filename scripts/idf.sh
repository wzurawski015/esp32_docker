#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/firmware"

PORT_ARG=""
if [[ "${ESPPORT:-}" != "" ]]; then
  PORT_ARG="--device=${ESPPORT}:${ESPPORT}"
fi

docker run --rm -it \
  -e TERM=xterm-256color \
  -e IDF_CCACHE_ENABLE=1 \
  -v esp-idf-espressif:/root/.espressif \
  -v esp-idf-ccache:/root/.cache/ccache \
  -v "${PROJECT_DIR}:/work" \
  ${PORT_ARG} \
  esp32-idf:5.3-docs bash -lc "idf.py $*"

