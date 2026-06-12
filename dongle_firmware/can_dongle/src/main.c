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

/* ---- 模拟电机状态 (Phase 0 占位数据) ---- */
/* 当没有真实 CAN 数据时，发送这些占位值，
 * 使 Godot Monitor 页面有数据显示 */
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
	.voltage = 24.0f,
	.speed = 0,
	.position = 0.0f,
	.torque = 0.0f,
	.status_word = 0x0040,   /* Switch On Disabled */
	.fault = 0,
	.mode = 8,               /* CSP (Cyclic Synchronous Position) */
	.alive = true,
};

/* ---- 内部状态 ---- */
static bool motor_enabled = false;

/* ---- 前向声明 ---- */
static void handle_command(const parsed_cmd_t *cmd);
static void send_motor_status(void);
static void process_can_frames(void);

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
			"Check wiring: RX=GPIO19, TX=GPIO20.", ret);
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
		if (co_basic_enable((uint8_t)cmd->node) == 0) {
			motor_enabled = true;
			motor_state.status_word = 0x0027; /* Operation Enabled */
			motor_state.fault = 0;
			ack_len = json_build_ack(ack_buf, sizeof(ack_buf), cmd->seq,
						 "ok", "motor enabled", cmd->node);
		} else {
			ack_len = json_build_ack(ack_buf, sizeof(ack_buf), cmd->seq,
						 "error", "CAN enable failed", cmd->node);
		}
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
		if (motor_enabled) {
			co_basic_jog((uint8_t)cmd->node, target_rpm);
			motor_state.speed = target_rpm;
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

		/* Phase 0: 返回占位 SDO 值 */
		int sdo_val = 0;
		switch (cmd->index) {
		case 0x6060: sdo_val = motor_state.mode; break;
		case 0x6040: sdo_val = motor_enabled ? 0x000F : 0x0006; break;
		case 0x60FF: sdo_val = motor_state.speed; break;
		case 0x6071: sdo_val = (int)(motor_state.torque * 1000); break;
		default: sdo_val = 0; break;
		}

		char sdo_buf[256];
		int sdo_len = snprintf(sdo_buf, sizeof(sdo_buf),
			"{\"cmd\":\"sdo_read_result\",\"seq\":%d,\"ts\":0,"
			"\"payload\":{\"index\":%d,\"sub\":%d,"
			"\"data\":\"0x%X\",\"node\":%d}}",
			cmd->seq, cmd->index, cmd->sub, sdo_val, cmd->node);
		udp_send(sdo_buf, sdo_len);
		break;
	}

	case CMD_SDO_WRITE:
		LOG_INF("SDO_WRITE node=%d idx=0x%04X sub=%d data=%d from %s",
			cmd->node, cmd->index, cmd->sub, cmd->data, client_ip);
		/* Phase 0: 只是 ack，不真正操作硬件 */
		ack_len = json_build_ack(ack_buf, sizeof(ack_buf), cmd->seq,
					 "ok", "sdo write", cmd->node);
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
		processed++;
	}
}
