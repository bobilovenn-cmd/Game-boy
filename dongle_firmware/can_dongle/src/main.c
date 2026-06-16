/*
 * main.c - ESP32 CAN Dongle 主程序 (Phase 0: UDP + CAN 原始网关)
 *
 * 启动流程:
 *   1. 初始化 Wi-Fi AP 热点 "CAN_Dongle_01", IP 192.168.4.1
 *   2. 监听 UDP 端口 5000
 *   3. 初始化 CAN 控制器 (1000 kbps)
 *   4. 主循环:
 *      - 接收 UDP JSON 命令 → 解析 → 回复 ack
 *      - 接收 CAN 帧 → 格式化 → 发送 can_log 给 RGB30
 *      - 周期性 (100ms) 发送 motor_status
 *      - 心跳看门狗 (500ms 超时 → 安全停止)
 *
 * 支持的 UDP 命令 (与 mock_dongle.py 兼容):
 *   heartbeat  - 心跳保持
 *   enable     - 电机使能
 *   disable    - 电机失能
 *   estop      - 急停
 *   jog_start  - 点动开始
 *   jog_stop   - 点动停止
 *   sdo_read   - 读取对象字典
 *   sdo_write  - 写入对象字典
 *   ota_start  - OTA 开始
 *   ota_chunk  - OTA 数据块
 *   ota_verify - OTA 校验
 *   ota_flash  - OTA 刷写
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>

#include "udp_comm.h"
#include "can_raw.h"
#include "canopen_basic.h"
#include "json_protocol.h"
#include "watchdog.h"

LOG_MODULE_REGISTER(main, LOG_LEVEL_INF);

/* ---- 配置 ---- */
#define MOTOR_STATUS_INTERVAL_MS	100
#define MAIN_LOOP_DELAY_MS		10
#define MAX_CAN_FRAMES_PER_LOOP		4
#define CAN_LOG_INTERVAL_MS		20
#define UI_SPEED_TO_MOTOR_UNITS		100
#define MOTOR_COMMAND_WDG_FEEDS		6

/* ---- 电机状态（从 CAN 总线实时读取） ---- */
static struct {
	float current;
	float voltage;
	int speed;
	float position;
	float torque;
	int status_word;
	int fault;
	int mode;
	bool alive;
	} motor_state = {
		.current = 0.0f,
		.voltage = 0.0f,
		.speed = 0,
		.position = 0.0f,
		.torque = 0.0f,
	.status_word = 0x0040,   /* Switch On Disabled */
	.fault = 0,
	.mode = 3,               /* Profile Velocity */
	.alive = false,
};

/* ---- 内部状态 ---- */
static bool motor_enabled = false;
static bool profile_configured = false;
#define DEFAULT_NODE 2
static uint8_t active_node = DEFAULT_NODE;

/* ---- 前向声明 ---- */
static void handle_command(const parsed_cmd_t *cmd);
static void send_motor_status(void);
static void process_can_frames(void);
static bool is_sdo_error(int value);
static void keep_link_alive_during_command(void);

/* ---- 入口 ---- */
int main(void)
{
	int ret;

	LOG_INF("========================================");
	LOG_INF("ESP32 CAN Dongle Firmware");
	LOG_INF("Phase 0: UDP + CAN Raw Gateway");
	LOG_INF("========================================");

	/* 1. 初始化看门狗 */
	wdg_init();

	/* 2. 初始化 Wi-Fi AP + UDP */
	ret = udp_init();
	if (ret < 0) {
		LOG_ERR("UDP init failed: %d — retrying...", ret);
		k_sleep(K_SECONDS(2));
		ret = udp_init();
		if (ret < 0) {
			LOG_ERR("UDP init failed again: %d. "
				"Dongle will run without network.", ret);
		}
	}

	/* 3. 初始化 CAN (非致命错误 — CAN 未连接时继续运行) */
	ret = can_init();
	if (ret < 0) {
		LOG_WRN("CAN init failed: %d. "
			"Dongle will run without CAN. "
			"Check wiring: RX=GPIO16, TX=GPIO15.", ret);
	} else {
		/* Keep startup non-invasive. The RGB30 selects the node later; do not
		 * probe/reset the CAN bus here, because an unpowered motor would push
		 * the ESP32 TWAI controller into Error-Passive before the UI is ready.
		 */
		can_diag();
	}

	LOG_INF("Dongle ready. Waiting for RGB30 heartbeat...");
	LOG_INF("SSID: CAN_Dongle_01  IP: 192.168.4.1  UDP: 5000");

	/* ---- 主循环 ---- */
	int64_t last_status_time = k_uptime_get();
	char recv_buf[2048];

	while (1) {
		/* A. 接收 UDP 消息 */
		int recv_len = udp_recv(recv_buf, sizeof(recv_buf), 10);
		if (recv_len > 0) {
			parsed_cmd_t cmd;
			if (cmd_json_parse(recv_buf, recv_len, &cmd)) {
				handle_command(&cmd);
			} else {
				LOG_WRN("Failed to parse JSON: %.100s", recv_buf);
			}
		}

		/* B. 处理 CAN 帧 */
		process_can_frames();

		/* C. 周期性发送 motor_status */
		int64_t now = k_uptime_get();
		if ((now - last_status_time) >= MOTOR_STATUS_INTERVAL_MS) {
			send_motor_status();
			last_status_time = now;
		}

		/* D. 检查看门狗 */
		wdg_check();

		/* E. 微小延迟，避免 CPU 100% */
		k_msleep(MAIN_LOOP_DELAY_MS);
	}

	return 0;
}

/* ---- 命令处理 ---- */

static void handle_command(const parsed_cmd_t *cmd)
{
	char ack_buf[512];
	int ack_len;
	const char *client_ip = udp_client_ip();

	if (cmd->cmd != CMD_HEARTBEAT && cmd->node >= 1 && cmd->node <= 127) {
		active_node = (uint8_t)cmd->node;
	}

	/* estop 不受安全状态限制 — 始终可以执行 */
	if (cmd->cmd == CMD_ESTOP) {
		LOG_WRN("ESTOP received from %s", client_ip);
		co_basic_estop((uint8_t)cmd->node);
		motor_enabled = false;
		motor_state.status_word = 0x0008; /* Fault */
		motor_state.fault = 1;
		motor_state.speed = 0;
		motor_state.current = 0;
		ack_len = json_build_ack(ack_buf, sizeof(ack_buf), cmd->seq,
					 "ok", "estop activated", cmd->node);
		udp_send(ack_buf, ack_len);
		LOG_INF("→ ack: estop ok");
		return;
	}

	/* heartbeat 不受安全状态限制 */
	if (cmd->cmd == CMD_HEARTBEAT) {
		wdg_feed();
		ack_len = json_build_ack(ack_buf, sizeof(ack_buf), cmd->seq,
					 "ok", "alive", cmd->node);
		udp_send(ack_buf, ack_len);
		return;
	}

	/* 安全状态检查: 以下命令在安全状态下被拦截 */
	if (wdg_is_safe() &&
	    (cmd->cmd == CMD_ENABLE || cmd->cmd == CMD_DISABLE ||
	     cmd->cmd == CMD_JOG_START || cmd->cmd == CMD_JOG_STOP)) {
		ack_len = json_build_ack(ack_buf, sizeof(ack_buf), cmd->seq,
					 "error",
					 "watchdog timeout — motor control blocked",
					 cmd->node);
		udp_send(ack_buf, ack_len);
		LOG_WRN("Command blocked by watchdog (cmd=%d)", cmd->cmd);
		return;
	}

	/* ---- 按命令类型处理 ---- */
	switch (cmd->cmd) {
	case CMD_ENABLE:
		LOG_INF("ENABLE node=%d from %s", cmd->node, client_ip);
		keep_link_alive_during_command();
			if (co_basic_enable((uint8_t)cmd->node) == 0) {
				motor_enabled = true;
				motor_state.alive = true;
				motor_state.fault = 0;
			/* 从 CAN 读取真实状态字 */
			int sw = co_read_status_word((uint8_t)cmd->node);
			if (sw >= 0) {
				motor_state.status_word = sw;
				LOG_INF("Motor status word = 0x%04X", sw);
			} else {
				motor_state.status_word = 0x0027;
			}
			ack_len = json_build_ack(ack_buf, sizeof(ack_buf), cmd->seq,
						 "ok", "motor enabled", cmd->node);
		} else {
			ack_len = json_build_ack(ack_buf, sizeof(ack_buf), cmd->seq,
						 "error", "CAN enable failed", cmd->node);
		}
		keep_link_alive_during_command();
		udp_send(ack_buf, ack_len);
		break;

	case CMD_DISABLE:
		LOG_INF("DISABLE node=%d from %s", cmd->node, client_ip);
		co_basic_disable((uint8_t)cmd->node);
		motor_enabled = false;
		motor_state.status_word = 0x0021; /* Ready */
		motor_state.speed = 0;
		ack_len = json_build_ack(ack_buf, sizeof(ack_buf), cmd->seq,
					 "ok", "motor disabled", cmd->node);
		udp_send(ack_buf, ack_len);
		break;

		case CMD_JOG_START:
			LOG_INF("JOG_START node=%d dir=%s speed=%d from %s",
				cmd->node, cmd->direction, cmd->speed, client_ip);
			int target_rpm = (cmd->direction[0] == 'c' &&
					  cmd->direction[1] == 'c') ?
					 -cmd->speed : cmd->speed;
			int target_motor_speed = target_rpm * UI_SPEED_TO_MOTOR_UNITS;
			if (motor_enabled) {
				if (!profile_configured) {
					/* 首次 jog 前补配置运动参数 */
					if (co_init_profile((uint8_t)cmd->node) == 0) {
						profile_configured = true;
				}
				}
				co_basic_jog((uint8_t)cmd->node, target_rpm);
				motor_state.speed = target_motor_speed;
			}
			ack_len = json_build_ack(ack_buf, sizeof(ack_buf), cmd->seq,
						 "ok", "jog started", cmd->node);
			udp_send(ack_buf, ack_len);
			break;

	case CMD_JOG_STOP:
		LOG_INF("JOG_STOP node=%d from %s", cmd->node, client_ip);
		co_basic_stop((uint8_t)cmd->node);
		motor_state.speed = 0;
		ack_len = json_build_ack(ack_buf, sizeof(ack_buf), cmd->seq,
					 "ok", "jog stopped", cmd->node);
		udp_send(ack_buf, ack_len);
		break;

	case CMD_SDO_READ: {
		LOG_INF("SDO_READ node=%d idx=0x%04X sub=%d from %s",
			cmd->node, cmd->index, cmd->sub, client_ip);

		/* 从 CAN 总线真实读取 SDO */
		int sdo_val = co_sdo_read((uint8_t)cmd->node,
						 cmd->index, cmd->sub);

		char sdo_buf[256];
		int sdo_len = snprintf(sdo_buf, sizeof(sdo_buf),
			"{\"cmd\":\"sdo_read_result\",\"seq\":%d,\"ts\":0,"
			"\"payload\":{\"index\":%d,\"sub\":%d,"
			"\"data\":\"0x%X\",\"node\":%d}}",
			cmd->seq, cmd->index, cmd->sub,
			(sdo_val >= 0) ? sdo_val : 0xDEAD, cmd->node);
		udp_send(sdo_buf, sdo_len);
		break;
	}

		case CMD_SDO_WRITE:
			LOG_INF("SDO_WRITE node=%d idx=0x%04X sub=%d data=%d from %s",
				cmd->node, cmd->index, cmd->sub, cmd->data, client_ip);
			/* 真实写入 CAN 总线 */
			{
				uint8_t size = 4;
				if (cmd->index == 0x6060) {
					size = 1;
				} else if (cmd->index == 0x6040 || cmd->index == 0x6041 ||
					   cmd->index == 0x603F) {
					size = 2;
				}
				int ret = co_sdo_write((uint8_t)cmd->node,
						       (uint16_t)cmd->index,
						       (uint8_t)cmd->sub,
						       (uint32_t)cmd->data, size);
				if (ret == 0) {
					ack_len = json_build_ack(ack_buf, sizeof(ack_buf),
								 cmd->seq, "ok",
								 "sdo write ok", cmd->node);
				} else {
					ack_len = json_build_ack(ack_buf, sizeof(ack_buf),
								 cmd->seq, "error",
								 "sdo write failed", cmd->node);
				}
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
		/* Phase 0: 只 ack，不保存 */
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
		LOG_WRN("Unknown cmd from %s: %.*s",
			client_ip, 64, "");
		/* 安全规则：未知命令必须返回错误 */
		ack_len = json_build_ack(ack_buf, sizeof(ack_buf), cmd->seq,
					 "error", "unknown command", 0);
		udp_send(ack_buf, ack_len);
		break;
	}
}

/* ---- 周期性上报 ---- */

static void send_motor_status(void)
{
	char buf[512];

	/* 从 CAN 读取真实电机数据 */
	if (motor_state.alive) {
		/* Poll one SDO object per status frame. This keeps the UI moving while
		 * avoiding long bursts of SDO traffic on every 100 ms status packet.
		 */
		static int poll_slot = 0;
		int val;
		switch (poll_slot) {
		case 0:
			val = co_read_actual_velocity(active_node);
			if (!is_sdo_error(val) && val >= -1000000 && val <= 1000000) {
				motor_state.speed = val;
			}
			break;
		case 1:
			val = co_read_actual_position(active_node);
			if (!is_sdo_error(val) && val > -1000000000 && val < 1000000000) {
				motor_state.position = (float)val;
			}
			break;
		case 2:
			val = co_read_actual_current(active_node);
			if (val >= 0) {
				motor_state.current = (float)val / 1000.0f;
			}
			break;
		case 3:
			val = co_read_dc_link_voltage(active_node);
			if (val >= 0) {
				motor_state.voltage = (float)val / 1000.0f;
			}
			break;
		case 4:
			val = co_read_actual_torque(active_node);
			if (!is_sdo_error(val) && val >= -1000000 && val <= 1000000) {
				motor_state.torque = (float)val / 1000.0f;
			}
			break;
		case 5:
			val = co_read_status_word(active_node);
			if (val >= 0) {
				motor_state.status_word = val;
			}
			break;
		}
		poll_slot = (poll_slot + 1) % 6;
	}

	/* 更新看门狗剩余时间 */
	int wdg_remaining = wdg_remaining_ms();

	int len = json_build_motor_status(buf, sizeof(buf),
		motor_state.current,
		motor_state.voltage,
		motor_state.speed,
		motor_state.position,
		motor_state.torque,
		motor_state.status_word,
		motor_state.fault,
		motor_state.mode,
		motor_state.alive,
		wdg_remaining);

	udp_send(buf, len);
}

static bool is_sdo_error(int value)
{
	return value == -EIO || value == -ETIMEDOUT || value == -EINVAL;
}

static void keep_link_alive_during_command(void)
{
	for (int i = 0; i < MOTOR_COMMAND_WDG_FEEDS; i++) {
		wdg_feed();
		k_msleep(20);
	}
}

/* ---- CAN 帧处理 ---- */

static void process_can_frames(void)
{
	can_frame_t frame;
	char log_buf[256];
	int processed = 0;
	static int64_t last_can_log_time = 0;

	while (processed < MAX_CAN_FRAMES_PER_LOOP && can_recv(&frame) == 1) {
		int64_t now = k_uptime_get();
		if ((now - last_can_log_time) >= CAN_LOG_INTERVAL_MS) {
			int len = json_build_can_log(log_buf, sizeof(log_buf),
						     frame.id, frame.data, frame.dlc);
			udp_send(log_buf, len);
			last_can_log_time = now;
		}

		/* 控制台日志 */
		char frame_str[128];
		can_frame_to_string(&frame, frame_str, sizeof(frame_str));
		LOG_DBG("CAN: %s", frame_str);
		if (frame.id == (0x700 + active_node) && frame.dlc >= 1) {
			motor_state.alive = true;
		}
		processed++;
	}
}
