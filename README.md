# ESP32-C6 — Extreme Clean Architecture (LCD1602 + DS18B20)

Szkielet z Dockerem, skryptami oraz strukturą:
- **ports/** (czyste interfejsy C: I2C async, UART, 1-Wire, TIME, LOG SINK)
- **drivers/** (czyste drivery: lcd1602 dev+fb, ds18b20)
- **infrastructure/** (adaptery IDF: i2c_service, uart, time, onewire)
- **logger_core/** + **logger_uart_sink/**
- **app/main** (Composition Root)
- **docs/** (Doxygen + Graphviz przykłady)

## Szybki start
```bash
./scripts/build-docker.sh
./scripts/setup-volumes.sh
./scripts/init.sh
# flash + monitor (auto-detect port):
./scripts/flash-monitor.sh
# lub: ESPPORT=/dev/ttyUSB0 ./scripts/flash-monitor.sh
```

## WSL (Windows)
Użyj `usbipd-win`:
```powershell
usbipd list
usbipd wsl attach --busid <BUSID> --distribution <TwojaDistro>
```
Następnie w WSL wykonaj kroki z „Szybki start”.

## Dokumentacja (Doxygen/Graphviz)
```bash
docker run --rm -t -v "$PWD/firmware:/work" esp32-idf:5.3-docs bash -lc 'doxygen docs/Doxyfile'
# Otwórz: firmware/docs/html/index.html
```
