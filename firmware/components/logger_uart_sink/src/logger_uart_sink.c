#include "logger/logger_uart_sink.h"
#include <stddef.h>

/* Prosty sink: wszystko co dostaje, wypycha na UART przez abstrakcyjny interfejs ports/uart_port.h. */
typedef struct { ca_uart_port_t* u; } ctx_t;

static int write_fn(log_sink_t* s, const uint8_t* d, size_t l)
{
    ctx_t* c = (ctx_t*)s->ctx;
    if (!c || !c->u || !c->u->write) return -1;
    size_t w = 0;
    c->u->write(c->u->ctx, d, l, &w);
    return (int)w;
}

static const log_sink_vtbl_t V = { .write = write_fn };

int logger_uart_sink_create(ca_uart_port_t* u, log_sink_t* out)
{
    static ctx_t C;
    C.u = u;
    out->v = &V;
    out->ctx = &C;
    return 0;
}
