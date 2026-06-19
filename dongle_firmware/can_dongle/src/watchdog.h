/*
 * watchdog.h - 心跳看门狗模块
 */

#pragma once

#include <stdint.h>
#include <stdbool.h>

#define WDG_TIMEOUT_MS 500

void wdg_init(void);
void wdg_feed(void);

/** 检查看门狗，仅在本次调用刚进入超时安全状态时返回 true。 */
bool wdg_check(void);

bool wdg_is_safe(void);
int wdg_remaining_ms(void);
