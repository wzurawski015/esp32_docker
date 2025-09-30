#!/usr/bin/env bash
set -euo pipefail
for p in /dev/ttyUSB* /dev/ttyACM* /dev/tty.SLAB_USBtoUART* /dev/tty.usbserial* /dev/tty.usbmodem*; do
  [ -e "$p" ] && { echo "$p"; exit 0; }
done
exit 1
