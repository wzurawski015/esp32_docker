#pragma once
#include <stdint.h>
#include <stdarg.h>
#include "ports/log_sink.h"
#include "ports/time_port.h"
typedef enum { LOG_TRACE=0, LOG_DEBUG, LOG_INFO, LOG_WARN, LOG_ERROR, LOG_FATAL } log_level_t;
typedef struct { time_port_t* timep; uint32_t queue_len; uint32_t max_line; int consumer_prio; int consumer_stack; } logger_cfg_t;
int logger_init(const logger_cfg_t*);
int logger_add_sink(log_sink_t*);
int logger_set_level_global(log_level_t);
int logger_printf(log_level_t lvl, const char* mod4, const char* fmt, ...);
#define LOG_T(mod, fmt, ...) logger_printf(LOG_TRACE, mod, fmt, ##__VA_ARGS__)
#define LOG_D(mod, fmt, ...) logger_printf(LOG_DEBUG, mod, fmt, ##__VA_ARGS__)
#define LOG_I(mod, fmt, ...) logger_printf(LOG_INFO,  mod, fmt, ##__VA_ARGS__)
#define LOG_W(mod, fmt, ...) logger_printf(LOG_WARN,  mod, fmt, ##__VA_ARGS__)
#define LOG_E(mod, fmt, ...) logger_printf(LOG_ERROR, mod, fmt, ##__VA_ARGS__)
#define LOG_F(mod, fmt, ...) logger_printf(LOG_FATAL, mod, fmt, ##__VA_ARGS__)
