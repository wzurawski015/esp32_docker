#!/bin/bash

# Flash script for ESP32 project
# Run this inside the Docker container

set -e

PORT=${1:-/dev/ttyUSB0}

echo "Flashing ESP32 on port $PORT..."

cd /project

# Flash the project
idf.py -p $PORT flash

echo "Flash completed successfully!"
echo "To monitor the output, run: idf.py -p $PORT monitor"
