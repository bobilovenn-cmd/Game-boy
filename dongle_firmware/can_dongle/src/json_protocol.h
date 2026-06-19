/*
 * json_protocol.h - JSON 协议解析与构建
 */

#pragma once

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

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

typedef struct {
	cmd_type_t cmd;
	int seq;
	int node;
	char direction[4];
	int speed;
	int position;
	int index;
	int sub;
	int data;
	int ota_size;
	char md5[33];
	int ota_offset;
} parsed_cmd_t;

bool cmd_json_parse(const char *json_str, int len, parsed_cmd_t *out);

int json_build_ack(char *buf, int buf_size, int seq,
		   const char *status, const char *msg, int node);

int json_build_motor_status(char *buf, int buf_size,
			    float current, float voltage,
			    int speed, float position, float torque,
			    uint16_t drive_status_word, bool drive_fault,
			    bool estop_latched, const char *display_status,
			    uint32_t valid_mask, uint32_t fresh_mask, int mode,
			    bool alive, int wdg_ms);

int json_build_can_log(char *buf, int buf_size, int can_id,
		       const uint8_t *data, int dlc);
