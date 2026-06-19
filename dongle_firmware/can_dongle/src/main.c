#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>

#include "udp_comm.h"
#include "can_raw.h"
#include "json_protocol.h"
#include "watchdog.h"
#include "motor_state.h"
#include "command_handler.h"
#include "telemetry.h"
#include "sdo_transport.h"

LOG_MODULE_REGISTER(main, LOG_LEVEL_INF);

#define MAIN_LOOP_DELAY_MS 10
#define UDP_RECEIVE_TIMEOUT_MS 10
#define MAX_UDP_MESSAGES_PER_LOOP 16
#define MAX_CAN_FRAMES_PER_LOOP 8

struct motor_state g_motor = {
	.drive_status_word = 0x0040,
	.mode = MODE_PROFILE_VELOCITY,
};
bool g_motor_enabled;
bool g_profile_configured;
int32_t g_target_speed = 50000;
uint8_t g_active_node = DEFAULT_NODE;

static void forward_can_frames(void)
{
	can_frame_t frame;
	char buffer[256];
	for (int count = 0;
	     count < MAX_CAN_FRAMES_PER_LOOP && can_recv(&frame) == 1;
	     count++) {
		int length = json_build_can_log(buffer, sizeof(buffer),
						frame.id, frame.data, frame.dlc);
		udp_send(buffer, length);
	}
}

static void handle_udp_messages(char *buffer, int buffer_size)
{
	int timeout_ms = UDP_RECEIVE_TIMEOUT_MS;

	for (int count = 0; count < MAX_UDP_MESSAGES_PER_LOOP; count++) {
		int length = udp_recv(buffer, buffer_size, timeout_ms);
		if (length <= 0) break;

		parsed_cmd_t command;
		if (cmd_json_parse(buffer, length, &command))
			command_handle(&command);

		timeout_ms = 0;
	}
}

int main(void)
{
	wdg_init();
	int ret = udp_init();
	if (ret < 0) LOG_ERR("UDP init failed: %d", ret);
	ret = can_init();
	if (ret < 0) LOG_WRN("CAN init failed: %d", ret);
	else can_diag();

	char receive_buffer[2048];
	while (1) {
		handle_udp_messages(receive_buffer, sizeof(receive_buffer));
		if (wdg_check())
			command_handle_watchdog_timeout();
		forward_can_frames();
		telemetry_send();
		k_msleep(MAIN_LOOP_DELAY_MS);
	}
	return 0;
}
