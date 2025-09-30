#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IMG="${IMG:-esp32-idf:5.3-docs}"

"$SCRIPT_DIR/build-docker.sh"
"$SCRIPT_DIR/setup-volumes.sh"

# Create initial firmware if missing
if [ ! -f "$ROOT/firmware/CMakeLists.txt" ]; then
  echo "Scaffolding minimal firmware..."
  mkdir -p "$ROOT/firmware/main"
  cat > "$ROOT/firmware/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.16)
include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(hello_esp32c6)
EOF
  cat > "$ROOT/firmware/main/CMakeLists.txt" <<'EOF'
idf_component_register(SRCS "main.c" INCLUDE_DIRS ".")
EOF
  cat > "$ROOT/firmware/main/main.c" <<'EOF'
#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"

void app_main(void) {
    while (1) {
        ESP_LOGI("HELLO", "Hello from ESP32-C6 (Docker build)!");
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}
EOF
fi

# Build firmware and print sizes
docker run --rm -t   -v "$ROOT/firmware:/work"   -v esp-idf-espressif:/root/.espressif   -v esp-idf-ccache:/root/.cache/ccache   "$IMG" bash -lc 'idf.py set-target esp32c6 && idf.py build && idf.py size-components'

echo "Init complete. Firmware in firmware/build/"
