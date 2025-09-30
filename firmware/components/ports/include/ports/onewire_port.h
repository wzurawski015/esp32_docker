#pragma once
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include "ca/status.h"
typedef struct onewire_port {
  void* ctx;
  ca_status_t (*reset)(void* ctx, bool* presence);
  ca_status_t (*write_bytes)(void* ctx, const uint8_t* data, size_t len);
  ca_status_t (*read_bytes)(void* ctx, uint8_t* data, size_t len);
  ca_status_t (*read_bit)(void* ctx, uint8_t* bit);
} onewire_port_t;
