/*
 * canopen_basic.c - Minimal CANopen/CiA 402 control helpers.
 *
 * This sends expedited SDO writes directly:
 *   0x6060: mode of operation
 *   0x6040: control word
 *   0x60FF: target velocity
 *
 * Assumption for first motor-spin test:
 *   - Node supports CiA 402 profile velocity mode (mode 3)
 *   - Target velocity unit accepted by the drive is close enough to UI rpm
 */

#include "canopen_basic.h"
#include "can_raw.h"

#include <string.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(canopen_basic, LOG_LEVEL_INF);

#define OD_CONTROL_WORD      0x6040
#define OD_MODE_OPERATION    0x6060
#define OD_TARGET_VELOCITY   0x60FF

#define MODE_PROFILE_VELOCITY 3
#define UI_SPEED_TO_PULSE_PER_SEC 100

static int co_sdo_write(uint8_t node, uint16_t index, uint8_t sub,
			uint32_t value, uint8_t size)
{
	if (node < 1 || node > 127) {
		LOG_ERR("Invalid CANopen node: %u", node);
		return -EINVAL;
	}
	if (size != 1 && size != 2 && size != 4) {
		return -EINVAL;
	}

	can_frame_t frame;
	memset(&frame, 0, sizeof(frame));
	frame.id = 0x600 + node;
	frame.dlc = 8;
	frame.data[0] = (size == 4) ? 0x23 : (size == 2) ? 0x2B : 0x2F;
	frame.data[1] = index & 0xFF;
	frame.data[2] = (index >> 8) & 0xFF;
	frame.data[3] = sub;
	frame.data[4] = value & 0xFF;
	frame.data[5] = (value >> 8) & 0xFF;
	frame.data[6] = (value >> 16) & 0xFF;
	frame.data[7] = (value >> 24) & 0xFF;

	LOG_INF("SDO write node=%u idx=0x%04X sub=%u value=0x%08X size=%u",
		node, index, sub, value, size);
	int ret = can_raw_send(&frame);
	if (ret < 0) {
		LOG_ERR("SDO write failed node=%u idx=0x%04X ret=%d",
			node, index, ret);
	}
	return ret;
}

static int co_nmt_start(uint8_t node)
{
	can_frame_t frame;
	memset(&frame, 0, sizeof(frame));
	frame.id = 0x000;
	frame.dlc = 2;
	frame.data[0] = 0x01;
	frame.data[1] = node;
	LOG_INF("CANopen NMT start node=%u", node);
	return can_raw_send(&frame);
}

static void gap_ms(int ms)
{
	k_msleep(ms);
}

int co_basic_enable(uint8_t node)
{
	int ret;

	LOG_INF("CANopen enable node=%u", node);
	co_nmt_start(node);
	gap_ms(50);

	ret = co_sdo_write(node, OD_CONTROL_WORD, 0, 0x0000, 2);
	if (ret < 0) return ret;
	gap_ms(50);

	ret = co_sdo_write(node, OD_CONTROL_WORD, 0, 0x0080, 2);
	if (ret < 0) return ret;
	gap_ms(50);

	ret = co_sdo_write(node, OD_MODE_OPERATION, 0, MODE_PROFILE_VELOCITY, 1);
	if (ret < 0) return ret;
	gap_ms(200);

	ret = co_sdo_write(node, OD_CONTROL_WORD, 0, 0x0006, 2);
	if (ret < 0) return ret;
	gap_ms(200);

	ret = co_sdo_write(node, OD_CONTROL_WORD, 0, 0x0007, 2);
	if (ret < 0) return ret;
	gap_ms(200);

	return co_sdo_write(node, OD_CONTROL_WORD, 0, 0x000F, 2);
}

int co_basic_disable(uint8_t node)
{
	LOG_INF("CANopen disable node=%u", node);
	co_sdo_write(node, OD_TARGET_VELOCITY, 0, 0, 4);
	gap_ms(50);
	return co_sdo_write(node, OD_CONTROL_WORD, 0, 0x0000, 2);
}

int co_basic_jog(uint8_t node, int rpm)
{
	int velocity = rpm * UI_SPEED_TO_PULSE_PER_SEC;

	LOG_INF("CANopen jog node=%u ui_speed=%d velocity=%d pulse/s",
		node, rpm, velocity);
	co_sdo_write(node, OD_MODE_OPERATION, 0, MODE_PROFILE_VELOCITY, 1);
	gap_ms(100);
	co_sdo_write(node, OD_CONTROL_WORD, 0, 0x000F, 2);
	gap_ms(50);
	return co_sdo_write(node, OD_TARGET_VELOCITY, 0, (uint32_t)velocity, 4);
}

int co_basic_stop(uint8_t node)
{
	LOG_INF("CANopen stop node=%u", node);
	co_sdo_write(node, OD_TARGET_VELOCITY, 0, 0, 4);
	gap_ms(50);
	return co_sdo_write(node, OD_CONTROL_WORD, 0, 0x0002, 2);
}

int co_basic_estop(uint8_t node)
{
	LOG_WRN("CANopen quick stop node=%u", node);
	co_sdo_write(node, OD_TARGET_VELOCITY, 0, 0, 4);
	gap_ms(50);
	return co_sdo_write(node, OD_CONTROL_WORD, 0, 0x0002, 2);
}
