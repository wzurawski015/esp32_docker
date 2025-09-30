#!/usr/bin/env bash
set -euo pipefail
docker volume create esp-idf-espressif >/dev/null
docker volume create esp-idf-ccache >/dev/null
echo "Volumes ready (esp-idf-espressif, esp-idf-ccache)."
