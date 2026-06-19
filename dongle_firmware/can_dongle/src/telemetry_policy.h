#pragma once

#include <stdbool.h>
#include <stdint.h>

#define TELEMETRY_BASE_RETRY_MS 1000
#define TELEMETRY_MAX_RETRY_MS  5000
#define TELEMETRY_STALE_MS      2000

int16_t telemetry_decode_i16(uint32_t raw);
int32_t telemetry_decode_i32(uint32_t raw);
uint32_t telemetry_retry_delay_ms(uint8_t consecutive_failures);
bool telemetry_value_is_fresh(int64_t now_ms, int64_t updated_ms,
			      int64_t stale_after_ms);
