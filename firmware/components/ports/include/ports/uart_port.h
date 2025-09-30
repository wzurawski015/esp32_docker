#pragma once
#include <stddef.h>
#include <stdint.h>
#include "ca/status.h"
typedef struct uart_port {
  void* ctx;
  ca_status_t (*write)(void* ctx, const uint8_t* data, size_t len, size_t* out_written);
} uart_port_t;
