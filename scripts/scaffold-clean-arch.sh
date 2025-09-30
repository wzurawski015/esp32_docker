#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# -----------------------------------------------------------------------------------
# 1) Konfiguracja hosta (WSL/Linux)
# -----------------------------------------------------------------------------------
mkdir -p "$ROOT/config"
cat > "$ROOT/config/host.env" <<'EOT'
# Ustaw swój typ hosta: linux | wsl (na WSL zalecany usbipd-win do podpięcia USB)
HOST_OS=linux
# Opcjonalnie możesz tu na stałe wskazać port szeregowy (zamiast autodetekcji):
# ESPPORT=/dev/ttyUSB0
EOT

# -----------------------------------------------------------------------------------
# 2) Szkielet ekstremalnie Clean Architecture w firmware/
# -----------------------------------------------------------------------------------
mkdir -p "$ROOT/firmware"/{main,components/{ca,ports,infrastructure,drivers,logger_core,logger_uart_sink},docs/graphs}

# 2.1 Top-level CMake (EXTRA_COMPONENT_DIRS + komentarze)
cat > "$ROOT/firmware/CMakeLists.txt" <<'EOT'
cmake_minimum_required(VERSION 3.16)
# =====================================================================
#  ESP32-C6 Firmware — Extreme Clean Architecture (EDU edition)
#  - ports/            (abstrakcje, czysty C, zero IDF)
#  - drivers/          (urządzenia; LCD1602, DS18B20 — czysty C, używają ports)
#  - infrastructure/   (adaptery IDF: i2c_service, uart, time, onewire)
#  - app/              (kompozycja; uruchomienie tasków, logger)
#
#  IDF NIE skanuje rekurencyjnie components/, dlatego listujemy jawnie:
# =====================================================================
include($ENV{IDF_PATH}/tools/cmake/project.cmake)

set(EXTRA_COMPONENT_DIRS
    ${CMAKE_CURRENT_LIST_DIR}/components/ca
    ${CMAKE_CURRENT_LIST_DIR}/components/ports
    ${CMAKE_CURRENT_LIST_DIR}/components/infrastructure/idf_i2c_service
    ${CMAKE_CURRENT_LIST_DIR}/components/infrastructure/idf_uart_port
    ${CMAKE_CURRENT_LIST_DIR}/components/infrastructure/idf_time_port
    ${CMAKE_CURRENT_LIST_DIR}/components/infrastructure/idf_onewire
    ${CMAKE_CURRENT_LIST_DIR}/components/drivers/lcd1602
    ${CMAKE_CURRENT_LIST_DIR}/components/drivers/ds18b20
    ${CMAKE_CURRENT_LIST_DIR}/components/logger_core
    ${CMAKE_CURRENT_LIST_DIR}/components/logger_uart_sink
)

project(esp32c6_extreme_clean_lcd_ds18)
EOT

# 2.2 app/ (main)
cat > "$ROOT/firmware/main/CMakeLists.txt" <<'EOT'
# ------------------------------------------------------------------
# app/ — Composition Root (wiąże ports→drivers→infra, uruchamia taski)
# ------------------------------------------------------------------
idf_component_register(
  SRCS "main.c"
  INCLUDE_DIRS "."
  REQUIRES
    ca ports
    infrastructure__idf_i2c_service
    infrastructure__idf_uart_port
    infrastructure__idf_time_port
    infrastructure__idf_onewire
    drivers__lcd1602 drivers__ds18b20
    logger_core logger_uart_sink
)
EOT

cat > "$ROOT/firmware/main/Kconfig.projbuild" <<'EOT'
menu "App configuration"

menu "I2C (LCD)"
config APP_I2C_SDA int "I2C SDA" range 0 48 default 21
config APP_I2C_SCL int "I2C SCL" range 0 48 default 22
config APP_I2C_HZ  int "I2C Hz"  default 400000
endmenu

menu "LCD"
config APP_LCD_ADDR hex "LCD 7-bit address" default 0x3E
endmenu

menu "1-Wire / DS18B20"
config APP_OW_GPIO int "1-Wire GPIO" range 0 48 default 18
config APP_DS_RES  int "DS18B20 resolution (9..12)" range 9 12 default 12
endmenu

menu "UART (console/logger)"
config APP_UART_NUM int "UART num" range 0 2 default 0
config APP_UART_TX  int "UART TX gpio" range 0 48 default 43
config APP_UART_RX  int "UART RX gpio" range 0 48 default 44
config APP_UART_BAUD int "UART baud" default 115200
endmenu

endmenu
EOT

cat > "$ROOT/firmware/main/main.c" <<'EOT'
/**
 * @file main.c
 * @brief Composition Root — ultra Clean Architecture.
 *
 * Warstwy:
 *  - ports/            czyste interfejsy C (I2C async, UART TX, 1-Wire, TIME, LOG SINK)
 *  - drivers/          czysty C (LCD1602 device+framebuffer; DS18B20 pipeline)
 *  - infrastructure/   adaptery IDF (i2c_service = service-task + queue; uart; time; onewire)
 *  - app/              tylko wiązanie i start zadań (UI, SENSOR) + logger
 *
 * Diagram (skrót konceptu):
 * \dot
 * digraph G { rankdir=LR; node[shape=box,style=rounded,fontsize=10];
 *   app->lcd; app->ds; lcd->i2c; ds->ow; i2c->i2c_svc[label="idf_i2c_service"]; ow->ow_svc[label="idf_onewire"];
 *   app->log[label="logger_core"]; log->uart_sink[label="logger_uart_sink"];
 * }
 * \enddot
 */
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#include "ports/i2c_async_port.h"
#include "ports/uart_port.h"
#include "ports/time_port.h"
#include "ports/onewire_port.h"
#include "ports/log_sink.h"

#include "infrastructure/idf_i2c_service.h"
#include "infrastructure/idf_uart_port.h"
#include "infrastructure/idf_time_port.h"
#include "infrastructure/idf_onewire.h"

#include "drivers/lcd1602_dev.h"
#include "drivers/lcd1602_fb.h"
#include "drivers/ds18b20.h"

#include "logger/logger_core.h"
#include "logger/logger_uart_sink.h"

// Ports (abstrakcje)
static i2c_async_port_t I2C0;
static uart_port_t      UART0;
static time_port_t      TIMEP;
static onewire_port_t   ONEW;

// Urządzenia (czyste drivery)
static lcd1602_dev_t    LCD_DEV;
static lcd1602_fb_t     LCD_FB;
static ds18b20_t        DS;

/** UI: baner + co 1 s flush minimal (I2C) */
static void ui_task(void* arg){
    (void)arg;
    lcd1602_fb_clear(&LCD_FB);
    lcd1602_fb_draw_text(&LCD_FB, 0,0, "ESP32-C6 Clean CA");
    lcd1602_fb_draw_text(&LCD_FB, 0,1, "LCD + DS18B20");
    for(;;){
        lcd1602_fb_flush_minimal(&LCD_FB);
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

/** SENSOR: pipeline DS18B20 — trigger → (czas wg rozdz.) → read */
static void sensor_task(void* arg){
    (void)arg;
    ds18b20_set_resolution(&DS, CONFIG_APP_DS_RES);
    for(;;){
        if (ds18b20_trigger_convert(&DS)==0){
            unsigned ms = (CONFIG_APP_DS_RES==9?94:CONFIG_APP_DS_RES==10?188:CONFIG_APP_DS_RES==11?375:750);
            vTaskDelay(pdMS_TO_TICKS(ms+50));
            float C=0.0f;
            if (ds18b20_read_celsius(&DS, &C)==0){
                char line[17]; snprintf(line, sizeof(line), "Temp: %5.2f C", C);
                lcd1602_fb_draw_text(&LCD_FB, 0,1, line);
            }
        }
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

void app_main(void){
    // UART + logger (producent -> queue -> 1 konsument -> sink)
    idf_uart_create(&(idf_uart_cfg_t){ .uart_num=CONFIG_APP_UART_NUM, .tx_gpio=CONFIG_APP_UART_TX, .rx_gpio=CONFIG_APP_UART_RX, .baud=CONFIG_APP_UART_BAUD, .rx_buf_bytes=2048 }, &UART0);
    idf_time_create(&TIMEP);
    log_sink_t sink; logger_uart_sink_create(&UART0, &sink);
    logger_init(&(logger_cfg_t){ .timep=&TIMEP, .queue_len=256, .max_line=256, .consumer_prio=9, .consumer_stack=4096 });
    logger_add_sink(&sink);
    logger_set_level_global(LOG_INFO);
    LOG_I("APP ","boot");

    // I2C service-task + 1-Wire
    idf_i2c_service_start(&(idf_i2c_service_cfg_t){
        .idf_port=I2C_NUM_0, .sda_gpio=CONFIG_APP_I2C_SDA, .scl_gpio=CONFIG_APP_I2C_SCL, .clk_hz=CONFIG_APP_I2C_HZ,
        .queue_len=32, .task_prio=8, .task_stack=4096
    }, &I2C0);
    idf_onewire_create(&(idf_onewire_cfg_t){ .gpio=CONFIG_APP_OW_GPIO, .internal_pullup=true }, &ONEW);

    // LCD + DS18B20 — czyste drivery
    lcd1602_dev_init(&LCD_DEV, &(lcd1602_dev_cfg_t){ .i2c=&I2C0, .time=&TIMEP, .addr7=CONFIG_APP_LCD_ADDR, .cols=16, .rows=2 }, NULL, NULL);
    lcd1602_fb_init(&LCD_FB, &LCD_DEV);
    ds18b20_init(&DS, &(ds18b20_cfg_t){ .ow=&ONEW, .time=&TIMEP, .res_bits=CONFIG_APP_DS_RES, .single_drop=true });

    xTaskCreate(ui_task, "ui",     4096, NULL, 4, NULL);
    xTaskCreate(sensor_task, "sens",4096, NULL, 5, NULL);
}
EOT

# 2.3 components/ca
mkdir -p "$ROOT/firmware/components/ca/include/ca" "$ROOT/firmware/components/ca/src"
cat > "$ROOT/firmware/components/ca/CMakeLists.txt" <<'EOT'
idf_component_register(SRCS "src/status.c" INCLUDE_DIRS "include")
EOT
cat > "$ROOT/firmware/components/ca/src/status.c" <<'EOT'
/* Intencjonalnie puste — miejsce na ewentualne mapowania błędów/logowanie */
EOT
cat > "$ROOT/firmware/components/ca/include/ca/status.h" <<'EOT'
/**
 * @file status.h
 * @brief Wspólne kody statusów (ujemne = błędy).
 * @defgroup ca_common CA Common
 * @{
 */
#pragma once
#include <stdint.h>
typedef int32_t ca_status_t;
#define CA_OK         0
#define CA_EINVAL    -22
#define CA_EIO        -5
#define CA_ENODEV    -19
#define CA_ETIMEDOUT -110
#define CA_EBUSY     -16
#define CA_ENOSYS    -38
/** @} */
EOT

# 2.4 ports/
mkdir -p "$ROOT/firmware/components/ports/include/ports"
cat > "$ROOT/firmware/components/ports/CMakeLists.txt" <<'EOT'
idf_component_register(SRCS "" INCLUDE_DIRS "include" REQUIRES ca)
EOT
cat > "$ROOT/firmware/components/ports/include/ports/i2c_async_port.h" <<'EOT'
/**
 * @file i2c_async_port.h
 * @brief Asynchroniczne API I²C (submit + callback) — czysty C, zero IDF.
 * @ingroup ports
 */
#pragma once
#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include "ca/status.h"
#ifdef __cplusplus
extern "C" {
#endif
typedef uint32_t i2c_req_t;
typedef enum { I2C_EVT_COMPLETE=0, I2C_EVT_ERROR, I2C_EVT_TIMEOUT } i2c_evt_kind_t;
typedef struct { uint32_t timeout_ms; uint8_t retries; bool no_stop; } i2c_xfer_opts_t;
typedef void (*i2c_completion_cb)(void* user, i2c_req_t req, i2c_evt_kind_t kind, ca_status_t status);
typedef struct i2c_async_port {
  void* ctx;
  ca_status_t (*submit_write)(void*, uint8_t, const uint8_t*, size_t, const i2c_xfer_opts_t*, i2c_completion_cb, void*, i2c_req_t*);
  ca_status_t (*submit_write_read)(void*, uint8_t, const uint8_t*, size_t, uint8_t*, size_t, const i2c_xfer_opts_t*, i2c_completion_cb, void*, i2c_req_t*);
  ca_status_t (*cancel)(void*, i2c_req_t);
} i2c_async_port_t;
#ifdef __cplusplus
}
#endif
EOT
cat > "$ROOT/firmware/components/ports/include/ports/uart_port.h" <<'EOT'
/**
 * @file uart_port.h
 * @brief Port UART (sink logera, komunikacja).
 * @ingroup ports
 */
#pragma once
#include <stddef.h>
#include <stdint.h>
#include "ca/status.h"
typedef struct uart_port {
  void* ctx;
  ca_status_t (*write)(void* ctx, const uint8_t* data, size_t len, size_t* out_written);
} uart_port_t;
EOT
cat > "$ROOT/firmware/components/ports/include/ports/onewire_port.h" <<'EOT'
/**
 * @file onewire_port.h
 * @brief Abstrakcja magistrali 1-Wire (reset/bytes/bit).
 * @ingroup ports
 */
#pragma once
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include "ca/status.h"
typedef struct onewire_port {
  void* ctx;
  ca_status_t (*reset)(void* ctx, bool* presence);
  ca_status_t (*write_bytes)(void* ctx, const uint8_t* data, size_t len);
  ca_status_t (*read_bytes)(void* ctx, uint8_t* data, size_t len);
  ca_status_t (*read_bit)(void* ctx, uint8_t* bit);
} onewire_port_t;
EOT
cat > "$ROOT/firmware/components/ports/include/ports/time_port.h" <<'EOT'
/**
 * @file time_port.h
 * @brief Czas monotoniczny + uśpienie (neutralne).
 * @ingroup ports
 */
#pragma once
#include <stdint.h>
typedef struct time_port {
  void (*sleep_ms)(uint32_t ms);
  uint64_t (*now_monotonic_us)(void);
} time_port_t;
EOT

# 2.5 infrastructure/: I2C service, UART, TIME, ONEWIRE
mkdir -p "$ROOT/firmware/components/infrastructure/idf_i2c_service"/{include,src}
cat > "$ROOT/firmware/components/infrastructure/idf_i2c_service/CMakeLists.txt" <<'EOT'
idf_component_register(SRCS "src/idf_i2c_service.c"
                       INCLUDE_DIRS "include"
                       REQUIRES driver freertos ca ports)
EOT
cat > "$ROOT/firmware/components/infrastructure/idf_i2c_service/include/infrastructure/idf_i2c_service.h" <<'EOT'
#pragma once
#include "ports/i2c_async_port.h"
typedef struct { int idf_port; int sda_gpio; int scl_gpio; uint32_t clk_hz; int queue_len; int task_prio; int task_stack; } idf_i2c_service_cfg_t;
ca_status_t idf_i2c_service_start(const idf_i2c_service_cfg_t* cfg, i2c_async_port_t* out_port);
EOT
cat > "$ROOT/firmware/components/infrastructure/idf_i2c_service/src/idf_i2c_service.c" <<'EOT'
#include "infrastructure/idf_i2c_service.h"
#include "driver/i2c.h"
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "freertos/task.h"
#include <string.h>
#include <stdlib.h>
typedef enum { REQ_WRITE, REQ_WRITE_READ } req_kind_t;
typedef struct { req_kind_t kind; uint8_t addr7; const uint8_t* w; size_t wl; uint8_t* r; size_t rl; i2c_xfer_opts_t opt; i2c_completion_cb cb; void* user; i2c_req_t id; } req_t;
typedef struct { int port_num; QueueHandle_t q; i2c_async_port_t vtable; uint32_t next_id; } i2c_ctx_t;
static ca_status_t map(esp_err_t e){ if(e==ESP_OK) return CA_OK; if(e==ESP_ERR_TIMEOUT) return CA_ETIMEDOUT; if(e==ESP_ERR_INVALID_ARG) return CA_EINVAL; return CA_EIO; }
static ca_status_t submit_write(void* c_, uint8_t addr7, const uint8_t* data, size_t len, const i2c_xfer_opts_t* opt, i2c_completion_cb cb, void* user, i2c_req_t* out){
  i2c_ctx_t* c=(i2c_ctx_t*)c_; req_t r={0}; r.kind=REQ_WRITE; r.addr7=addr7; r.w=data; r.wl=len; r.opt=(opt?*opt:(i2c_xfer_opts_t){.timeout_ms=1000}); r.cb=cb; r.user=user; r.id=++c->next_id; if(out)*out=r.id; return xQueueSend(c->q,&r,0)==pdTRUE?CA_OK:CA_EBUSY;
}
static ca_status_t submit_write_read(void* c_, uint8_t addr7, const uint8_t* w, size_t wl, uint8_t* rbuf, size_t rl, const i2c_xfer_opts_t* opt, i2c_completion_cb cb, void* user, i2c_req_t* out){
  i2c_ctx_t* c=(i2c_ctx_t*)c_; req_t r={0}; r.kind=REQ_WRITE_READ; r.addr7=addr7; r.w=w; r.wl=wl; r.r=rbuf; r.rl=rl; r.opt=(opt?*opt:(i2c_xfer_opts_t){.timeout_ms=1000}); r.cb=cb; r.user=user; r.id=++c->next_id; if(out)*out=r.id; return xQueueSend(c->q,&r,0)==pdTRUE?CA_OK:CA_EBUSY;
}
static ca_status_t cancel_stub(void* ctx, i2c_req_t req){ (void)ctx;(void)req; return CA_ENOSYS; }
static void i2c_task(void* arg){
  i2c_ctx_t* c=(i2c_ctx_t*)arg; req_t r;
  while(1){
    if (xQueueReceive(c->q,&r,portMAX_DELAY)==pdTRUE){
      ca_status_t rc=CA_OK; esp_err_t e=ESP_OK; int tries=(r.opt.retries? r.opt.retries:0)+1;
      while(tries--){
        if (r.kind==REQ_WRITE) e=i2c_master_write_to_device(c->port_num,r.addr7,r.w,r.wl,r.opt.timeout_ms/portTICK_PERIOD_MS);
        else e=i2c_master_write_read_device(c->port_num,r.addr7,r.w,r.wl,r.r,r.rl,r.opt.timeout_ms/portTICK_PERIOD_MS);
        if (e==ESP_OK) break;
      }
      rc=map(e);
      if (r.cb) r.cb(r.user, r.id, (rc==CA_OK)?I2C_EVT_COMPLETE:((rc==CA_ETIMEDOUT)?I2C_EVT_TIMEOUT:I2C_EVT_ERROR), rc);
    }
  }
}
ca_status_t idf_i2c_service_start(const idf_i2c_service_cfg_t* cfg, i2c_async_port_t* out){
  if(!cfg||!out) return CA_EINVAL;
  i2c_ctx_t* c=(i2c_ctx_t*)calloc(1,sizeof(i2c_ctx_t)); if(!c) return CA_EIO; c->port_num=cfg->idf_port;
  c->q=xQueueCreate(cfg->queue_len?cfg->queue_len:16,sizeof(req_t)); if(!c->q){ free(c); return CA_EIO; }
  i2c_config_t conf={ .mode=I2C_MODE_MASTER, .sda_io_num=cfg->sda_gpio, .scl_io_num=cfg->scl_gpio, .sda_pullup_en=1, .scl_pullup_en=1 };
#if ESP_IDF_VERSION >= ESP_IDF_VERSION_VAL(5,0,0)
  conf.clk_source = I2C_CLK_SRC_DEFAULT;
#endif
  conf.master.clk_speed = cfg->clk_hz;
  if (i2c_param_config(c->port_num,&conf)!=ESP_OK || i2c_driver_install(c->port_num, conf.mode, 0, 0, 0)!=ESP_OK){ vQueueDelete(c->q); free(c); return CA_EIO; }
  xTaskCreate(i2c_task,"i2c_service",cfg->task_stack?cfg->task_stack:4096,c,cfg->task_prio?cfg->task_prio:8,NULL);
  out->ctx=c; out->submit_write=submit_write; out->submit_write_read=submit_write_read; out->cancel=cancel_stub; return CA_OK;
}
EOT

mkdir -p "$ROOT/firmware/components/infrastructure/idf_uart_port"/{include,src}
cat > "$ROOT/firmware/components/infrastructure/idf_uart_port/CMakeLists.txt" <<'EOT'
idf_component_register(SRCS "src/idf_uart_port.c" INCLUDE_DIRS "include" REQUIRES driver ports ca)
EOT
cat > "$ROOT/firmware/components/infrastructure/idf_uart_port/include/infrastructure/idf_uart_port.h" <<'EOT'
#pragma once
#include "ports/uart_port.h"
typedef struct { int uart_num; int tx_gpio; int rx_gpio; int baud; int rx_buf_bytes; } idf_uart_cfg_t;
ca_status_t idf_uart_create(const idf_uart_cfg_t* cfg, uart_port_t* out);
EOT
cat > "$ROOT/firmware/components/infrastructure/idf_uart_port/src/idf_uart_port.c" <<'EOT'
#include "infrastructure/idf_uart_port.h"
#include "driver/uart.h"
#include <stdlib.h>
typedef struct { int num; } ctx_t;
static ca_status_t map(esp_err_t e){ if(e==ESP_OK) return CA_OK; if(e==ESP_ERR_TIMEOUT) return CA_ETIMEDOUT; if(e==ESP_ERR_INVALID_ARG) return CA_EINVAL; return CA_EIO; }
static ca_status_t w_fn(void* c_, const uint8_t* d, size_t l, size_t* out){ ctx_t* c=(ctx_t*)c_; int n=uart_write_bytes(c->num,(const char*)d,l); if(out)*out=(n<0?0:(size_t)n); return (n<0)?CA_EIO:CA_OK; }
ca_status_t idf_uart_create(const idf_uart_cfg_t* cfg, uart_port_t* out){
  if(!cfg||!out) return CA_EINVAL; ctx_t* c=(ctx_t*)calloc(1,sizeof(ctx_t)); if(!c) return CA_EIO; c->num=cfg->uart_num;
  uart_config_t conf={ .baud_rate=cfg->baud, .data_bits=UART_DATA_8_BITS, .parity=UART_PARITY_DISABLE, .stop_bits=UART_STOP_BITS_1, .flow_ctrl=UART_HW_FLOWCTRL_DISABLE, .source_clk=UART_SCLK_DEFAULT };
  if (uart_driver_install(c->num, cfg->rx_buf_bytes?cfg->rx_buf_bytes:2048, 0, 0, NULL, 0)!=ESP_OK){ free(c); return CA_EIO; }
  if (uart_param_config(c->num,&conf)!=ESP_OK){ uart_driver_delete(c->num); free(c); return CA_EIO; }
  if (uart_set_pin(c->num, cfg->tx_gpio, cfg->rx_gpio, UART_PIN_NO_CHANGE, UART_PIN_NO_CHANGE)!=ESP_OK){ uart_driver_delete(c->num); free(c); return CA_EIO; }
  out->ctx=c; out->write=w_fn; return CA_OK;
}
EOT

mkdir -p "$ROOT/firmware/components/infrastructure/idf_time_port"/{include,src}
cat > "$ROOT/firmware/components/infrastructure/idf_time_port/CMakeLists.txt" <<'EOT'
idf_component_register(SRCS "src/idf_time_port.c" INCLUDE_DIRS "include" REQUIRES ports)
EOT
cat > "$ROOT/firmware/components/infrastructure/idf_time_port/include/infrastructure/idf_time_port.h" <<'EOT'
#pragma once
#include "ports/time_port.h"
void idf_time_create(time_port_t* out);
EOT
cat > "$ROOT/firmware/components/infrastructure/idf_time_port/src/idf_time_port.c" <<'EOT'
#include "infrastructure/idf_time_port.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_timer.h"
static void sleep_ms(uint32_t ms){ vTaskDelay(pdMS_TO_TICKS(ms)); }
static uint64_t now_us(void){ return esp_timer_get_time(); }
void idf_time_create(time_port_t* out){ out->sleep_ms=sleep_ms; out->now_monotonic_us=now_us; }
EOT

mkdir -p "$ROOT/firmware/components/infrastructure/idf_onewire"/{include,src}
cat > "$ROOT/firmware/components/infrastructure/idf_onewire/CMakeLists.txt" <<'EOT'
idf_component_register(SRCS "src/idf_onewire.c" INCLUDE_DIRS "include" REQUIRES ports ca)
EOT
cat > "$ROOT/firmware/components/infrastructure/idf_onewire/idf_component.yml" <<'EOT'
dependencies:
  espressif/onewire_bus: "^1.0.4"
EOT
cat > "$ROOT/firmware/components/infrastructure/idf_onewire/include/infrastructure/idf_onewire.h" <<'EOT'
#pragma once
#include "ports/onewire_port.h"
typedef struct { int gpio; bool internal_pullup; } idf_onewire_cfg_t;
ca_status_t idf_onewire_create(const idf_onewire_cfg_t* cfg, onewire_port_t* out);
EOT
cat > "$ROOT/firmware/components/infrastructure/idf_onewire/src/idf_onewire.c" <<'EOT'
#include "infrastructure/idf_onewire.h"
#include "onewire_bus.h"
#include <stdlib.h>
typedef struct { onewire_bus_handle_t bus; } ctx_t;
static ca_status_t map(esp_err_t e){ return e==ESP_OK?CA_OK:CA_EIO; }
static ca_status_t reset(void* c_, bool* p){ ctx_t* c=(ctx_t*)c_; bool pres=false; esp_err_t e=onewire_bus_reset(c->bus,&pres); if(p)*p=pres; return map(e); }
static ca_status_t wbytes(void* c_, const uint8_t* d,size_t l){ ctx_t* c=(ctx_t*)c_; return map(onewire_bus_write_bytes(c->bus,d,l)); }
static ca_status_t rbytes(void* c_, uint8_t* d,size_t l){ ctx_t* c=(ctx_t*)c_; return map(onewire_bus_read_bytes(c->bus,d,l)); }
static ca_status_t rbit(void* c_, uint8_t* b){ ctx_t* c=(ctx_t*)c_; uint8_t v=0; esp_err_t e=onewire_bus_read_bit(c->bus,&v); if(b)*b=v; return map(e); }
ca_status_t idf_onewire_create(const idf_onewire_cfg_t* cfg, onewire_port_t* out){
  if(!cfg||!out) return CA_EINVAL;
  ctx_t* c=(ctx_t*)calloc(1,sizeof(ctx_t)); if(!c) return CA_EIO;
  onewire_bus_config_t bus_cfg={ .bus_gpio_num=cfg->gpio, .flags={ .en_pull_up=cfg->internal_pullup } };
  onewire_bus_rmt_config_t rmt_cfg={ .max_rx_bytes = 10 };
  if (onewire_new_bus_rmt(&bus_cfg,&rmt_cfg,&c->bus)!=ESP_OK){ free(c); return CA_EIO; }
  out->ctx=c; out->reset=reset; out->write_bytes=wbytes; out->read_bytes=rbytes; out->read_bit=rbit; return CA_OK;
}
EOT

# 2.6 drivers/: LCD (dev+fb) + DS18B20 + logger
mkdir -p "$ROOT/firmware/components/drivers/lcd1602"/{include/src}
cat > "$ROOT/firmware/components/drivers/lcd1602/CMakeLists.txt" <<'EOT'
idf_component_register(SRCS "src/lcd1602_dev.c" "src/lcd1602_fb.c" INCLUDE_DIRS "include" REQUIRES ports ca)
EOT
cat > "$ROOT/firmware/components/drivers/lcd1602/include/drivers/lcd1602_dev.h" <<'EOT'
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
EOT
cat > "$ROOT/firmware/components/drivers/lcd1602/src/lcd1602_dev.c" <<'EOT'
#include "drivers/lcd1602_dev.h"
#include <string.h>
#define CMD_CLEARDISPLAY 0x01
#define CMD_ENTRYMODESET 0x04
#define CMD_DISPLAYCONTROL 0x08
#define CMD_FUNCTIONSET 0x20
#define FLAG_ENTRYLEFT 0x02
#define FLAG_ENTRYSHIFTDECREMENT 0x00
#define FLAG_DISPLAYON 0x04
#define FLAG_4BITMODE 0x00
#define FLAG_2LINE 0x08
#define FLAG_5x8DOTS 0x00
static void cont(void* u,uint32_t r,int k,int s){(void)u;(void)r;(void)k;(void)s;}
static ca_status_t send_cmd(lcd1602_dev_t* d, uint8_t v){ uint8_t b[2]={0x80,v}; return d->i2c->submit_write(d->i2c->ctx,d->addr7,b,2,NULL,cont,d,NULL); }
static ca_status_t send_data(lcd1602_dev_t* d, const uint8_t* data, uint8_t n){ uint8_t buf[1+32]; if(n>32)n=32; buf[0]=0x40; memcpy(&buf[1],data,n); return d->i2c->submit_write(d->i2c->ctx,d->addr7,buf,1+n,NULL,cont,d,NULL); }
ca_status_t lcd1602_dev_init(lcd1602_dev_t* d, const lcd1602_dev_cfg_t* cfg, void (*on_ready)(void*), void* u){
  if(!d||!cfg||!cfg->i2c||!cfg->time) return CA_EINVAL; memset(d,0,sizeof(*d));
  d->i2c=cfg->i2c; d->time=cfg->time; d->addr7=cfg->addr7?cfg->addr7:0x3E; d->cols=cfg->cols?cfg->cols:16; d->rows=cfg->rows?cfg->rows:2;
  d->st=LCD_INIT_DELAY; d->time->sleep_ms(50);
  d->st=LCD_INIT_FSET1; send_cmd(d, CMD_FUNCTIONSET | (FLAG_4BITMODE | (d->rows>1?FLAG_2LINE:0) | FLAG_5x8DOTS));
  d->st=LCD_INIT_FSET2; send_cmd(d, CMD_FUNCTIONSET | (FLAG_4BITMODE | (d->rows>1?FLAG_2LINE:0) | FLAG_5x8DOTS));
  d->st=LCD_INIT_FSET3; send_cmd(d, CMD_FUNCTIONSET | (FLAG_4BITMODE | (d->rows>1?FLAG_2LINE:0) | FLAG_5x8DOTS));
  d->st=LCD_INIT_DISPON; send_cmd(d, CMD_DISPLAYCONTROL | FLAG_DISPLAYON);
  d->st=LCD_INIT_CLEAR;  send_cmd(d, CMD_CLEARDISPLAY);
  d->st=LCD_INIT_ENTRY;  send_cmd(d, CMD_ENTRYMODESET | (FLAG_ENTRYLEFT | FLAG_ENTRYSHIFTDECREMENT));
  d->st=LCD_READY; if (on_ready) on_ready(u); return CA_OK;
}
ca_status_t lcd1602_dev_set_ddram(lcd1602_dev_t* d, uint8_t addr){ uint8_t b[2]={0x80,(uint8_t)(0x80|addr)}; return d->i2c->submit_write(d->i2c->ctx,d->addr7,b,2,NULL,0,0,0); }
ca_status_t lcd1602_dev_write_bytes(lcd1602_dev_t* d, const uint8_t* bytes, uint8_t n){ return send_data(d,bytes,n); }
EOT

mkdir -p "$ROOT/firmware/components/drivers/lcd1602/src"
cat > "$ROOT/firmware/components/drivers/lcd1602/include/drivers/lcd1602_fb.h" <<'EOT'
#pragma once
#include <stdint.h>
#include "drivers/lcd1602_dev.h"
#include "ca/status.h"
typedef struct { lcd1602_dev_t* dev; uint8_t cols, rows; uint8_t buf[2][16]; uint8_t dirty[2][16]; } lcd1602_fb_t;
ca_status_t lcd1602_fb_init(lcd1602_fb_t*, lcd1602_dev_t*);
ca_status_t lcd1602_fb_clear(lcd1602_fb_t*);
ca_status_t lcd1602_fb_draw_text(lcd1602_fb_t*, uint8_t col, uint8_t row, const char* ascii);
ca_status_t lcd1602_fb_flush_minimal(lcd1602_fb_t*);
EOT
cat > "$ROOT/firmware/components/drivers/lcd1602/src/lcd1602_fb.c" <<'EOT'
#include "drivers/lcd1602_fb.h"
#include <string.h>
ca_status_t lcd1602_fb_init(lcd1602_fb_t* fb, lcd1602_dev_t* dev){ if(!fb||!dev) return CA_EINVAL; memset(fb,0,sizeof(*fb)); fb->dev=dev; fb->cols=dev->cols; fb->rows=dev->rows; return CA_OK; }
ca_status_t lcd1602_fb_clear(lcd1602_fb_t* fb){ for(int r=0;r<fb->rows;r++) for(int c=0;c<fb->cols;c++){ fb->buf[r][c]=' '; fb->dirty[r][c]=1; } return CA_OK; }
ca_status_t lcd1602_fb_draw_text(lcd1602_fb_t* fb, uint8_t col, uint8_t row, const char* s){ if(row>=fb->rows||col>=fb->cols) return CA_EINVAL; uint8_t c=col,r=row; while(*s&&r<fb->rows){ if(c>=fb->cols){ r++; c=0; if(r>=fb->rows) break; } fb->buf[r][c]=(uint8_t)*s++; fb->dirty[r][c]=1; c++; } return CA_OK; }
ca_status_t lcd1602_fb_flush_minimal(lcd1602_fb_t* fb){ for(uint8_t row=0;row<fb->rows;++row){ uint8_t col=0; while(col<fb->cols){ while(col<fb->cols && !fb->dirty[row][col]) col++; if(col>=fb->cols) break; uint8_t start=col; while(col<fb->cols && fb->dirty[row][col]) col++; uint8_t end=col; uint8_t addr=(row==0?0x00:0x40)|start; lcd1602_dev_set_ddram(fb->dev, addr); lcd1602_dev_write_bytes(fb->dev, &fb->buf[row][start], end-start); for(uint8_t i=start;i<end;i++) fb->dirty[row][i]=0; } } return CA_OK; }
EOT

mkdir -p "$ROOT/firmware/components/drivers/ds18b20"/{include,src}
cat > "$ROOT/firmware/components/drivers/ds18b20/CMakeLists.txt" <<'EOT'
idf_component_register(SRCS "src/ds18b20.c" INCLUDE_DIRS "include" REQUIRES ports ca)
EOT
cat > "$ROOT/firmware/components/drivers/ds18b20/include/drivers/ds18b20.h" <<'EOT'
#pragma once
#include <stdint.h>
#include <stdbool.h>
#include "ports/onewire_port.h"
#include "ports/time_port.h"
typedef struct { onewire_port_t* ow; time_port_t* time; uint8_t res_bits; bool single_drop; uint8_t rom[8]; } ds18b20_cfg_t;
typedef struct { onewire_port_t* ow; time_port_t* time; uint8_t res_bits; bool single_drop; uint8_t rom[8]; } ds18b20_t;
int ds18b20_init(ds18b20_t*, const ds18b20_cfg_t*);
int ds18b20_set_resolution(ds18b20_t*, uint8_t res_bits);
int ds18b20_trigger_convert(ds18b20_t*);
bool ds18b20_poll_ready(ds18b20_t*);
int ds18b20_read_celsius(ds18b20_t*, float*);
EOT
cat > "$ROOT/firmware/components/drivers/ds18b20/src/ds18b20.c" <<'EOT'
#include "drivers/ds18b20.h"
#include <string.h>
#define CMD_SKIP_ROM 0xCC
#define CMD_MATCH_ROM 0x55
#define CMD_CONVERT_T 0x44
#define CMD_READ_SCR 0xBE
#define CMD_WRITE_SCR 0x4E
static int select(const ds18b20_t* h){
    bool p=false; if(h->ow->reset(h->ow->ctx,&p)!=CA_OK) return -1; if(!p) return -1;
    if (h->single_drop) { uint8_t c=CMD_SKIP_ROM; return h->ow->write_bytes(h->ow->ctx,&c,1); }
    uint8_t b[9]; b[0]=CMD_MATCH_ROM; memcpy(&b[1],h->rom,8); return h->ow->write_bytes(h->ow->ctx,b,9);
}
int ds18b20_init(ds18b20_t* h, const ds18b20_cfg_t* c){
    if(!h||!c||!c->ow||!c->time) return -1; memset(h,0,sizeof(*h));
    h->ow=c->ow; h->time=c->time; h->res_bits=c->res_bits?c->res_bits:12; h->single_drop=c->single_drop; memcpy(h->rom,c->rom,8);
    return 0;
}
int ds18b20_set_resolution(ds18b20_t* h, uint8_t rb){
    if (rb<9 || rb>12) return -1;
    if (select(h)!=0) return -1;
    uint8_t cfg = 0x1F | (((rb-9)&0x03) << 5);
    uint8_t cmd = CMD_WRITE_SCR; if(h->ow->write_bytes(h->ow->ctx,&cmd,1)!=0) return -1;
    uint8_t b[3] = { 0x4B, 0x46, cfg };
    if (h->ow->write_bytes(h->ow->ctx,b,3)!=0) return -1;
    h->res_bits = rb; return 0;
}
int ds18b20_trigger_convert(ds18b20_t* h){ if(select(h)!=0) return -1; uint8_t c=CMD_CONVERT_T; return h->ow->write_bytes(h->ow->ctx,&c,1); }
bool ds18b20_poll_ready(ds18b20_t* h){ uint8_t bit=0; return h->ow->read_bit(h->ow->ctx,&bit)==CA_OK && bit!=0; }
int ds18b20_read_celsius(ds18b20_t* h, float* out){
    if (select(h)!=0) return -1; uint8_t cmd=CMD_READ_SCR; if(h->ow->write_bytes(h->ow->ctx,&cmd,1)!=0) return -1;
    uint8_t s[9]; if(h->ow->read_bytes(h->ow->ctx,s,9)!=0) return -1;
    int16_t raw = (int16_t)((s[1]<<8)|s[0]); *out=(float)raw/16.0f; return 0;
}
EOT

# 2.7 logger
mkdir -p "$ROOT/firmware/components/logger_core"/{include,src}
cat > "$ROOT/firmware/components/logger_core/CMakeLists.txt" <<'EOT'
idf_component_register(SRCS "src/logger_core.c" INCLUDE_DIRS "include" REQUIRES freertos ports)
EOT
cat > "$ROOT/firmware/components/logger_core/include/logger/logger_core.h" <<'EOT'
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
EOT
cat > "$ROOT/firmware/components/logger_core/src/logger_core.c" <<'EOT'
#include "logger/logger_core.h"
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "freertos/task.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
typedef struct { uint64_t ts_us; char mod[5]; uint8_t lvl; uint16_t len; } rec_hdr_t;
static time_port_t* s_time=NULL;
static QueueHandle_t s_q=NULL;
static size_t s_max=256;
static log_level_t s_global=LOG_INFO;
#define MAXS 4
static log_sink_t* S[MAXS]; static int Sc=0;
static const char* tag(uint8_t l){ switch(l){case 0:return"TRACE";case 1:return"DEBUG";case 2:return"INFO";case 3:return"WARN";case 4:return"ERROR";case 5:return"FATAL";default:return"?";} }
int logger_add_sink(log_sink_t* s){ if(Sc>=MAXS) return -1; S[Sc++]=s; return 0; }
int logger_set_level_global(log_level_t l){ s_global=l; return 0; }
static void consumer(void*arg){
  (void)arg;
  for(;;){
    rec_hdr_t* r=NULL;
    if (xQueueReceive(s_q,&r,portMAX_DELAY)){
      char head[64];
      uint64_t us=r->ts_us; uint32_t s=(uint32_t)(us/1000000ULL); uint32_t ms=(uint32_t)((us/1000ULL)%1000ULL);
      int n=snprintf(head,sizeof(head),"[%u.%03u][%s][%s] ",s,ms,tag(r->lvl),r->mod);
      for(int i=0;i<Sc;i++){ if(S[i]){ log_sink_write(S[i],(const uint8_t*)head,(size_t)n); log_sink_write(S[i],(const uint8_t*)(r+1),r->len); log_sink_write(S[i],(const uint8_t*)"\n",1);} }
      free(r);
    }
  }
}
int logger_init(const logger_cfg_t* cfg){
  if(!cfg||!cfg->timep) return -1; s_time=cfg->timep; s_max=cfg->max_line?cfg->max_line:256;
  s_q=xQueueCreate(cfg->queue_len?cfg->queue_len:64,sizeof(void*)); if(!s_q) return -1;
  xTaskCreate(consumer,"logger",cfg->consumer_stack?cfg->consumer_stack:4096,NULL,cfg->consumer_prio?cfg->consumer_prio:9,NULL); return 0;
}
int logger_printf(log_level_t lvl, const char* mod4, const char* fmt, ...){
  if (lvl < s_global) return 0;
  char buf[512]; va_list ap; va_start(ap, fmt); int m=vsnprintf(buf,sizeof(buf),fmt,ap); va_end(ap); if(m<0) return -1; if((size_t)m>s_max) m=(int)s_max;
  size_t a=sizeof(rec_hdr_t)+(size_t)m; rec_hdr_t* r=(rec_hdr_t*)malloc(a); if(!r) return -1;
  r->ts_us=s_time->now_monotonic_us? s_time->now_monotonic_us():0; r->lvl=(uint8_t)lvl; memset(r->mod,0,5); if(mod4){ strncpy(r->mod,mod4,4); } else { strcpy(r->mod,"APP "); } r->len=(uint16_t)m; memcpy(r+1,buf,(size_t)m);
  if (xQueueSend(s_q,&r,0)!=pdTRUE){ free(r); return -1; } return 0;
}
EOT

mkdir -p "$ROOT/firmware/components/logger_uart_sink"/{include,src}
cat > "$ROOT/firmware/components/logger_uart_sink/CMakeLists.txt" <<'EOT'
idf_component_register(SRCS "src/logger_uart_sink.c" INCLUDE_DIRS "include" REQUIRES ports infrastructure__idf_uart_port)
EOT
cat > "$ROOT/firmware/components/logger_uart_sink/include/logger/logger_uart_sink.h" <<'EOT'
#pragma once
#include "ports/log_sink.h"
#include "ports/uart_port.h"
int logger_uart_sink_create(uart_port_t* uart, log_sink_t* out);
EOT
cat > "$ROOT/firmware/components/logger_uart_sink/src/logger_uart_sink.c" <<'EOT'
#include "logger/logger_uart_sink.h"
typedef struct { uart_port_t* u; } ctx_t;
static int write_fn(log_sink_t* s, const uint8_t* d, size_t l){ ctx_t* c=(ctx_t*)s->ctx; size_t w=0; if(!c||!c->u||!c->u->write) return -1; c->u->write(c->u->ctx,d,l,&w); return (int)w; }
static const log_sink_vtbl_t V={ .write=write_fn };
int logger_uart_sink_create(uart_port_t* u, log_sink_t* out){ static ctx_t C; C.u=u; out->v=&V; out->ctx=&C; return 0; }
EOT

# 3) Doxygen + Graphviz (konfiguracja + przykładowe diagramy)
cat > "$ROOT/firmware/docs/Doxyfile" <<'EOT'
PROJECT_NAME           = "ESP32-C6 Extreme Clean CA — LCD+DS18"
PROJECT_BRIEF          = "ports→drivers→infra→app, I2C service-task, DS18 pipeline, logger"
OUTPUT_DIRECTORY       = docs
GENERATE_HTML          = YES
GENERATE_LATEX         = NO
RECURSIVE              = YES
EXTRACT_ALL            = YES
QUIET                  = YES
WARN_IF_UNDOCUMENTED   = NO
INPUT                  = components/ main/ README.md
FILE_PATTERNS          = *.h *.c *.md
USE_MDFILE_AS_MAINPAGE = README.md
SOURCE_BROWSER         = YES
REFERENCES_RELATION    = YES
REFERENCED_BY_RELATION = YES
VERBATIM_HEADERS       = YES
GENERATE_TREEVIEW      = YES
FULL_PATH_NAMES        = NO
STRIP_FROM_PATH        = .
HAVE_DOT               = YES
DOT_IMAGE_FORMAT       = svg
INTERACTIVE_SVG        = YES
DOT_NUM_THREADS        = 4
DOT_TRANSPARENT        = YES
DOT_GRAPH_MAX_NODES    = 70
MAX_DOT_GRAPH_DEPTH    = 0
DOT_CLEANUP            = YES
DOTFILE_DIRS           = docs/graphs
CLASS_DIAGRAMS         = YES
CALL_GRAPH             = YES
CALLER_GRAPH           = YES
INCLUDE_GRAPH          = YES
INCLUDED_BY_GRAPH      = YES
EOT

cat > "$ROOT/firmware/docs/graphs/arch.dot" <<'EOT'
digraph "Arch" {
  rankdir=LR;
  node [shape=box, style=rounded, fontsize=10];
  subgraph cluster_ports { label="ports/"; color=gray;
    i2c[label="i2c_async_port"]; uart[label="uart_port"]; ow[label="onewire_port"]; time[label="time_port"]; log[label="log_sink"];
  }
  subgraph cluster_drivers { label="drivers/"; color=lightblue;
    lcd[label="lcd1602 (dev+fb)"]; ds[label="ds18b20"];
  }
  subgraph cluster_infra { label="infrastructure/"; color=lightgoldenrod;
    i2cs[label="idf_i2c_service"]; uarts[label="idf_uart_port"]; times[label="idf_time_port"]; ows[label="idf_onewire"];
  }
  app[shape=oval, label="app/main\n(UI,SENSOR,logger)"];
  app->lcd; app->ds; lcd->i2c; ds->ow; i2c->i2cs; uart->uarts; time->times; ow->ows; app->log;
}
EOT

cat > "$ROOT/firmware/docs/graphs/ds18_pipeline.dot" <<'EOT'
digraph "DS18 pipeline" {
  rankdir=LR; node[shape=box,style=rounded,fontsize=10];
  trig[label="trigger_convert"]; wait[label="wait t_conv (per res)"]; read[label="read scratchpad"]; upd[label="update UI"];
  trig->wait->read->upd;
}
EOT

echo "OK — Szkielet Clean-Arch + LCD+DS18 + Doxygen gotowy w firmware/"
