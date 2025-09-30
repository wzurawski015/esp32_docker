#pragma once
#include <stdint.h>
#include "drivers/lcd1602_dev.h"
#include "ca/status.h"
typedef struct { lcd1602_dev_t* dev; uint8_t cols, rows; uint8_t buf[2][16]; uint8_t dirty[2][16]; } lcd1602_fb_t;
ca_status_t lcd1602_fb_init(lcd1602_fb_t*, lcd1602_dev_t*);
ca_status_t lcd1602_fb_clear(lcd1602_fb_t*);
ca_status_t lcd1602_fb_draw_text(lcd1602_fb_t*, uint8_t col, uint8_t row, const char* ascii);
ca_status_t lcd1602_fb_flush_minimal(lcd1602_fb_t*);
