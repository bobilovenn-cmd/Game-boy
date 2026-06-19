/*
 * watchdog.c - 心跳看门狗实现
 */

#include "watchdog.h"

#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(watchdog, LOG_LEVEL_INF);

static int64_t last_heartbeat_ms;
static bool safe_state = true;
static bool fed_once;

void wdg_init(void)
{
	last_heartbeat_ms = k_uptime_get();
	safe_state = true;
	fed_once = false;
	LOG_INF("Watchdog initialized, timeout=%d ms", WDG_TIMEOUT_MS);
}

void wdg_feed(void)
{
	last_heartbeat_ms = k_uptime_get();
	if (!fed_once) {
		fed_once = true;
		LOG_INF("First heartbeat received — watchdog armed");
	}
	if (safe_state) {
		safe_state = false;
		LOG_INF("Watchdog: safe state cleared");
	}
}

bool wdg_check(void)
{
	if (!fed_once) return false;

	int64_t now = k_uptime_get();
	int64_t elapsed = now - last_heartbeat_ms;

	if (elapsed > WDG_TIMEOUT_MS && !safe_state) {
		safe_state = true;
		LOG_WRN("Watchdog timeout! %lld ms since last heartbeat. "
			"Entering SAFE state.", elapsed);
		return true;
	}
	return false;
}

bool wdg_is_safe(void)
{
	return safe_state;
}

int wdg_remaining_ms(void)
{
	if (!fed_once) return WDG_TIMEOUT_MS;
	int64_t now = k_uptime_get();
	int64_t elapsed = now - last_heartbeat_ms;
	int remaining = WDG_TIMEOUT_MS - (int)elapsed;
	return remaining > 0 ? remaining : 0;
}
