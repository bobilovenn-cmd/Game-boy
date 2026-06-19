#pragma once

#include <stdint.h>
#include "json_protocol.h"

uint8_t command_resolve_node(cmd_type_t command, int packet_node,
			     uint8_t active_node);
bool command_updates_active_node(cmd_type_t command);
