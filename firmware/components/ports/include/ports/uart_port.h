#pragma once
#include <stddef.h>
#include <stdint.h>
#include "ca/status.h"

/** Minimalny interfejs abstrakcyjnego UART-a (Clean Architecture).
 *  Uwaga: nazwa typu to ca_uart_port_t, aby nie kolidować z IDF-owym enumem uart_port_t.
 */
typedef struct ca_uart_port {
    void* ctx;
    ca_status_t (*write)(void* ctx, const uint8_t* data, size_t len, size_t* out_written);
} ca_uart_port_t;
