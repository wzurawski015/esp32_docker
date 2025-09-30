#!/usr/bin/env bash
set -euo pipefail
IMG="${IMG:-esp32-idf:5.3-docs}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${ESPPORT:-}"
if [ -z "$PORT" ]; then
  if ! PORT="$("$ROOT/scripts/find-port.sh")"; then
    echo "Ustaw ESPPORT=/dev/ttyUSB0 (lub inny) i powtórz." >&2
    exit 1
  fi
fi
echo "Flash: $PORT"
docker run --rm -it \
  --device "$PORT:$PORT" \
  -v "$ROOT/firmware:/work" \
  -v esp-idf-espressif:/root/.espressif \
  -v esp-idf-ccache:/root/.cache/ccache \
  "$IMG" bash -lc "idf.py -p '$PORT' flash"
