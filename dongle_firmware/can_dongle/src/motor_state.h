/*
 * motor_state.h - 共享电机状态 + 内部标志位
 *
 * 所有模块 #include 此文件即可访问电机数据，避免散落在 main.c 中。
 */

#pragma once

#include <stdint.h>
#include <stdbool.h>

#define DEFAULT_NODE 2

enum motor_field {
	MOTOR_FIELD_SPEED = 0,
	MOTOR_FIELD_POSITION,
	MOTOR_FIELD_CURRENT,
	MOTOR_FIELD_VOLTAGE,
	MOTOR_FIELD_TORQUE,
	MOTOR_FIELD_STATUS,
	MOTOR_FIELD_COUNT,
};

#define MOTOR_FIELD_BIT(field) (1U << (field))

/* ---- 电机实时数据（由 SDO 轮询刷新） ---- */
struct motor_state {
	float current;
	float voltage;
	int32_t speed;
	int32_t position;
	float torque;
	uint16_t drive_status_word;
	bool drive_fault;
	bool estop_latched;
	int8_t mode;
	bool alive;
	uint32_t valid_mask;
	uint32_t fresh_mask;
	int64_t updated_ms[MOTOR_FIELD_COUNT];
};

extern struct motor_state g_motor;
extern bool g_motor_enabled;
extern bool g_profile_configured;
extern int32_t g_target_speed;
extern uint8_t g_active_node;
