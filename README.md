# ESP32 Docker Development Environment

A complete Docker-based development environment for ESP32 microcontroller projects using ESP-IDF framework.

## Features

- 🐳 Dockerized ESP-IDF development environment
- 📦 Pre-configured with ESP-IDF v5.1
- 🚀 Easy setup with Docker Compose
- 🔧 Includes build, flash, and monitor scripts
- 📝 Sample "Hello World" project included
- 🔄 Volume mounting for persistent development

## Prerequisites

- Docker (version 20.10 or higher)
- Docker Compose (version 1.29 or higher)
- USB connection to ESP32 device (for flashing)

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/wzurawski015/esp32_docker.git
cd esp32_docker
```

### 2. Build the Docker Image

```bash
docker-compose build
```

### 3. Start the Development Container

```bash
docker-compose run --rm esp32-dev
```

This will start a bash shell inside the container with all ESP-IDF tools available.

## Project Structure

```
esp32_docker/
├── Dockerfile              # Docker image definition
├── docker-compose.yml      # Docker Compose configuration
├── .dockerignore          # Files to exclude from Docker build
├── project/               # Your ESP32 project files
│   ├── CMakeLists.txt     # Project CMake configuration
│   └── main/              # Main application directory
│       ├── CMakeLists.txt # Component CMake configuration
│       └── main.c         # Main application code
└── scripts/               # Helper scripts
    ├── build.sh           # Build the project
    ├── flash.sh           # Flash to ESP32
    └── monitor.sh         # Monitor serial output
```

## Usage

### Building Your Project

Inside the Docker container:

```bash
cd /project
idf.py set-target esp32    # Or esp32s2, esp32s3, esp32c3, etc.
idf.py build
```

Or use the build script:

```bash
/scripts/build.sh
```

### Configuring Your Project

To configure project settings (e.g., WiFi credentials, GPIO pins):

```bash
cd /project
idf.py menuconfig
```

### Flashing to ESP32

Make sure your ESP32 is connected via USB. You may need to adjust the device path in `docker-compose.yml` (default is `/dev/ttyUSB0`).

Inside the Docker container:

```bash
idf.py -p /dev/ttyUSB0 flash
```

Or use the flash script:

```bash
/scripts/flash.sh /dev/ttyUSB0
```

### Monitoring Serial Output

```bash
idf.py -p /dev/ttyUSB0 monitor
```

Or use the monitor script:

```bash
/scripts/monitor.sh /dev/ttyUSB0
```

Press `Ctrl+]` to exit the monitor.

### All-in-One: Build, Flash, and Monitor

```bash
cd /project
idf.py -p /dev/ttyUSB0 flash monitor
```

## Finding Your ESP32 Device

On Linux:
```bash
ls /dev/ttyUSB*
# or
ls /dev/ttyACM*
```

On macOS:
```bash
ls /dev/cu.*
```

On Windows (WSL2):
You may need to use [usbipd-win](https://github.com/dorssel/usbipd-win) to attach USB devices to WSL2.

## Customizing the Environment

### Using a Different ESP-IDF Version

Edit the `Dockerfile` and change the base image:

```dockerfile
FROM espressif/idf:release-v5.2
```

Available versions: https://hub.docker.com/r/espressif/idf/tags

### Changing the USB Device

Edit `docker-compose.yml` and update the device mapping:

```yaml
devices:
  - /dev/ttyUSB1:/dev/ttyUSB0  # Map host device to container
```

### Persisting ESP-IDF Cache

The Docker Compose configuration includes a volume for ESP-IDF build cache to speed up subsequent builds:

```yaml
volumes:
  - esp32-build-cache:/root/.espressif
```

## Troubleshooting

### Permission Denied on USB Device

On Linux, you may need to add your user to the `dialout` group:

```bash
sudo usermod -a -G dialout $USER
```

Then log out and log back in.

### Container Can't Access USB Device

Make sure the device path in `docker-compose.yml` matches your actual device:

```bash
ls -l /dev/ttyUSB*
```

### Build Errors

If you encounter build errors, try cleaning the build:

```bash
cd /project
idf.py fullclean
idf.py build
```

## Example Projects

The repository includes a simple "Hello World" example that:
- Prints a greeting message
- Displays free heap memory every 5 seconds
- Demonstrates basic FreeRTOS task usage

## Creating a New Project

To start your own project:

1. Clear the `project/` directory:
   ```bash
   rm -rf project/*
   ```

2. Create a new ESP-IDF project structure or copy an existing one into `project/`

3. Build and flash as described above

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Resources

- [ESP-IDF Programming Guide](https://docs.espressif.com/projects/esp-idf/en/latest/)
- [ESP32 Documentation](https://www.espressif.com/en/products/socs/esp32)
- [Docker Documentation](https://docs.docker.com/)
- [ESP-IDF Docker Image](https://hub.docker.com/r/espressif/idf)

## Support

For issues and questions:
- Open an issue on GitHub
- Check the [ESP-IDF documentation](https://docs.espressif.com/projects/esp-idf/)
- Visit the [ESP32 Forum](https://www.esp32.com/)
