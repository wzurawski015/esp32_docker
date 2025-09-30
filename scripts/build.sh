#!/bin/bash

# Build script for ESP32 project
# Run this inside the Docker container

set -e

echo "Building ESP32 project..."

cd /project

# Configure the project if needed
if [ ! -f "sdkconfig" ]; then
    echo "Running menuconfig for first-time setup..."
    idf.py set-target esp32
fi

# Build the project
idf.py build

echo "Build completed successfully!"
