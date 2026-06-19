#include "canopen_basic.h"
#include "can_raw.h"
#include "sdo_transport.h"

#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(canopen_basic, LOG_LEVEL_INF);

int co_basic_enable(uint8_t node)
{
	int ret;
	LOG_INF("=== CANopen enable node=%u ===", node);
	(void)can_force_recover("before CANopen enable");
	(void)nmt_start(node);
	k_msleep(100);

	ret = sdo_write(node, OD_MODE_OPERATION, 0, MODE_PROFILE_VELOCITY, 1);
	if (ret < 0) {
		LOG_WRN("Mode write failed node=%u ret=%d, resetting communication", node, ret);
		(void)can_force_recover("retry after mode write failed");
		(void)nmt_reset_comm(node);
		k_msleep(1200);
		(void)nmt_start(node);
		k_msleep(300);
		ret = sdo_write(node, OD_MODE_OPERATION, 0, MODE_PROFILE_VELOCITY, 1);
		if (ret < 0) return ret;
	}

	(void)sdo_write(node, OD_CONTROL_WORD, 0, CW_FAULT_RESET, 2);
	k_msleep(100);
	ret = sdo_write(node, OD_CONTROL_WORD, 0, CW_SHUTDOWN, 2);
	if (ret < 0) return ret;
	k_msleep(200);
	ret = sdo_write(node, OD_CONTROL_WORD, 0, CW_SWITCH_ON, 2);
	if (ret < 0) return ret;
	k_msleep(200);
	ret = sdo_write(node, OD_CONTROL_WORD, 0, CW_ENABLE_OPERATION, 2);
	if (ret < 0) return ret;
	k_msleep(200);

	uint16_t status;
	ret = co_read_status_word(node, &status);
	if (ret == 0) LOG_INF("Motor enabled status=0x%04X", status);
	return 0;
}

int co_basic_disable(uint8_t node)
{
	LOG_INF("Disable motor node=%u", node);
	(void)sdo_write(node, OD_CONTROL_WORD, 0, CW_QUICK_STOP, 2);
	k_msleep(100);
	int ret = sdo_write(node, OD_CONTROL_WORD, 0, CW_DISABLE_VOLTAGE, 2);
	k_msleep(100);
	if (ret == 0) LOG_INF("Motor disabled node=%u", node);
	return ret;
}

int co_basic_estop(uint8_t node)
{
	LOG_WRN("E-STOP node=%u", node);
	(void)sdo_write(node, OD_CONTROL_WORD, 0, CW_QUICK_STOP, 2);
	k_msleep(20);
	return sdo_write(node, OD_CONTROL_WORD, 0, CW_DISABLE_VOLTAGE, 2);
}

int co_init_profile(uint8_t node)
{
	int ret = sdo_write(node, OD_MODE_OPERATION, 0, MODE_PROFILE_VELOCITY, 1);
	if (ret < 0) return ret;
	k_msleep(200);
	ret = sdo_write(node, OD_PROFILE_VELOCITY, 0, DEFAULT_PROFILE_VELOCITY, 4);
	if (ret < 0) return ret;
	ret = sdo_write(node, OD_PROFILE_ACCELERATION, 0, DEFAULT_PROFILE_ACCELERATION, 4);
	if (ret < 0) return ret;
	return sdo_write(node, OD_PROFILE_DECELERATION, 0, DEFAULT_PROFILE_DECELERATION, 4);
}

int co_basic_jog(uint8_t node, int32_t velocity)
{
	return sdo_write(node, OD_TARGET_VELOCITY, 0, (uint32_t)velocity, 4);
}

int co_move_to_position(uint8_t node, int32_t position, int32_t speed)
{
	uint32_t velocity = speed < 0 ? (uint32_t)-speed : (uint32_t)speed;
	if (velocity == 0) velocity = DEFAULT_PROFILE_VELOCITY;
	(void)nmt_start(node);
	int ret = sdo_write(node, OD_MODE_OPERATION, 0, MODE_PROFILE_POSITION, 1);
	if (ret < 0) return ret;
	ret = sdo_write(node, OD_PROFILE_VELOCITY, 0, velocity, 4);
	if (ret < 0) return ret;
	ret = sdo_write(node, OD_TARGET_POSITION, 0, (uint32_t)position, 4);
	if (ret < 0) return ret;
	ret = sdo_write(node, OD_CONTROL_WORD, 0, CW_ENABLE_OPERATION, 2);
	if (ret < 0) return ret;
	return sdo_write(node, OD_CONTROL_WORD, 0, CW_CHANGE_IMM, 2);
}

int co_basic_stop(uint8_t node)
{
	(void)sdo_write(node, OD_TARGET_VELOCITY, 0, 0, 4);
	return sdo_write(node, OD_CONTROL_WORD, 0, CW_QUICK_STOP, 2);
}

int co_read_status_word(uint8_t node, uint16_t *value)
{
	return sdo_read_u16(node, OD_STATUS_WORD, 0, value);
}

int co_read_actual_velocity(uint8_t node, int32_t *value)
{
	return sdo_read_i32(node, OD_ACTUAL_VELOCITY, 0, value);
}

int co_read_actual_current(uint8_t node, int32_t *value)
{
	return sdo_read_i32(node, OD_CURRENT_ACTUAL, 0, value);
}

int co_read_dc_link_voltage(uint8_t node, uint32_t *value)
{
	return sdo_read_u32(node, OD_DC_LINK_VOLTAGE, 0, value);
}

int co_read_actual_torque(uint8_t node, int16_t *value)
{
	return sdo_read_i16(node, OD_TORQUE_ACTUAL, 0, value);
}

int co_read_actual_position(uint8_t node, int32_t *value)
{
	return sdo_read_i32(node, OD_ACTUAL_POSITION, 0, value);
}
