/*
 * command_handler.h - UDP 命令解析与分发
 */

#pragma once

#include "json_protocol.h"

/** 在主循环中每次收到合法 JSON 命令后调用。 */
void command_handle(const parsed_cmd_t *cmd);

/** RGB30 心跳超时后执行一次主动安全失能。 */
void command_handle_watchdog_timeout(void);
