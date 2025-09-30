#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IMG="${IMG:-esp32-idf:5.3-docs}"

"$SCRIPT_DIR/build-docker.sh"
"$SCRIPT_DIR/setup-volumes.sh"

docker run --rm -t \
  -v "$ROOT/firmware:/work" \
  -v esp-idf-espressif:/root/.espressif \
  -v esp-idf-ccache:/root/.cache/ccache \
  "$IMG" bash -lc 'idf.py set-target esp32c6 && idf.py build && idf.py size-components'

echo "Init complete. Firmware in firmware/build/"
