#include "telemetry.h"
#include "telemetry_policy.h"
#include "motor_state.h"
#include "motor_status_policy.h"
#include "canopen_basic.h"
#include "json_protocol.h"
#include "udp_comm.h"
#include "watchdog.h"

#include <string.h>
#include <zephyr/kernel.h>

#define MOTOR_STATUS_INTERVAL_MS 100

struct poll_state {
	uint8_t failures;
	int64_t next_attempt_ms;
};

static struct poll_state polls[MOTOR_FIELD_COUNT];
static enum motor_field poll_field;

void telemetry_reset(void)
{
	memset(polls, 0, sizeof(polls));
	poll_field = MOTOR_FIELD_SPEED;
	g_motor.alive = false;
	g_motor.valid_mask = 0;
	g_motor.fresh_mask = 0;
	memset(g_motor.updated_ms, 0, sizeof(g_motor.updated_ms));
}

static void record_result(enum motor_field field, int result, int64_t now)
{
	if (result == 0) {
		polls[field].failures = 0;
		polls[field].next_attempt_ms = now + MOTOR_STATUS_INTERVAL_MS;
		g_motor.valid_mask |= MOTOR_FIELD_BIT(field);
		g_motor.updated_ms[field] = now;
		return;
	}
	if (polls[field].failures < UINT8_MAX) polls[field].failures++;
	polls[field].next_attempt_ms =
		now + telemetry_retry_delay_ms(polls[field].failures);
}

static void poll_one_field(int64_t now)
{
	enum motor_field field = poll_field;
	bool found = false;
	for (int offset = 0; offset < MOTOR_FIELD_COUNT; offset++) {
		field = (enum motor_field)((poll_field + offset) % MOTOR_FIELD_COUNT);
		if (now >= polls[field].next_attempt_ms) {
			poll_field =
				(enum motor_field)((field + 1) % MOTOR_FIELD_COUNT);
			found = true;
			break;
		}
	}
	if (!found) return;

	int result;
	switch (field) {
	case MOTOR_FIELD_SPEED:
		result = co_read_actual_velocity(g_active_node, &g_motor.speed);
		break;
	case MOTOR_FIELD_POSITION:
		result = co_read_actual_position(g_active_node, &g_motor.position);
		break;
	case MOTOR_FIELD_CURRENT: {
		int32_t raw;
		result = co_read_actual_current(g_active_node, &raw);
		if (result == 0) g_motor.current = (float)raw / 1000.0f;
		break;
	}
	case MOTOR_FIELD_VOLTAGE: {
		uint32_t raw;
		result = co_read_dc_link_voltage(g_active_node, &raw);
		if (result == 0) g_motor.voltage = (float)raw / 1000.0f;
		break;
	}
	case MOTOR_FIELD_TORQUE: {
		int16_t raw;
		result = co_read_actual_torque(g_active_node, &raw);
		if (result == 0) g_motor.torque = (float)raw / 1000.0f;
		break;
	}
	case MOTOR_FIELD_STATUS: {
		uint16_t status;
		result = co_read_status_word(g_active_node, &status);
		if (result == 0) {
			g_motor.drive_status_word = status;
			g_motor.drive_fault = motor_status_word_has_fault(status);
		}
		break;
	}
	default:
		return;
	}
	record_result(field, result, now);
}

void telemetry_send(void)
{
	static int64_t last_send_ms;
	int64_t now = k_uptime_get();
	if (now - last_send_ms < MOTOR_STATUS_INTERVAL_MS) return;
	last_send_ms = now;

	poll_one_field(now);

	g_motor.fresh_mask = 0;
	for (int field = 0; field < MOTOR_FIELD_COUNT; field++) {
		if ((g_motor.valid_mask & MOTOR_FIELD_BIT(field)) &&
		    telemetry_value_is_fresh(now, g_motor.updated_ms[field],
					     TELEMETRY_STALE_MS)) {
			g_motor.fresh_mask |= MOTOR_FIELD_BIT(field);
		}
	}
	g_motor.alive = g_motor.fresh_mask != 0;
	bool status_fresh =
		(g_motor.fresh_mask & MOTOR_FIELD_BIT(MOTOR_FIELD_STATUS)) != 0;
	enum motor_display_status display_status =
		motor_display_status_resolve(g_motor.alive, status_fresh,
					     g_motor.drive_fault,
					     g_motor.estop_latched);

	char buffer[640];
	int length = json_build_motor_status(buffer, sizeof(buffer),
		g_motor.current, g_motor.voltage, g_motor.speed,
		(float)g_motor.position, g_motor.torque,
		g_motor.drive_status_word, g_motor.drive_fault,
		g_motor.estop_latched,
		motor_display_status_name(display_status),
		g_motor.valid_mask, g_motor.fresh_mask,
		g_motor.mode, g_motor.alive,
		wdg_remaining_ms());
	udp_send(buffer, length);
}
