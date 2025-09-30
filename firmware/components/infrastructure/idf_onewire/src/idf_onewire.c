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
