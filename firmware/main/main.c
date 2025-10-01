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

static i2c_async_port_t I2C0;
static ca_uart_port_t   UART0;
static time_port_t      TIMEP;
static onewire_port_t   ONEW;

static lcd1602_dev_t    LCD_DEV;
static lcd1602_fb_t     LCD_FB;
static ds18b20_t        DS;

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
    idf_uart_create(&(idf_uart_cfg_t){ .uart_num=CONFIG_APP_UART_NUM, .tx_gpio=CONFIG_APP_UART_TX, .rx_gpio=CONFIG_APP_UART_RX, .baud=CONFIG_APP_UART_BAUD, .rx_buf_bytes=2048 }, &UART0);
    idf_time_create(&TIMEP);

    log_sink_t sink; logger_uart_sink_create(&UART0, &sink);
    logger_init(&(logger_cfg_t){ .timep=&TIMEP, .queue_len=256, .max_line=256, .consumer_prio=9, .consumer_stack=4096 });
    logger_add_sink(&sink);
    logger_set_level_global(LOG_INFO);
    LOG_I("APP ","boot");

    idf_i2c_service_start(&(idf_i2c_service_cfg_t){
        .idf_port=0, /* port 0 (zamiast bezpośredniego I2C_NUM_0) */
        .sda_gpio=CONFIG_APP_I2C_SDA,
        .scl_gpio=CONFIG_APP_I2C_SCL,
        .clk_hz=CONFIG_APP_I2C_HZ,
        .queue_len=32, .task_prio=8, .task_stack=4096
    }, &I2C0);

    idf_onewire_create(&(idf_onewire_cfg_t){ .gpio=CONFIG_APP_OW_GPIO, .internal_pullup=true }, &ONEW);

    lcd1602_dev_init(&LCD_DEV, &(lcd1602_dev_cfg_t){ .i2c=&I2C0, .time=&TIMEP, .addr7=CONFIG_APP_LCD_ADDR, .cols=16, .rows=2 }, NULL, NULL);
    lcd1602_fb_init(&LCD_FB, &LCD_DEV);
    ds18b20_init(&DS, &(ds18b20_cfg_t){ .ow=&ONEW, .time=&TIMEP, .res_bits=CONFIG_APP_DS_RES, .single_drop=true });

    xTaskCreate(ui_task, "ui", 4096, NULL, 4, NULL);
    xTaskCreate(sensor_task, "sensor", 4096, NULL, 5, NULL);
}
