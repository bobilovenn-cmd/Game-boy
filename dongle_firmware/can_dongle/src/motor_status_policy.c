#include "motor_status_policy.h"

bool motor_status_word_has_fault(uint16_t status_word)
{
	return (status_word & 0x0008U) != 0U;
}

bool motor_estop_should_latch(int command_result)
{
	return command_result == 0;
}

enum motor_display_status motor_display_status_resolve(bool alive,
						       bool status_fresh,
						       bool drive_fault,
						       bool estop_latched)
{
	if (estop_latched) {
		return MOTOR_DISPLAY_ESTOP;
	}
	if (!alive) {
		return MOTOR_DISPLAY_OFFLINE;
	}
	if (!status_fresh) {
		return MOTOR_DISPLAY_STALE;
	}
	if (drive_fault) {
		return MOTOR_DISPLAY_DRIVE_FAULT;
	}
	return MOTOR_DISPLAY_READY;
}

const char *motor_display_status_name(enum motor_display_status status)
{
	switch (status) {
	case MOTOR_DISPLAY_ESTOP:
		return "estop";
	case MOTOR_DISPLAY_DRIVE_FAULT:
		return "drive_fault";
	case MOTOR_DISPLAY_READY:
		return "ready";
	case MOTOR_DISPLAY_STALE:
		return "stale";
	case MOTOR_DISPLAY_OFFLINE:
	default:
		return "offline";
	}
}
