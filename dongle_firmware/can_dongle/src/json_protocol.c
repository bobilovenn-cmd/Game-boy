/*
 * json_protocol.c - JSON 协议解析与构建实现
 *
 * 使用轻量级字符串扫描来解析/构建 JSON。
 * 不需要外部 JSON 库，适合 Phase 0 快速验证。
 * Phase 1 可以替换为 cJSON 或 Zephyr JSON 库。
 */

#include "json_protocol.h"

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>
#include <zephyr/sys/util.h>

/* ---- 内部辅助: 字符串扫描 ---- */

static const char *skip_ws(const char *p)
{
	while (*p && isspace((unsigned char)*p)) {
		p++;
	}
	return p;
}

static const char *json_find_value(const char *s, const char *key)
{
	char search[64];
	int n = snprintf(search, sizeof(search), "\"%s\"", key);
	const char *p = strstr(s, search);
	if (!p) {
		return NULL;
	}

	p += n;
	p = skip_ws(p);
	if (*p != ':') {
		return NULL;
	}
	p++;
	return skip_ws(p);
}

/* 在 s 中查找 key 对应的字符串值，写入 val (最大 val_size 字节)。
 * 例: "cmd":"heartbeat" → val="heartbeat" */
static bool json_get_string(const char *s, const char *key, char *val, int val_size)
{
	const char *p = json_find_value(s, key);
	if (!p || *p != '"') return false;
	p++;
	int i;
	for (i = 0; i < val_size - 1 && *p && *p != '"'; i++, p++) {
		val[i] = *p;
	}
	val[i] = '\0';
	return true;
}

/* 在 s 中查找 key 对应的整数值。
 * 支持: "key":123 或 "key":"123" */
static bool json_get_int(const char *s, const char *key, int *val)
{
	const char *p = json_find_value(s, key);
	if (!p) return false;

	/* 跳过引号（处理 "key":"123" 的情况） */
	if (*p == '"') p++;

	*val = atoi(p);
	return true;
}

/* 在 s 中查找 key 对应的浮点数值 */
static bool json_get_float(const char *s, const char *key, float *val)
{
	const char *p = json_find_value(s, key);
	if (!p) return false;
	if (*p == '"') p++;
	*val = (float)atof(p);
	return true;
}

/* 在 s 中查找 key 对应的布尔值 */
static bool json_get_bool(const char *s, const char *key, bool *val)
{
	const char *p = json_find_value(s, key);
	if (!p) return false;
	if (strncmp(p, "true", 4) == 0) {
		*val = true;
		return true;
	}
	if (strncmp(p, "false", 5) == 0) {
		*val = false;
		return true;
	}
	return false;
}

static int scale_float(float value, int scale)
{
	float scaled = value * (float)scale;
	return (int)(scaled + (scaled >= 0.0f ? 0.5f : -0.5f));
}

static void format_fixed(char *buf, size_t buf_size, float value, int decimals)
{
	int scale = (decimals == 1) ? 10 : 100;
	int scaled = scale_float(value, scale);
	int abs_scaled = scaled < 0 ? -scaled : scaled;
	const char *sign = scaled < 0 ? "-" : "";
	int whole = abs_scaled / scale;
	int frac = abs_scaled % scale;

	if (decimals == 1) {
		snprintf(buf, buf_size, "%s%d.%01d", sign, whole, frac);
	} else {
		snprintf(buf, buf_size, "%s%d.%02d", sign, whole, frac);
	}
}

/* 内部: 获取 "payload":{"subkey":...} 中的整数值 */
static bool json_get_payload_int(const char *s, const char *subkey, int *val)
{
	/* 先定位 "payload" */
	const char *p = json_find_value(s, "payload");
	if (!p) return false;
	/* 在 payload 段内查找 subkey */
	const char *q = json_find_value(p, subkey);
	if (!q) return false;
	if (*q == '"') q++;
	*val = atoi(q);
	return true;
}

/* 内部: 获取 "payload":{"subkey":...} 中的字符串值 */
static bool json_get_payload_string(const char *s, const char *subkey,
				    char *val, int val_size)
{
	const char *p = json_find_value(s, "payload");
	if (!p) return false;
	const char *q = json_find_value(p, subkey);
	if (!q || *q != '"') return false;
	q++;
	int i;
	for (i = 0; i < val_size - 1 && *q && *q != '"'; i++, q++) {
		val[i] = *q;
	}
	val[i] = '\0';
	return true;
}

/* ---- 公共接口 ---- */

/* 字符串到命令类型的映射 */
static cmd_type_t str_to_cmd(const char *s)
{
	if (strcmp(s, "heartbeat") == 0)  return CMD_HEARTBEAT;
	if (strcmp(s, "enable") == 0)     return CMD_ENABLE;
	if (strcmp(s, "disable") == 0)    return CMD_DISABLE;
	if (strcmp(s, "estop") == 0)      return CMD_ESTOP;
	if (strcmp(s, "jog_start") == 0)  return CMD_JOG_START;
	if (strcmp(s, "jog_stop") == 0)   return CMD_JOG_STOP;
	if (strcmp(s, "sdo_read") == 0)   return CMD_SDO_READ;
	if (strcmp(s, "sdo_write") == 0)  return CMD_SDO_WRITE;
	if (strcmp(s, "ota_start") == 0)  return CMD_OTA_START;
	if (strcmp(s, "ota_chunk") == 0)  return CMD_OTA_CHUNK;
	if (strcmp(s, "ota_verify") == 0) return CMD_OTA_VERIFY;
	if (strcmp(s, "ota_flash") == 0)  return CMD_OTA_FLASH;
	if (strcmp(s, "set_speed") == 0)  return CMD_SET_SPEED;
	if (strcmp(s, "move_position") == 0) return CMD_MOVE_POSITION;
	return CMD_UNKNOWN;
}

bool cmd_json_parse(const char *json_str, int len, parsed_cmd_t *out)
{
	if (!json_str || !out) return false;

	memset(out, 0, sizeof(*out));
	out->node = 1;       /* 默认节点 1 */
	out->direction[0] = 'c';
	out->direction[1] = 'w';
	out->direction[2] = '\0';
	out->speed = 500;    /* 默认 500 rpm */

	/* 检查基本 JSON 结构 */
	const char *brace = strchr(json_str, '{');
	if (!brace) return false;

	/* 提取 cmd */
	char cmd_str[32];
	if (!json_get_string(brace, "cmd", cmd_str, sizeof(cmd_str))) {
		return false;
	}
	out->cmd = str_to_cmd(cmd_str);

	/* 提取 seq */
	json_get_int(brace, "seq", &out->seq);

	/* 提取 payload 内部字段（按命令类型） */
	switch (out->cmd) {
	case CMD_HEARTBEAT:
		json_get_payload_int(brace, "node", &out->node);
		break;
	case CMD_ENABLE:
	case CMD_DISABLE:
	case CMD_JOG_STOP:
	case CMD_OTA_FLASH:
		json_get_payload_int(brace, "node", &out->node);
		break;
	case CMD_SET_SPEED:
		json_get_payload_int(brace, "node", &out->node);
		json_get_payload_int(brace, "speed", &out->speed);
		break;
	case CMD_MOVE_POSITION:
		json_get_payload_int(brace, "node", &out->node);
		json_get_payload_int(brace, "position", &out->position);
		json_get_payload_int(brace, "speed", &out->speed);
		break;
	case CMD_JOG_START:
		json_get_payload_int(brace, "node", &out->node);
		json_get_payload_string(brace, "direction", out->direction,
					sizeof(out->direction));
		json_get_payload_int(brace, "speed", &out->speed);
		break;
	case CMD_SDO_READ:
		json_get_payload_int(brace, "node", &out->node);
		json_get_payload_int(brace, "index", &out->index);
		json_get_payload_int(brace, "sub", &out->sub);
		break;
	case CMD_SDO_WRITE:
		json_get_payload_int(brace, "node", &out->node);
		json_get_payload_int(brace, "index", &out->index);
		json_get_payload_int(brace, "sub", &out->sub);
		json_get_payload_int(brace, "data", &out->data);
		break;
	case CMD_OTA_START:
		json_get_payload_int(brace, "size", &out->ota_size);
		json_get_payload_string(brace, "md5", out->md5, sizeof(out->md5));
		break;
	case CMD_OTA_CHUNK:
		json_get_payload_int(brace, "offset", &out->ota_offset);
		break;
	default:
		break;
	}

	return true;
}

int json_build_ack(char *buf, int buf_size, int seq,
		   const char *status, const char *msg, int node)
{
	return snprintf(buf, buf_size,
		"{\"cmd\":\"ack\",\"seq\":%d,\"ts\":0,"
		"\"payload\":{\"status\":\"%s\",\"msg\":\"%s\",\"node\":%d}}",
		seq, status, msg, node);
}

int json_build_motor_status(char *buf, int buf_size,
			    float current, float voltage,
			    int speed, float position, float torque,
			    int status_word, int fault, int mode,
			    bool alive, int wdg_ms)
{
	char current_s[16];
	char voltage_s[16];
	char position_s[16];
	char torque_s[16];

	format_fixed(current_s, sizeof(current_s), current, 2);
	format_fixed(voltage_s, sizeof(voltage_s), voltage, 1);
	format_fixed(position_s, sizeof(position_s), position, 1);
	format_fixed(torque_s, sizeof(torque_s), torque, 2);

	return snprintf(buf, buf_size,
		"{\"cmd\":\"motor_status\",\"seq\":0,\"ts\":0,"
		"\"payload\":{"
		"\"current\":%s,\"voltage\":%s,"
		"\"speed\":%d,\"position\":%s,\"torque\":%s,"
		"\"status_word\":%d,\"fault\":%d,\"mode\":%d,"
		"\"alive\":%s,\"wdg_ms\":%d"
		"}}",
		current_s, voltage_s, speed, position_s, torque_s,
		status_word, fault, mode,
		alive ? "true" : "false", wdg_ms);
}

int json_build_can_log(char *buf, int buf_size, int can_id,
		       const uint8_t *data, int dlc)
{
	char data_str[64];
	int pos = 0;
	for (int i = 0; i < dlc && i < 8; i++) {
		pos += snprintf(data_str + pos, sizeof(data_str) - pos,
				"%s%02X", (i > 0 ? " " : ""), data[i]);
	}

	return snprintf(buf, buf_size,
		"{\"cmd\":\"can_log\",\"payload\":{"
		"\"id\":\"0x%X\",\"data\":\"%s\",\"dlc\":%d"
		"}}",
		can_id, data_str, dlc);
}
