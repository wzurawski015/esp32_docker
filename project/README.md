# ESP32 Hello World Example

This is a simple ESP32 example project that demonstrates:
- Basic ESP-IDF project structure
- FreeRTOS task usage
- ESP logging
- System information retrieval

## Building

Inside the Docker container:

```bash
cd /project
idf.py set-target esp32
idf.py build
```

## Configuration

The project uses default settings. To customize:

```bash
cd /project
idf.py menuconfig
```

## Flashing

```bash
idf.py -p /dev/ttyUSB0 flash
```

## Monitoring

```bash
idf.py -p /dev/ttyUSB0 monitor
```

## Expected Output

```
I (xxx) main: Hello from ESP32!
I (xxx) main: Free heap: XXXXX bytes
I (xxx) main: Free heap: XXXXX bytes
...
```

## Customization

Edit `main/main.c` to add your own functionality. Common modifications:
- Add GPIO control
- Configure WiFi
- Add sensors or peripherals
- Implement custom tasks
