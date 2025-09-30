#!/usr/bin/env bash
set -euo pipefail
IMG="${IMG:-esp32-idf:5.3-docs}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
docker run --rm -it   -e TERM=xterm-256color   -v "$ROOT/firmware:/work"   -v esp-idf-espressif:/root/.espressif   -v esp-idf-ccache:/root/.cache/ccache   "$IMG" bash -lc 'idf.py menuconfig'
