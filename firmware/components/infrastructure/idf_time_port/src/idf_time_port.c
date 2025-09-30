#include "infrastructure/idf_time_port.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_timer.h"
static void sleep_ms(uint32_t ms){ vTaskDelay(pdMS_TO_TICKS(ms)); }
static uint64_t now_us(void){ return esp_timer_get_time(); }
void idf_time_create(time_port_t* out){ out->sleep_ms=sleep_ms; out->now_monotonic_us=now_us; }
