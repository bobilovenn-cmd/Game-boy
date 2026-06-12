/*
 * canopen_basic.h - Minimal CANopen/CiA 402 control helpers.
 *
 * Phase 0.5 goal: make RGB30 commands move one CANopen motor node.
 */
#pragma once

#include <stdint.h>

int co_basic_enable(uint8_t node);
int co_basic_disable(uint8_t node);
int co_basic_jog(uint8_t node, int rpm);
int co_basic_stop(uint8_t node);
int co_basic_estop(uint8_t node);

