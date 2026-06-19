#pragma once

#include <stdbool.h>
#include <stdint.h>

enum motor_display_status {
	MOTOR_DISPLAY_OFFLINE = 0,
	MOTOR_DISPLAY_STALE,
	MOTOR_DISPLAY_READY,
	MOTOR_DISPLAY_DRIVE_FAULT,
	MOTOR_DISPLAY_ESTOP,
};

bool motor_status_word_has_fault(uint16_t status_word);
bool motor_estop_should_latch(int command_result);
enum motor_display_status motor_display_status_resolve(bool alive,
						       bool status_fresh,
						       bool drive_fault,
						       bool estop_latched);
const char *motor_display_status_name(enum motor_display_status status);
