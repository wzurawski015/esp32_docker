#pragma once
#include "ports/uart_port.h"

typedef struct {
    int uart_num;
    int tx_gpio;
    int rx_gpio;
    int baud;
    int rx_buf_bytes;
} idf_uart_cfg_t;

ca_status_t idf_uart_create(const idf_uart_cfg_t* cfg, ca_uart_port_t* out);
