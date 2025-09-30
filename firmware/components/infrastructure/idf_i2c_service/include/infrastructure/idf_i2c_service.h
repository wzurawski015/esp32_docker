#pragma once
#include "ports/i2c_async_port.h"
typedef struct { int idf_port; int sda_gpio; int scl_gpio; uint32_t clk_hz; int queue_len; int task_prio; int task_stack; } idf_i2c_service_cfg_t;
ca_status_t idf_i2c_service_start(const idf_i2c_service_cfg_t* cfg, i2c_async_port_t* out_port);
