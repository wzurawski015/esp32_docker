#pragma once
#include "ports/log_sink.h"
#include "ports/uart_port.h"

/** Sink loggera, który wypisuje bajty przez abstrakcyjny UART (ca_uart_port_t). */
int logger_uart_sink_create(ca_uart_port_t* uart, log_sink_t* out);
