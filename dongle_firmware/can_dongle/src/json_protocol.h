/*
 * json_protocol.h - JSON 协议解析与构建
 *
 * 负责解析 RGB30 发来的 UDP JSON 命令，以及构建 dongle 发回的响应消息。
 * 协议格式与 mock_server/mock_dongle.py 和 godot_terminal/scripts/protocol.gd 兼容。
 */
#pragma once

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

/* 已知命令类型 */
typedef enum {
	CMD_UNKNOWN = 0,
	CMD_HEARTBEAT,
	CMD_ENABLE,
	CMD_DISABLE,
	CMD_ESTOP,
	CMD_JOG_START,
	CMD_JOG_STOP,
	CMD_SDO_READ,
	CMD_SDO_WRITE,
	CMD_OTA_START,
	CMD_OTA_CHUNK,
	CMD_OTA_VERIFY,
	CMD_OTA_FLASH,
	CMD_SET_SPEED,
	CMD_MOVE_POSITION,
} cmd_type_t;

/* 解析后的命令结构 */
typedef struct {
	cmd_type_t cmd;
	int seq;
	int node;
	/* jog 参数 */
	char direction[4];   /* "cw" / "ccw" */
	int speed;
	int position;
	/* SDO 参数 */
	int index;
	int sub;
	int data;
	/* OTA 参数 */
	int ota_size;
	char md5[33];
	int ota_offset;
} parsed_cmd_t;

/*
 * 解析 JSON 字符串为 parsed_cmd_t。
 * 返回 true 表示解析成功（至少提取到了 cmd 字段）。
 * 对于无法识别的 cmd 字符串，out->cmd == CMD_UNKNOWN 但仍然返回 true。
 * 返回 false 表示输入不是有效 JSON。
 */
bool cmd_json_parse(const char *json_str, int len, parsed_cmd_t *out);

/*
 * 构建 ack 响应 JSON。
 * 返回写入的字节数（不含结尾 '\0'）。
 *
 * 例: {"cmd":"ack","seq":1,"ts":1234567890,"payload":{"status":"ok","msg":"alive","node":1}}
 */
int json_build_ack(char *buf, int buf_size, int seq,
		   const char *status, const char *msg, int node);

/*
 * 构建 motor_status JSON。
 * 返回写入的字节数（不含结尾 '\0'）。
 *
 * 与 mock_dongle.py 的 motor_status 格式一致。
 */
int json_build_motor_status(char *buf, int buf_size,
			    float current, float voltage,
			    int speed, float position, float torque,
			    int status_word, int fault, int mode,
			    bool alive, int wdg_ms);

/*
 * 构建 can_log JSON — 将 CAN 原始帧转成 Godot CAN 日志界面可显示的文本。
 * 返回写入的字节数（不含结尾 '\0'）。
 *
 * 格式: {"cmd":"can_log","payload":{"id":"0x123","data":"A1 B2 C3 D4 E5 F6 07 08","dlc":8}}
 */
int json_build_can_log(char *buf, int buf_size, int can_id,
		       const uint8_t *data, int dlc);
