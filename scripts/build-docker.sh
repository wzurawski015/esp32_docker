#!/usr/bin/env bash
set -euo pipefail
IMG="${IMG:-esp32-idf:5.3-docs}"
docker build -t "$IMG" -f Dockerfile .
echo "Built image: $IMG"
