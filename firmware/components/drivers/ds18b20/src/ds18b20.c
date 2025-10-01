#include "drivers/ds18b20.h"
#include <string.h>

#define CMD_SKIP_ROM   0xCC
#define CMD_MATCH_ROM  0x55
#define CMD_CONVERT_T  0x44
#define CMD_READ_SCR   0xBE
#define CMD_WRITE_SCR  0x4E

static int select(const ds18b20_t* h){
    bool p=false;
    if(h->ow->reset(h->ow->ctx,&p)!=CA_OK) return -1;
    if(!p) return -1;
    if(h->single_drop){
        uint8_t c=CMD_SKIP_ROM;
        return h->ow->write_bytes(h->ow->ctx,&c,1);
    }
    uint8_t b[9]; b[0]=CMD_MATCH_ROM; memcpy(&b[1],h->rom,8);
    return h->ow->write_bytes(h->ow->ctx,b,9);
}

int ds18b20_init(ds18b20_t* h, const ds18b20_cfg_t* c){
    if(!h||!c||!c->ow||!c->time) {
        return -1;
    }
    memset(h,0,sizeof(*h));
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

int ds18b20_trigger_convert(ds18b20_t* h){
    if(select(h)!=0) return -1;
    uint8_t c=CMD_CONVERT_T;
    return h->ow->write_bytes(h->ow->ctx,&c,1);
}

bool ds18b20_poll_ready(ds18b20_t* h){
    uint8_t bit=0; return h->ow->read_bit(h->ow->ctx,&bit)==CA_OK && bit!=0;
}

int ds18b20_read_celsius(ds18b20_t* h, float* out){
    if (select(h)!=0) return -1;
    uint8_t cmd=CMD_READ_SCR;
    if(h->ow->write_bytes(h->ow->ctx,&cmd,1)!=0) return -1;
    uint8_t s[9]; if(h->ow->read_bytes(h->ow->ctx,s,9)!=0) return -1;
    int16_t raw = (int16_t)((s[1]<<8)|s[0]);
    *out=(float)raw/16.0f;
    return 0;
}
