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
