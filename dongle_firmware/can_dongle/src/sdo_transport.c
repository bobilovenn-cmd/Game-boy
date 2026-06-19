/*
 * sdo_transport.c - CANopen SDO 传输层实现
 */

#include "sdo_transport.h"
#include "can_raw.h"
#include "json_protocol.h"
#include "udp_comm.h"

#include <string.h>
#include <errno.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(sdo, LOG_LEVEL_INF);

static int can_wait_sdo_response(uint32_t cob_id, uint16_t index, uint8_t sub,
				 can_frame_t *out, int timeout_ms)
{
	int64_t deadline = k_uptime_get() + timeout_ms;

	while (k_uptime_get() < deadline) {
		int ret = can_recv(out);
		if (ret == 1) {
			char log_buf[128];
			int log_len = json_build_can_log(log_buf, sizeof(log_buf),
							 out->id, out->data, out->dlc);
			udp_send(log_buf, log_len);
			if (out->id == cob_id &&
			    (uint16_t)(out->data[1] |
				       ((uint16_t)out->data[2] << 8)) == index &&
			    out->data[3] == sub) {
				return 1;
			}
		} else if (ret < 0) {
			return ret;
		}
		k_msleep(5);
	}
	return 0;
}

int sdo_write(uint8_t node, uint16_t index, uint8_t sub, uint32_t value, uint8_t size)
{
	if (node < 1 || node > 127) return -EINVAL;
	if (size != 1 && size != 2 && size != 4) return -EINVAL;

	uint32_t tx_id = 0x600 + node;
	uint32_t rx_id = 0x580 + node;

	can_frame_t frame;
	memset(&frame, 0, sizeof(frame));
	frame.id = tx_id;
	frame.dlc = 8;

	frame.data[0] = (size == 4) ? 0x23 : (size == 2) ? 0x2B : 0x2F;
	frame.data[1] = index & 0xFF;
	frame.data[2] = (index >> 8) & 0xFF;
	frame.data[3] = sub;
	frame.data[4] = value & 0xFF;
	frame.data[5] = (value >> 8) & 0xFF;
	frame.data[6] = (value >> 16) & 0xFF;
	frame.data[7] = (value >> 24) & 0xFF;

	int ret = can_raw_send(&frame);
	if (ret < 0) {
		LOG_ERR("SDO TX failed node=%u idx=0x%04X ret=%d", node, index, ret);
		return ret;
	}

	can_frame_t resp;
	ret = can_wait_sdo_response(rx_id, index, sub, &resp,
				    SDO_RESPONSE_TIMEOUT_MS);
	if (ret == 0) {
		LOG_ERR("SDO timeout node=%u idx=0x%04X sub=%u", node, index, sub);
		return -ETIMEDOUT;
	}
	if (ret < 0) return ret;

	uint8_t cs = resp.data[0];
	if (cs == 0x60) return 0;
	if (cs == 0x80) {
		uint32_t err = (uint32_t)resp.data[4] |
			       ((uint32_t)resp.data[5] << 8) |
			       ((uint32_t)resp.data[6] << 16) |
			       ((uint32_t)resp.data[7] << 24);
		LOG_ERR("SDO abort node=%u idx=0x%04X sub=%u code=0x%08X",
			node, index, sub, err);
		return -EIO;
	}
	LOG_WRN("SDO unexpected cs=0x%02X node=%u idx=0x%04X", cs, node, index);
	return -EIO;
}

int sdo_read_u32(uint8_t node, uint16_t index, uint8_t sub, uint32_t *value)
{
	if (node < 1 || node > 127 || value == NULL) {
		return -EINVAL;
	}

	uint32_t tx_id = 0x600 + node;
	uint32_t rx_id = 0x580 + node;

	can_frame_t frame;
	memset(&frame, 0, sizeof(frame));
	frame.id = tx_id;
	frame.dlc = 8;
	frame.data[0] = 0x40;
	frame.data[1] = index & 0xFF;
	frame.data[2] = (index >> 8) & 0xFF;
	frame.data[3] = sub;

	int ret = can_raw_send(&frame);
	if (ret < 0) {
		LOG_ERR("SDO read TX failed node=%u idx=0x%04X ret=%d", node, index, ret);
		return ret;
	}

	can_frame_t resp;
	int64_t deadline = k_uptime_get() + SDO_RESPONSE_TIMEOUT_MS;
	while (k_uptime_get() < deadline) {
		ret = can_recv(&resp);
		if (ret != 1) { k_msleep(5); continue; }

		char log_buf[128];
		int log_len = json_build_can_log(log_buf, sizeof(log_buf),
						 resp.id, resp.data, resp.dlc);
		udp_send(log_buf, log_len);

		if (resp.id != rx_id) continue;

		if (resp.dlc < 4) continue;

		uint16_t r_idx = (uint16_t)(resp.data[1] |
					    ((uint16_t)resp.data[2] << 8));
		uint8_t  r_sub = resp.data[3];
		if (r_idx != index || r_sub != sub) continue;

		uint8_t cs = resp.data[0];
		if (cs == 0x43) {
			*value = (uint32_t)resp.data[4] |
				 ((uint32_t)resp.data[5] << 8) |
				 ((uint32_t)resp.data[6] << 16) |
				 ((uint32_t)resp.data[7] << 24);
			return 0;
		}
		if (cs == 0x4B) {
			*value = (uint32_t)resp.data[4] |
				 ((uint32_t)resp.data[5] << 8);
			return 0;
		}
		if (cs == 0x4F) {
			*value = resp.data[4];
			return 0;
		}
		if (cs == 0x80) {
			uint32_t err = (uint32_t)resp.data[4] |
				       ((uint32_t)resp.data[5] << 8) |
				       ((uint32_t)resp.data[6] << 16) |
				       ((uint32_t)resp.data[7] << 24);
			LOG_ERR("SDO read abort node=%u idx=0x%04X sub=%u code=0x%08X",
				node, index, sub, err);
			return -EIO;
		}
		return -EIO;
	}

	LOG_ERR("SDO read timeout node=%u idx=0x%04X sub=%u", node, index, sub);
	return -ETIMEDOUT;
}

int sdo_read_i8(uint8_t node, uint16_t index, uint8_t sub, int8_t *value)
{
	uint32_t raw;
	int ret = value ? sdo_read_u32(node, index, sub, &raw) : -EINVAL;
	if (ret == 0) *value = (int8_t)(uint8_t)raw;
	return ret;
}

int sdo_read_i16(uint8_t node, uint16_t index, uint8_t sub, int16_t *value)
{
	uint32_t raw;
	int ret = value ? sdo_read_u32(node, index, sub, &raw) : -EINVAL;
	if (ret == 0) *value = (int16_t)(uint16_t)raw;
	return ret;
}

int sdo_read_u16(uint8_t node, uint16_t index, uint8_t sub, uint16_t *value)
{
	uint32_t raw;
	int ret = value ? sdo_read_u32(node, index, sub, &raw) : -EINVAL;
	if (ret == 0) *value = (uint16_t)raw;
	return ret;
}

int sdo_read_i32(uint8_t node, uint16_t index, uint8_t sub, int32_t *value)
{
	uint32_t raw;
	int ret = value ? sdo_read_u32(node, index, sub, &raw) : -EINVAL;
	if (ret == 0) *value = (int32_t)raw;
	return ret;
}

/* ---- NMT ---- */
int nmt_start(uint8_t node)
{
	can_frame_t frame;
	memset(&frame, 0, sizeof(frame));
	frame.id = 0x000;
	frame.dlc = 2;
	frame.data[0] = 0x01;
	frame.data[1] = node;

	LOG_INF("NMT start node=%u", node);
	int ret = can_raw_send(&frame);
	if (ret < 0) {
		LOG_ERR("NMT start TX failed node=%u ret=%d", node, ret);
	}
	return ret;
}

int nmt_pre_operational(uint8_t node)
{
	can_frame_t frame;
	memset(&frame, 0, sizeof(frame));
	frame.id = 0x000;
	frame.dlc = 2;
	frame.data[0] = 0x80;
	frame.data[1] = node;
	LOG_INF("NMT pre-operational node=%u", node);
	return can_raw_send(&frame);
}

int nmt_reset_comm(uint8_t node)
{
	can_frame_t frame;
	memset(&frame, 0, sizeof(frame));
	frame.id = 0x000;
	frame.dlc = 2;
	frame.data[0] = 0x82;
	frame.data[1] = node;
	return can_raw_send(&frame);
}

int nmt_wait_operational(uint8_t node, int timeout_ms)
{
	uint32_t hb_id = 0x700 + node;
	LOG_INF("Waiting for node %u heartbeat (timeout=%d ms)...", node, timeout_ms);

	nmt_start(node);
	k_msleep(200);

	uint32_t device_type;
	int ret = sdo_read_u32(node, 0x1000, 0, &device_type);
	if (ret == 0) {
		LOG_INF("Node %u responds to SDO! Device type = 0x%08X",
			node, device_type);
		return 0;
	}
	if (ret == -ETIMEDOUT) {
		LOG_WRN("Node %u SDO timeout", node);
	}

	int64_t deadline = k_uptime_get() + timeout_ms;
	while (k_uptime_get() < deadline) {
		can_frame_t frame;
		ret = can_recv(&frame);
		if (ret == 1 && frame.id == hb_id) {
			uint8_t state = frame.data[0];
			LOG_INF("Heartbeat node=%u state=0x%02X", node, state);
			if (state == NMT_STATE_OPERATIONAL) {
				LOG_INF("Node %u is Operational", node);
				return 0;
			}
			if (state == NMT_STATE_PRE_OP || state == NMT_STATE_STOPPED) {
				nmt_start(node);
			}
		}
		k_msleep(HEARTBEAT_POLL_MS);
	}

	LOG_ERR("Node %u did not reach Operational within %d ms", node, timeout_ms);
	return -ETIMEDOUT;
}
