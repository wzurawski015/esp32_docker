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
