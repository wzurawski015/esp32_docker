#pragma once
#include <stddef.h>
#include <stdint.h>
struct log_sink;
typedef struct log_sink_vtbl {
  int (*write)(struct log_sink* s, const uint8_t* data, size_t len);
} log_sink_vtbl_t;
typedef struct log_sink {
  const log_sink_vtbl_t* v;
  void* ctx;
} log_sink_t;
static inline int log_sink_write(log_sink_t* s, const uint8_t* d, size_t l){
  return (s && s->v && s->v->write) ? s->v->write(s,d,l) : -1;
}
