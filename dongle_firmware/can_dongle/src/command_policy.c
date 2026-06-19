#include "command_policy.h"

uint8_t command_resolve_node(cmd_type_t command, int packet_node,
			     uint8_t active_node)
{
	if (command == CMD_HEARTBEAT || command == CMD_ESTOP) {
		return active_node;
	}
	return packet_node >= 1 && packet_node <= 127
		? (uint8_t)packet_node : active_node;
}

bool command_updates_active_node(cmd_type_t command)
{
	switch (command) {
	case CMD_ENABLE:
	case CMD_DISABLE:
	case CMD_JOG_START:
	case CMD_JOG_STOP:
	case CMD_SDO_READ:
	case CMD_SDO_WRITE:
	case CMD_SET_SPEED:
	case CMD_MOVE_POSITION:
		return true;
	case CMD_HEARTBEAT:
	case CMD_ESTOP:
	case CMD_OTA_START:
	case CMD_OTA_CHUNK:
	case CMD_OTA_VERIFY:
	case CMD_OTA_FLASH:
	case CMD_UNKNOWN:
	default:
		return false;
	}
}
