#!/usr/bin/env bash
set -Eeuo pipefail

IMG="${IMG:-esp32-idf:5.3-docs}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${ROOT}/firmware"

PORT_ARGS=()
if [[ -n "${ESPPORT:-}" ]]; then
  PORT_ARGS+=(--device "${ESPPORT}:${ESPPORT}")
fi

exec docker run --rm -it \
  -e TERM=xterm-256color \
  -e IDF_CCACHE_ENABLE=1 \
  -v esp-idf-espressif:/opt/esp \
  -v esp-idf-ccache:/root/.ccache \
  -v "${WORK}:/work" \
  "${PORT_ARGS[@]}" \
  "${IMG}" bash -lc "idf.py $*"
