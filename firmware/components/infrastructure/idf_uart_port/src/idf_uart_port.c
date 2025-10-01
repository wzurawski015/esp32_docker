#include "infrastructure/idf_uart_port.h"
#include "driver/uart.h"
#include <stdlib.h>

typedef struct { int num; } ctx_t;

static ca_status_t w_fn(void* c_, const uint8_t* d, size_t l, size_t* out)
{
    ctx_t* c = (ctx_t*)c_;
    int n = uart_write_bytes(c->num, (const char*)d, l);
    if (out) *out = (n < 0 ? 0 : (size_t)n);
    return (n < 0) ? CA_EIO : CA_OK;
}

ca_status_t idf_uart_create(const idf_uart_cfg_t* cfg, ca_uart_port_t* out)
{
    if (!cfg || !out) return CA_EINVAL;

    ctx_t* c = (ctx_t*)calloc(1, sizeof(ctx_t));
    if (!c) return CA_EIO;
    c->num = cfg->uart_num;

    uart_config_t conf = {
        .baud_rate = cfg->baud,
        .data_bits = UART_DATA_8_BITS,
        .parity    = UART_PARITY_DISABLE,
        .stop_bits = UART_STOP_BITS_1,
        .flow_ctrl = UART_HW_FLOWCTRL_DISABLE,
        .source_clk = UART_SCLK_DEFAULT
    };

    if (uart_driver_install(c->num, cfg->rx_buf_bytes ? cfg->rx_buf_bytes : 2048, 0, 0, NULL, 0) != ESP_OK) { free(c); return CA_EIO; }
    if (uart_param_config(c->num, &conf) != ESP_OK) { uart_driver_delete(c->num); free(c); return CA_EIO; }
    if (uart_set_pin(c->num, cfg->tx_gpio, cfg->rx_gpio, UART_PIN_NO_CHANGE, UART_PIN_NO_CHANGE) != ESP_OK) { uart_driver_delete(c->num); free(c); return CA_EIO; }

    out->ctx   = c;
    out->write = w_fn;
    return CA_OK;
}
