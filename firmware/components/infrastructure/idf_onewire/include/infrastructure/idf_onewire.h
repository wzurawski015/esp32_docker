#pragma once
#include "ports/onewire_port.h"
typedef struct { int gpio; bool internal_pullup; } idf_onewire_cfg_t;
ca_status_t idf_onewire_create(const idf_onewire_cfg_t* cfg, onewire_port_t* out);
