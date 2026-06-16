/*
 * canopen_basic.c - CiA 402 motor control (velocity mode).
 *
 * Sends expedited SDO downloads, waits for the slave's SDO response on
 * every write, and verifies the NMT operational state via heartbeat.
 * Based on the working Python reference at /Users/guoweifeng/canopen/canopen_servo.py.
 */

#include "canopen_basic.h"
#include "can_raw.h"
#include "watchdog.h"

#include <string.h>
#include <errno.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(canopen_basic, LOG_LEVEL_INF);

/* ---- CiA 402 object dictionary indices ---- */
#define OD_CONTROL_WORD          0x6040
#define OD_STATUS_WORD           0x6041
#define OD_MODE_OPERATION        0x6060
#define OD_MODE_DISPLAY          0x6061
#define OD_TARGET_VELOCITY       0x60FF
#define OD_TARGET_POSITION       0x607A
#define OD_PROFILE_VELOCITY      0x6081
#define OD_PROFILE_ACCELERATION  0x6083
#define OD_PROFILE_DECELERATION  0x6084
#define OD_ACTUAL_VELOCITY       0x606C
#define OD_ACTUAL_POSITION       0x6064
#define OD_CURRENT_ACTUAL        0x3001
#define OD_DC_LINK_VOLTAGE       0x6079
#define OD_TORQUE_ACTUAL         0x6077

/* ---- CiA 402 control word bits ---- */
#define CW_DISABLE_VOLTAGE       0x0000
#define CW_SHUTDOWN              0x0006
#define CW_SWITCH_ON             0x0007
#define CW_ENABLE_OPERATION      0x000F
#define CW_QUICK_STOP            0x0002
#define CW_FAULT_RESET           0x0080
#define CW_NEW_SET_POINT         0x001F  /* bit4: new set point */
#define CW_CHANGE_IMM            0x003F  /* bit4+bit5: change set immediately */

/* ---- CiA 402 mode codes ---- */
#define MODE_PROFILE_VELOCITY    3

/* ---- Timing (ms) ---- */
#define SDO_RESPONSE_TIMEOUT_MS  500
#define NMT_START_TIMEOUT_MS     5000
#define HEARTBEAT_POLL_MS        50

/* ---- Default motion parameters (from canopen_test.py) ---- */
#define DEFAULT_PROFILE_VELOCITY      100000
#define DEFAULT_PROFILE_ACCELERATION  100000
#define DEFAULT_PROFILE_DECELERATION  100000

/* ---- Conversion: UI rpm → motor pulse/s (adjust to match encoder) ---- */
#define UI_RPM_TO_PULSE_PER_SEC      100

/* ---- NMT states in heartbeat ---- */
#define NMT_STATE_OPERATIONAL  0x05
#define NMT_STATE_PRE_OP       0x7F
#define NMT_STATE_STOPPED      0x04

/* ---- Internals ---- */

/* Wait for a CAN frame matching a specific COB-ID on the bus.
 * Returns 1 (frame received), 0 (timeout), or <0 (error). */
static int can_wait_frame(uint32_t cob_id, can_frame_t *out, int timeout_ms)
{
	int64_t deadline = k_uptime_get() + timeout_ms;

	while (k_uptime_get() < deadline) {
		int ret = can_recv(out);
		if (ret == 1 && out->id == cob_id) {
			return 1;
		}
		/* N.B.: frames that don't match the COB-ID are silently dropped.
		 * In a production system we'd re-queue them, but for the
		 * single-motor dongle this is fine. */
		wdg_feed();
		k_msleep(5);
	}
	return 0; /* timeout */
}

/*
 * Send an expedited SDO download and wait for the slave's response.
 *
 * Returns 0 on success (slave responded with 0x60).
 * Returns -EIO if the slave responded with an abort (0x80).
 * Returns -ETIMEDOUT if no response arrived within SDO_RESPONSE_TIMEOUT_MS.
 */
int co_sdo_write(uint8_t node, uint16_t index, uint8_t sub,
			uint32_t value, uint8_t size)
{
	if (node < 1 || node > 127) {
		LOG_ERR("Invalid CANopen node: %u", node);
		return -EINVAL;
	}
	if (size != 1 && size != 2 && size != 4) {
		return -EINVAL;
	}

	uint32_t sdo_tx_id = 0x600 + node;
	uint32_t sdo_rx_id = 0x580 + node;

	can_frame_t frame;
	memset(&frame, 0, sizeof(frame));
	frame.id = sdo_tx_id;
	frame.dlc = 8;

	/* Command specifier */
	frame.data[0] = (size == 4) ? 0x23 : (size == 2) ? 0x2B : 0x2F;
	/* Index (little-endian) */
	frame.data[1] = index & 0xFF;
	frame.data[2] = (index >> 8) & 0xFF;
	/* Sub-index */
	frame.data[3] = sub;
	/* Data (little-endian) */
	frame.data[4] = value & 0xFF;
	frame.data[5] = (value >> 8) & 0xFF;
	frame.data[6] = (value >> 16) & 0xFF;
	frame.data[7] = (value >> 24) & 0xFF;

	LOG_DBG("SDO TX node=%u idx=0x%04X sub=%u value=0x%08X size=%u",
		node, index, sub, value, size);

	int ret = can_raw_send(&frame);
	if (ret < 0) {
		LOG_ERR("SDO TX failed node=%u idx=0x%04X ret=%d", node, index, ret);
		return ret;
	}

	/* Wait for SDO response */
	can_frame_t resp;
	ret = can_wait_frame(sdo_rx_id, &resp, SDO_RESPONSE_TIMEOUT_MS);
	if (ret == 0) {
		LOG_ERR("SDO timeout node=%u idx=0x%04X sub=%u", node, index, sub);
		return -ETIMEDOUT;
	}
	if (ret < 0) {
		LOG_ERR("SDO RX error node=%u idx=0x%04X ret=%d", node, index, ret);
		return ret;
	}

	uint8_t cs = resp.data[0];
	if (cs == 0x60) {
		LOG_DBG("SDO write OK node=%u idx=0x%04X", node, index);
		return 0;
	}
	if (cs == 0x80) {
		uint32_t err_code = resp.data[4] | (resp.data[5] << 8) |
				    (resp.data[6] << 16) | (resp.data[7] << 24);
		LOG_ERR("SDO abort node=%u idx=0x%04X sub=%u code=0x%08X",
			node, index, sub, err_code);
		return -EIO;
	}

	LOG_WRN("SDO unexpected response cs=0x%02X node=%u idx=0x%04X",
		cs, node, index);
	return -EIO;
}

/*
 * Send an SDO upload request and read the value.
 *
 * Returns the value on success, or a negative error code.
 * The caller should check (ret < 0) to detect errors.
 */
int co_sdo_read(uint8_t node, uint16_t index, uint8_t sub)
{
	uint32_t sdo_tx_id = 0x600 + node;
	uint32_t sdo_rx_id = 0x580 + node;

	can_frame_t frame;
	memset(&frame, 0, sizeof(frame));
	frame.id = sdo_tx_id;
	frame.dlc = 8;
	frame.data[0] = 0x40; /* upload request */
	frame.data[1] = index & 0xFF;
	frame.data[2] = (index >> 8) & 0xFF;
	frame.data[3] = sub;
	/* data[4..7] = 0 */

	int ret = can_raw_send(&frame);
	if (ret < 0) {
		LOG_ERR("SDO read TX failed node=%u idx=0x%04X ret=%d",
			node, index, ret);
		return ret;
	}

	/* Ignore non-matching frames until we get the response */
	can_frame_t resp;
	int64_t deadline = k_uptime_get() + SDO_RESPONSE_TIMEOUT_MS;
	while (k_uptime_get() < deadline) {
		ret = can_recv(&resp);
		if (ret != 1) {
			wdg_feed();
			k_msleep(5);
			continue;
		}
		if (resp.id != sdo_rx_id) {
			continue;
		}
		/* Verify index/sub match the request */
		uint16_t r_idx = resp.data[1] | (resp.data[2] << 8);
		uint8_t  r_sub = resp.data[3];
		if (r_idx != index || r_sub != sub) {
			continue;
		}

		uint8_t cs = resp.data[0];
		if (cs == 0x43) { /* 32-bit response */
			return (int)(resp.data[4] | (resp.data[5] << 8) |
				     (resp.data[6] << 16) | (resp.data[7] << 24));
		}
		if (cs == 0x4B) { /* 16-bit response */
			return (int16_t)(resp.data[4] | (resp.data[5] << 8));
		}
		if (cs == 0x4F) { /* 8-bit response */
			return (int8_t)resp.data[4];
		}
		if (cs == 0x80) { /* abort */
			uint32_t err = resp.data[4] | (resp.data[5] << 8) |
				       (resp.data[6] << 16) | (resp.data[7] << 24);
			LOG_ERR("SDO read abort node=%u idx=0x%04X sub=%u code=0x%08X",
				node, index, sub, err);
			return -EIO;
		}
		return -EIO;
	}

	LOG_ERR("SDO read timeout node=%u idx=0x%04X sub=%u", node, index, sub);
	return -ETIMEDOUT;
}

/* ---- NMT ---- */

int co_nmt_start(uint8_t node)
{
	can_frame_t frame;
	memset(&frame, 0, sizeof(frame));
	frame.id = 0x000;
	frame.dlc = 2;
	frame.data[0] = 0x01; /* NMT start */
	frame.data[1] = node;

	LOG_INF("NMT start node=%u", node);
	int ret = can_raw_send(&frame);
	if (ret < 0) {
		LOG_ERR("NMT start TX failed node=%u ret=%d", node, ret);
		return ret;
	}
	return 0;
}

static int co_nmt_reset_comm(uint8_t node)
{
	can_frame_t frame;
	memset(&frame, 0, sizeof(frame));
	frame.id = 0x000;
	frame.dlc = 2;
	frame.data[0] = 0x82; /* NMT reset communication */
	frame.data[1] = node;

	LOG_WRN("NMT reset communication node=%u", node);
	return can_raw_send(&frame);
}

int co_wait_operational(uint8_t node, int timeout_ms)
{
	uint32_t hb_id = 0x700 + node;

	LOG_INF("Waiting for node %u heartbeat (timeout=%d ms)...",
		node, timeout_ms);

	/* Send NMT start to wake up the motor */
	co_nmt_start(node);
	k_msleep(200);

	/* Also try SDO read of device type (0x1000) — some motors don't
	 * send heartbeat by default but respond to SDO */
	int dev_type = co_sdo_read(node, 0x1000, 0);
	if (dev_type >= 0) {
		LOG_INF("Node %u responds to SDO! Device type = 0x%08X", node, dev_type);
		/* Motor is alive via SDO, proceed as if operational */
		return 0;
	}
	if (dev_type == -ETIMEDOUT) {
		LOG_WRN("Node %u SDO timeout — motor not responding on CAN", node);
	}

	int64_t deadline = k_uptime_get() + timeout_ms;
	while (k_uptime_get() < deadline) {
		can_frame_t frame;
		int ret = can_recv(&frame);
		if (ret == 1 && frame.id == hb_id) {
			uint8_t state = frame.data[0];
			LOG_INF("Heartbeat node=%u state=0x%02X", node, state);

			if (state == NMT_STATE_OPERATIONAL) {
				LOG_INF("Node %u is Operational", node);
				return 0;
			}
			if (state == NMT_STATE_PRE_OP) {
				LOG_INF("Node %u in Pre-op, sending NMT start...",
					node);
				co_nmt_start(node);
			} else if (state == NMT_STATE_STOPPED) {
				LOG_WRN("Node %u is Stopped, sending NMT start...",
					node);
				co_nmt_start(node);
			}
		}
		wdg_feed();
		k_msleep(HEARTBEAT_POLL_MS);
	}

	LOG_ERR("Node %u did not reach Operational within %d ms", node, timeout_ms);
	return -ETIMEDOUT;
}

/* ---- CiA 402 enable / disable ---- */

int co_basic_enable(uint8_t node)
{
	int ret;

	LOG_INF("=== CANopen enable node=%u ===", node);

	ret = can_force_recover("before CANopen enable");
	if (ret < 0) {
		LOG_WRN("CAN recovery failed node=%u ret=%d, trying anyway", node, ret);
	}

	/* Step 0: Best-effort NMT start. The previous Python control script does
	 * not make heartbeat mandatory before the CiA 402 control-word sequence;
	 * some drives respond to SDO but do not emit heartbeat in the expected
	 * window. Keep enable responsive and let the SDO writes prove the link.
	 */
	ret = co_nmt_start(node);
	if (ret < 0) {
		LOG_WRN("NMT start failed node=%u ret=%d, trying SDO sequence anyway",
			node, ret);
	}
	k_msleep(100);

	/* Select Profile Velocity before enabling. 0x6060 is an int8 object, so
	 * writing it as a 32-bit value is rejected by some drives.
	 */
	ret = co_sdo_write(node, OD_MODE_OPERATION, 0, MODE_PROFILE_VELOCITY, 1);
	if (ret < 0) {
		LOG_WRN("Set operation mode failed node=%u ret=%d, recovering and retrying",
			node, ret);
		(void)can_force_recover("retry after mode write failed");
		(void)co_nmt_reset_comm(node);
		k_msleep(1200);
		(void)co_nmt_start(node);
		k_msleep(300);
		ret = co_sdo_write(node, OD_MODE_OPERATION, 0, MODE_PROFILE_VELOCITY, 1);
		if (ret < 0) {
			LOG_WRN("Set operation mode retry failed node=%u ret=%d, continuing",
				node, ret);
		}
	}
	k_msleep(50);

	/* Step 1: Fault reset (belt-and-suspenders) */
	co_sdo_write(node, OD_CONTROL_WORD, 0, CW_FAULT_RESET, 2);
	k_msleep(100);

	/* Step 2: Shutdown → Switch On → Enable Operation */
	ret = co_sdo_write(node, OD_CONTROL_WORD, 0, CW_SHUTDOWN, 2);
	if (ret < 0) { LOG_ERR("Shutdown failed"); return ret; }
	k_msleep(200);

	ret = co_sdo_write(node, OD_CONTROL_WORD, 0, CW_SWITCH_ON, 2);
	if (ret < 0) { LOG_ERR("Switch On failed"); return ret; }
	k_msleep(200);

	ret = co_sdo_write(node, OD_CONTROL_WORD, 0, CW_ENABLE_OPERATION, 2);
	if (ret < 0) { LOG_ERR("Enable Operation failed"); return ret; }
	k_msleep(200);

	/* Step 3: Verify status word (bits 0-3 should be 0x7 = Operation Enabled) */
	int sw = co_sdo_read(node, OD_STATUS_WORD, 0);
	if (sw < 0) {
		LOG_WRN("Failed to read status word after enable: %d", sw);
		/* Continue anyway — motor might still work */
	} else if ((sw & 0x006F) == 0x0027) {
		LOG_INF("Motor enabled OK (status=0x%04X)", sw);
	} else {
		LOG_WRN("Motor status=0x%04X after enable (expected 0x0027)", sw);
	}

	LOG_INF("=== Motor enabled node=%u ===", node);
	return 0;
}

int co_basic_disable(uint8_t node)
{
	int ret;

	LOG_INF("Disable motor node=%u", node);

	/* Quick stop first, then disable voltage */
	co_sdo_write(node, OD_CONTROL_WORD, 0, CW_QUICK_STOP, 2);
	k_msleep(100);

	ret = co_sdo_write(node, OD_CONTROL_WORD, 0, CW_DISABLE_VOLTAGE, 2);
	if (ret < 0) {
		LOG_WRN("Disable voltage write failed: %d", ret);
		return ret;
	}
	k_msleep(100);

	LOG_INF("Motor disabled node=%u", node);
	return 0;
}

/* ---- Profile configuration ---- */

int co_init_profile(uint8_t node)
{
	int ret;

	LOG_INF("Configuring motion profile node=%u", node);

	/* Set velocity mode */
	ret = co_sdo_write(node, OD_MODE_OPERATION, 0, MODE_PROFILE_VELOCITY, 1);
	if (ret < 0) return ret;
	k_msleep(200);

	/* Verify mode was accepted */
	int mode = co_sdo_read(node, OD_MODE_DISPLAY, 0);
	if (mode == MODE_PROFILE_VELOCITY) {
		LOG_INF("Profile Velocity mode confirmed");
	} else {
		LOG_WRN("Mode display = %d (expected %d), continuing anyway",
			mode, MODE_PROFILE_VELOCITY);
	}

	/* Configure profile parameters */
	ret = co_sdo_write(node, OD_PROFILE_VELOCITY, 0,
			   DEFAULT_PROFILE_VELOCITY, 4);
	if (ret < 0) return ret;
	k_msleep(50);

	ret = co_sdo_write(node, OD_PROFILE_ACCELERATION, 0,
			   DEFAULT_PROFILE_ACCELERATION, 4);
	if (ret < 0) return ret;
	k_msleep(50);

	ret = co_sdo_write(node, OD_PROFILE_DECELERATION, 0,
			   DEFAULT_PROFILE_DECELERATION, 4);
	if (ret < 0) return ret;
	k_msleep(50);

	LOG_INF("Motion profile configured: vel=%d acc=%d dec=%d pulse/s",
		DEFAULT_PROFILE_VELOCITY,
		DEFAULT_PROFILE_ACCELERATION,
		DEFAULT_PROFILE_DECELERATION);
	return 0;
}

/* ---- Jog / motion (velocity mode) ---- */

int co_basic_jog(uint8_t node, int rpm)
{
	/* rpm > 0 = cw, rpm < 0 = ccw */
	int velocity = rpm * UI_RPM_TO_PULSE_PER_SEC;

	LOG_INF("Jog node=%u rpm=%d → velocity=%d pulse/s", node, rpm, velocity);

	/* In velocity mode, just write target velocity — motor spins continuously.
	 * Hold button → velocity stays, release → stop sends 0 velocity. */
	int ret = co_sdo_write(node, OD_TARGET_VELOCITY, 0,
			       (uint32_t)(int32_t)velocity, 4);
	if (ret < 0) {
		LOG_ERR("Jog velocity write failed node=%u ret=%d", node, ret);
	}
	return ret;
}

int co_basic_stop(uint8_t node)
{
	LOG_INF("Stop motor node=%u", node);

	/* Set target velocity to 0 + quick stop */
	co_sdo_write(node, OD_TARGET_VELOCITY, 0, 0, 4);
	k_msleep(50);
	return co_sdo_write(node, OD_CONTROL_WORD, 0, CW_QUICK_STOP, 2);
}

int co_basic_estop(uint8_t node)
{
	LOG_WRN("E-STOP node=%u", node);

	/* Quick stop + disable voltage */
	co_sdo_write(node, OD_CONTROL_WORD, 0, CW_QUICK_STOP, 2);
	k_msleep(20);
	return co_sdo_write(node, OD_CONTROL_WORD, 0, CW_DISABLE_VOLTAGE, 2);
}

/* ---- Read live motor data ---- */

int co_read_status_word(uint8_t node)
{
	return co_sdo_read(node, OD_STATUS_WORD, 0);
}

int co_read_actual_velocity(uint8_t node)
{
	return co_sdo_read(node, OD_ACTUAL_VELOCITY, 0);
}

int co_read_actual_current(uint8_t node)
{
	return co_sdo_read(node, OD_CURRENT_ACTUAL, 0);
}

int co_read_dc_link_voltage(uint8_t node)
{
	return co_sdo_read(node, OD_DC_LINK_VOLTAGE, 0);
}

int co_read_actual_torque(uint8_t node)
{
	return co_sdo_read(node, OD_TORQUE_ACTUAL, 0);
}

int co_read_actual_position(uint8_t node)
{
	return co_sdo_read(node, OD_ACTUAL_POSITION, 0);
}
