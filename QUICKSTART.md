# ESP32 Docker Quick Reference

## Quick Start Commands

```bash
# Build the Docker image
make build

# Open a shell in the container
make shell

# Inside the container - Build the project
cd /project
idf.py set-target esp32
idf.py build

# Flash to device (from host)
make flash PORT=/dev/ttyUSB0

# Monitor serial output (from host)
make monitor PORT=/dev/ttyUSB0
```

## Common idf.py Commands

```bash
# Set the target chip
idf.py set-target esp32       # ESP32
idf.py set-target esp32s2     # ESP32-S2
idf.py set-target esp32s3     # ESP32-S3
idf.py set-target esp32c3     # ESP32-C3
idf.py set-target esp32c6     # ESP32-C6

# Build the project
idf.py build

# Clean the build
idf.py clean
idf.py fullclean

# Flash the device
idf.py -p /dev/ttyUSB0 flash

# Monitor serial output
idf.py -p /dev/ttyUSB0 monitor

# Flash and monitor
idf.py -p /dev/ttyUSB0 flash monitor

# Configure the project
idf.py menuconfig

# Get project info
idf.py size
idf.py size-components
idf.py size-files
```

## Docker Commands

```bash
# Build the image
docker compose build

# Run a shell
docker compose run --rm esp32-dev

# Stop all containers
docker compose down

# Remove volumes
docker compose down -v

# View logs
docker compose logs esp32-dev
```

## Finding USB Device

```bash
# Linux
ls /dev/ttyUSB*
ls /dev/ttyACM*

# macOS
ls /dev/cu.*

# Check permissions (Linux)
ls -l /dev/ttyUSB0
```

## Troubleshooting

### Can't access USB device
```bash
# Add user to dialout group (Linux)
sudo usermod -a -G dialout $USER
# Log out and log back in
```

### Build fails
```bash
# Clean and rebuild
cd /project
idf.py fullclean
idf.py build
```

### Container can't find device
```bash
# Check device exists
ls -l /dev/ttyUSB0

# Update docker-compose.yml to match your device
```

## Project Structure

```
project/
├── CMakeLists.txt          # Project build configuration
├── main/
│   ├── CMakeLists.txt      # Main component configuration
│   └── main.c              # Application entry point
└── components/             # Custom components (optional)
```

## Useful ESP-IDF Links

- Documentation: https://docs.espressif.com/projects/esp-idf/
- API Reference: https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-reference/
- Examples: https://github.com/espressif/esp-idf/tree/master/examples
- Forum: https://www.esp32.com/
