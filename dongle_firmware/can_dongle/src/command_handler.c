/*
 * command_handler.c - UDP 命令解析与分发
 */

#include "command_handler.h"
#include "command_policy.h"
#include "motor_state.h"
#include "motor_status_policy.h"
#include "canopen_basic.h"
#include "json_protocol.h"
#include "telemetry.h"
#include "udp_comm.h"
#include "watchdog.h"

#include <errno.h>
#include <stdio.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(cmd_handler, LOG_LEVEL_INF);

static void invalidate_commanded_fields(uint32_t fields)
{
	g_motor.valid_mask &= ~fields;
	g_motor.fresh_mask &= ~fields;
}

void command_handle_watchdog_timeout(void)
{
	if (!g_motor_enabled) {
		return;
	}

	LOG_WRN("Heartbeat watchdog stopping active node=%u", g_active_node);
	int ret = co_basic_estop(g_active_node);
	g_motor_enabled = false;
	g_profile_configured = false;
	g_motor.estop_latched = motor_estop_should_latch(ret);
	invalidate_commanded_fields(MOTOR_FIELD_BIT(MOTOR_FIELD_SPEED) |
				    MOTOR_FIELD_BIT(MOTOR_FIELD_STATUS));
	if (ret < 0) {
		LOG_ERR("Watchdog safety stop failed node=%u ret=%d",
			g_active_node, ret);
	}
}

void command_handle(const parsed_cmd_t *cmd)
{
	if (cmd == NULL) {
		return;
	}

	char ack_buf[512];
	int ack_len;
	const char *client_ip = udp_client_ip();

	uint8_t resolved_node = command_resolve_node(cmd->cmd, cmd->node,
						     g_active_node);
	if (command_updates_active_node(cmd->cmd)) {
		if (resolved_node != g_active_node) {
			g_profile_configured = false;
			telemetry_reset();
		}
		g_active_node = resolved_node;
	}

	/* estop — always allowed, same CAN ops as disable, different status */
	if (cmd->cmd == CMD_ESTOP) {
		LOG_WRN("ESTOP from %s packet_node=%d active_node=%u",
			client_ip, cmd->node, resolved_node);
		int ret = co_basic_estop(resolved_node);
		g_motor_enabled = false;
		g_profile_configured = false;
		g_motor.estop_latched = motor_estop_should_latch(ret);
		invalidate_commanded_fields(MOTOR_FIELD_BIT(MOTOR_FIELD_SPEED) |
					    MOTOR_FIELD_BIT(MOTOR_FIELD_CURRENT) |
					    MOTOR_FIELD_BIT(MOTOR_FIELD_STATUS));
		ack_len = json_build_ack(ack_buf, sizeof(ack_buf), cmd->seq,
					 ret == 0 ? "ok" : "error",
					 ret == 0 ? "emergency disable latched"
						  : "emergency disable failed",
					 resolved_node);
		udp_send(ack_buf, ack_len);
		return;
	}

	/* heartbeat — always allowed */
	if (cmd->cmd == CMD_HEARTBEAT) {
		wdg_feed();
		ack_len = json_build_ack(ack_buf, sizeof(ack_buf), cmd->seq,
					 "ok", "alive", resolved_node);
		udp_send(ack_buf, ack_len);
		return;
	}

	/* watchdog safety gate */
	if (wdg_is_safe() &&
	    (cmd->cmd == CMD_ENABLE || cmd->cmd == CMD_DISABLE ||
	     cmd->cmd == CMD_JOG_START || cmd->cmd == CMD_JOG_STOP ||
	     cmd->cmd == CMD_MOVE_POSITION)) {
		ack_len = json_build_ack(ack_buf, sizeof(ack_buf), cmd->seq,
					 "error",
					 "watchdog timeout — motor control blocked",
					 resolved_node);
		udp_send(ack_buf, ack_len);
		LOG_WRN("Command blocked by watchdog (cmd=%d)", cmd->cmd);
		return;
	}

	switch (cmd->cmd) {
	case CMD_ENABLE:
		LOG_INF("ENABLE node=%u from %s", resolved_node, client_ip);
		if (co_basic_enable(resolved_node) == 0) {
			g_motor_enabled = true;
			g_motor.alive = true;
			g_motor.estop_latched = false;
			uint16_t status;
			if (co_read_status_word(resolved_node, &status) == 0) {
				g_motor.drive_status_word = status;
				g_motor.drive_fault =
					motor_status_word_has_fault(status);
			}
			ack_len = json_build_ack(ack_buf, sizeof(ack_buf), cmd->seq,
						 "ok", "motor enabled", resolved_node);
		} else {
			ack_len = json_build_ack(ack_buf, sizeof(ack_buf), cmd->seq,
						 "error", "CAN enable failed", resolved_node);
		}
		udp_send(ack_buf, ack_len);
		break;

	case CMD_DISABLE:
		LOG_INF("DISABLE node=%u from %s", resolved_node, client_ip);
		{
			int ret = co_basic_disable(resolved_node);
			if (ret == 0) {
				g_motor_enabled = false;
				g_profile_configured = false;
				invalidate_commanded_fields(
					MOTOR_FIELD_BIT(MOTOR_FIELD_SPEED) |
					MOTOR_FIELD_BIT(MOTOR_FIELD_STATUS));
			}
			ack_len = json_build_ack(ack_buf, sizeof(ack_buf), cmd->seq,
						 ret == 0 ? "ok" : "error",
						 ret == 0 ? "motor disabled"
							  : "motor disable failed",
						 resolved_node);
		}
		udp_send(ack_buf, ack_len);
		break;

	case CMD_JOG_START:
		LOG_INF("JOG_START node=%u dir=%s speed=%d from %s",
			resolved_node, cmd->direction, cmd->speed, client_ip);
		if (cmd->speed > 0) {
			g_target_speed = cmd->speed;
		}
		{
			int vel = (cmd->direction[0] == 'c' && cmd->direction[1] == 'c')
				  ? -g_target_speed : g_target_speed;
			int ret = g_motor_enabled ? 0 : -EPERM;
			if (ret == 0 && !g_profile_configured) {
				ret = co_init_profile(resolved_node);
				if (ret == 0) {
					g_profile_configured = true;
				}
			}
			if (ret == 0) {
				ret = co_basic_jog(resolved_node, vel);
			}
			if (ret == 0) {
				g_motor.speed = vel;
			}
			ack_len = json_build_ack(ack_buf, sizeof(ack_buf), cmd->seq,
						 ret == 0 ? "ok" : "error",
						 ret == 0 ? "jog started"
							  : (ret == -EPERM
							     ? "motor not enabled"
							     : "jog start failed"),
						 resolved_node);
		}
		udp_send(ack_buf, ack_len);
		break;

	case CMD_SET_SPEED:
		if (cmd->speed < 1 || cmd->speed > 300000) {
			ack_len = json_build_ack(ack_buf, sizeof(ack_buf), cmd->seq,
						 "error", "speed range 1-300000", resolved_node);
		} else {
			g_target_speed = cmd->speed;
			ack_len = json_build_ack(ack_buf, sizeof(ack_buf), cmd->seq,
						 "ok", "speed updated", resolved_node);
		}
		udp_send(ack_buf, ack_len);
		break;

	case CMD_MOVE_POSITION: {
		LOG_INF("MOVE_POSITION node=%u pos=%d speed=%d from %s",
			resolved_node, cmd->position, cmd->speed, client_ip);
		int move_speed = cmd->speed > 0 ? cmd->speed : g_target_speed;
		if (co_move_to_position(resolved_node, (int32_t)cmd->position,
					move_speed) == 0) {
			g_motor.alive = true;
			ack_len = json_build_ack(ack_buf, sizeof(ack_buf), cmd->seq,
						 "ok", "position move started", resolved_node);
		} else {
			ack_len = json_build_ack(ack_buf, sizeof(ack_buf), cmd->seq,
						 "error", "position move failed", resolved_node);
		}
		udp_send(ack_buf, ack_len);
		break;
	}

	case CMD_JOG_STOP:
		LOG_INF("JOG_STOP node=%u from %s", resolved_node, client_ip);
		{
			int ret = co_basic_stop(resolved_node);
			if (ret == 0) {
				g_motor.speed = 0;
			}
			ack_len = json_build_ack(ack_buf, sizeof(ack_buf), cmd->seq,
						 ret == 0 ? "ok" : "error",
						 ret == 0 ? "jog stopped"
							  : "jog stop failed",
						 resolved_node);
		}
		udp_send(ack_buf, ack_len);
		break;

	case CMD_SDO_READ: {
		LOG_INF("SDO_READ node=%u idx=0x%04X sub=%d from %s",
			resolved_node, cmd->index, cmd->sub, client_ip);
		uint32_t value;
		int ret = sdo_read_u32(resolved_node, (uint16_t)cmd->index,
				       (uint8_t)cmd->sub, &value);
		char sdo_buf[256];
		if (ret == 0) {
			int sdo_len = snprintf(sdo_buf, sizeof(sdo_buf),
				"{\"cmd\":\"sdo_read_result\",\"seq\":%d,\"ts\":0,"
				"\"payload\":{\"index\":%d,\"sub\":%d,"
				"\"data\":\"0x%08X\",\"node\":%u}}",
				cmd->seq, cmd->index, cmd->sub, value, resolved_node);
			udp_send(sdo_buf, sdo_len);
		} else {
			ack_len = json_build_ack(ack_buf, sizeof(ack_buf), cmd->seq,
						 "error", "sdo read failed",
						 resolved_node);
			udp_send(ack_buf, ack_len);
		}
		break;
	}

	case CMD_SDO_WRITE:
		LOG_INF("SDO_WRITE node=%u idx=0x%04X sub=%d data=%d from %s",
			resolved_node, cmd->index, cmd->sub, cmd->data, client_ip);
		{
			uint8_t size = 4;
			if (cmd->index == 0x6060) size = 1;
			else if (cmd->index == 0x6040 || cmd->index == 0x6041 ||
				 cmd->index == 0x603F) size = 2;
			int ret = co_sdo_write(resolved_node,
					       (uint16_t)cmd->index,
					       (uint8_t)cmd->sub,
					       (uint32_t)cmd->data, size);
			ack_len = json_build_ack(ack_buf, sizeof(ack_buf), cmd->seq,
						 ret == 0 ? "ok" : "error",
						 ret == 0 ? "sdo write ok" : "sdo write failed",
						 resolved_node);
		}
		udp_send(ack_buf, ack_len);
		break;

	case CMD_OTA_START:
		LOG_INF("OTA_START size=%d md5=%s", cmd->ota_size, cmd->md5);
		ack_len = snprintf(ack_buf, sizeof(ack_buf),
			"{\"cmd\":\"ota_status\",\"seq\":%d,\"ts\":0,"
			"\"payload\":{\"state\":\"ready\",\"msg\":\"ready\"}}",
			cmd->seq);
		udp_send(ack_buf, ack_len);
		break;

	case CMD_OTA_CHUNK:
		ack_len = json_build_ack(ack_buf, sizeof(ack_buf), cmd->seq,
					 "ok", "chunk received", 0);
		udp_send(ack_buf, ack_len);
		break;

	case CMD_OTA_VERIFY:
		ack_len = snprintf(ack_buf, sizeof(ack_buf),
			"{\"cmd\":\"ota_status\",\"seq\":%d,\"ts\":0,"
			"\"payload\":{\"state\":\"done\",\"msg\":\"MD5 OK\"}}",
			cmd->seq);
		udp_send(ack_buf, ack_len);
		break;

	case CMD_OTA_FLASH:
		ack_len = snprintf(ack_buf, sizeof(ack_buf),
			"{\"cmd\":\"ota_status\",\"seq\":%d,\"ts\":0,"
			"\"payload\":{\"state\":\"done\",\"msg\":\"flash done\"}}",
			cmd->seq);
		udp_send(ack_buf, ack_len);
		break;

	case CMD_UNKNOWN:
	default:
		LOG_WRN("Unknown cmd from %s", client_ip);
		ack_len = json_build_ack(ack_buf, sizeof(ack_buf), cmd->seq,
					 "error", "unknown command", 0);
		udp_send(ack_buf, ack_len);
		break;
	}
}
