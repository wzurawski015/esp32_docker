#pragma once
#include "ports/log_sink.h"
#include "ports/uart_port.h"
int logger_uart_sink_create(uart_port_t* uart, log_sink_t* out);
