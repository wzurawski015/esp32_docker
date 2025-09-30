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
