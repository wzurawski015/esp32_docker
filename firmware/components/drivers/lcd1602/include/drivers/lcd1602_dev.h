#pragma once
#include <stdint.h>
#include "ports/i2c_async_port.h"
#include "ports/time_port.h"
#include "ca/status.h"
typedef struct { i2c_async_port_t* i2c; time_port_t* time; uint8_t addr7; uint8_t cols, rows; } lcd1602_dev_cfg_t;
typedef enum { LCD_IDLE, LCD_INIT_DELAY, LCD_INIT_FSET1, LCD_INIT_FSET2, LCD_INIT_FSET3, LCD_INIT_DISPON, LCD_INIT_CLEAR, LCD_INIT_ENTRY, LCD_READY } lcd_state_t;
typedef struct { i2c_async_port_t* i2c; time_port_t* time; uint8_t addr7, cols, rows; lcd_state_t st; } lcd1602_dev_t;
ca_status_t lcd1602_dev_init(lcd1602_dev_t*, const lcd1602_dev_cfg_t*, void (*on_ready)(void*), void* user);
ca_status_t lcd1602_dev_set_ddram(lcd1602_dev_t*, uint8_t addr);
ca_status_t lcd1602_dev_write_bytes(lcd1602_dev_t*, const uint8_t* bytes, uint8_t n);
