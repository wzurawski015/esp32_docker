#pragma once
#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include "ca/status.h"
typedef uint32_t i2c_req_t;
typedef enum { I2C_EVT_COMPLETE=0, I2C_EVT_ERROR, I2C_EVT_TIMEOUT } i2c_evt_kind_t;
typedef struct { uint32_t timeout_ms; uint8_t retries; bool no_stop; } i2c_xfer_opts_t;
typedef void (*i2c_completion_cb)(void* user, i2c_req_t req, i2c_evt_kind_t kind, ca_status_t status);
typedef struct i2c_async_port {
  void* ctx;
  ca_status_t (*submit_write)(void*, uint8_t, const uint8_t*, size_t, const i2c_xfer_opts_t*, i2c_completion_cb, void*, i2c_req_t*);
  ca_status_t (*submit_write_read)(void*, uint8_t, const uint8_t*, size_t, uint8_t*, size_t, const i2c_xfer_opts_t*, i2c_completion_cb, void*, i2c_req_t*);
  ca_status_t (*cancel)(void*, i2c_req_t);
} i2c_async_port_t;
