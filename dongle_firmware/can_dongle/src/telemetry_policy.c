#include "telemetry_policy.h"

int16_t telemetry_decode_i16(uint32_t raw)
{
	return (int16_t)(uint16_t)raw;
}

int32_t telemetry_decode_i32(uint32_t raw)
{
	return (int32_t)raw;
}

uint32_t telemetry_retry_delay_ms(uint8_t consecutive_failures)
{
	uint32_t delay = TELEMETRY_BASE_RETRY_MS;
	uint8_t shifts = consecutive_failures > 1 ? consecutive_failures - 1 : 0;

	while (shifts-- > 0 && delay < TELEMETRY_MAX_RETRY_MS) {
		delay *= 2U;
	}
	return delay > TELEMETRY_MAX_RETRY_MS ? TELEMETRY_MAX_RETRY_MS : delay;
}

bool telemetry_value_is_fresh(int64_t now_ms, int64_t updated_ms,
			      int64_t stale_after_ms)
{
	return updated_ms > 0 && now_ms >= updated_ms &&
	       now_ms - updated_ms <= stale_after_ms;
}
