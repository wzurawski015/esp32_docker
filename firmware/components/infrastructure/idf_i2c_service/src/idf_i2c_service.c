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
