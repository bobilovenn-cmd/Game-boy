#pragma once

#include <stdint.h>
#include "sdo_transport.h"

#define co_sdo_write sdo_write

int co_basic_enable(uint8_t node);
int co_basic_disable(uint8_t node);
int co_basic_estop(uint8_t node);
int co_init_profile(uint8_t node);
int co_basic_jog(uint8_t node, int32_t velocity);
int co_move_to_position(uint8_t node, int32_t position, int32_t speed);
int co_basic_stop(uint8_t node);

int co_read_status_word(uint8_t node, uint16_t *value);
int co_read_actual_velocity(uint8_t node, int32_t *value);
int co_read_actual_current(uint8_t node, int32_t *value);
int co_read_dc_link_voltage(uint8_t node, uint32_t *value);
int co_read_actual_torque(uint8_t node, int16_t *value);
int co_read_actual_position(uint8_t node, int32_t *value);
