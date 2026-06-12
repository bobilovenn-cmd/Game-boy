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
#include <zephyr/sys/util.h>

/* ---- 内部辅助: 字符串扫描 ---- */

/* 在 s 中查找 key 对应的字符串值，写入 val (最大 val_size 字节)。
 * 例: "cmd":"heartbeat" → val="heartbeat" */
static bool json_get_string(const char *s, const char *key, char *val, int val_size)
{
	char search[64];
	int n = snprintf(search, sizeof(search), "\"%s\":\"", key);
	const char *p = strstr(s, search);
	if (!p) return false;
	p += n;
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
	char search[64];
	int n = snprintf(search, sizeof(search), "\"%s\":", key);
	const char *p = strstr(s, search);
	if (!p) return false;
	p += n;

	/* 跳过引号（处理 "key":"123" 的情况） */
	if (*p == '"') p++;

	*val = atoi(p);
	return true;
}

/* 在 s 中查找 key 对应的浮点数值 */
static bool json_get_float(const char *s, const char *key, float *val)
{
	char search[64];
	int n = snprintf(search, sizeof(search), "\"%s\":", key);
	const char *p = strstr(s, search);
	if (!p) return false;
	p += n;
	if (*p == '"') p++;
	*val = (float)atof(p);
	return true;
}

/* 在 s 中查找 key 对应的布尔值 */
static bool json_get_bool(const char *s, const char *key, bool *val)
{
	char search[64];
	int n = snprintf(search, sizeof(search), "\"%s\":", key);
	const char *p = strstr(s, search);
	if (!p) return false;
	p += n;
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

/* 内部: 获取 "payload":{"subkey":...} 中的整数值 */
static bool json_get_payload_int(const char *s, const char *subkey, int *val)
{
	char search[64];
	int n = snprintf(search, sizeof(search), "\"%s\":", subkey);
	/* 先定位 "payload" */
	const char *p = strstr(s, "\"payload\":");
	if (!p) return false;
	/* 在 payload 段内查找 subkey */
	const char *q = strstr(p, search);
	if (!q) return false;
	q += n;
	if (*q == '"') q++;
	*val = atoi(q);
	return true;
}

/* 内部: 获取 "payload":{"subkey":...} 中的字符串值 */
static bool json_get_payload_string(const char *s, const char *subkey,
				    char *val, int val_size)
{
	char search[64];
	int n = snprintf(search, sizeof(search), "\"%s\":\"", subkey);
	const char *p = strstr(s, "\"payload\":");
	if (!p) return false;
	const char *q = strstr(p, search);
	if (!q) return false;
	q += n;
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
	return CMD_UNKNOWN;
}

bool json_parse(const char *json_str, int len, parsed_cmd_t *out)
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
	case CMD_ENABLE:
	case CMD_DISABLE:
	case CMD_JOG_STOP:
	case CMD_OTA_FLASH:
		json_get_payload_int(brace, "node", &out->node);
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
	return snprintf(buf, buf_size,
		"{\"cmd\":\"motor_status\",\"seq\":0,\"ts\":0,"
		"\"payload\":{"
		"\"current\":%.2f,\"voltage\":%.1f,"
		"\"speed\":%d,\"position\":%.1f,\"torque\":%.2f,"
		"\"status_word\":%d,\"fault\":%d,\"mode\":%d,"
		"\"alive\":%s,\"wdg_ms\":%d"
		"}}",
		current, voltage, speed, position, torque,
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
