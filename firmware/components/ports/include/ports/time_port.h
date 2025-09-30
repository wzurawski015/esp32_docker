#pragma once
#include <stdint.h>
typedef struct time_port {
  void (*sleep_ms)(uint32_t ms);
  uint64_t (*now_monotonic_us)(void);
} time_port_t;
