#!/bin/bash

# Monitor script for ESP32 project
# Run this inside the Docker container

set -e

PORT=${1:-/dev/ttyUSB0}

echo "Monitoring ESP32 on port $PORT..."
echo "Press Ctrl+] to exit"

cd /project

# Monitor the serial output
idf.py -p $PORT monitor
