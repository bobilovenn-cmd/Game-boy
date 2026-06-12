/*
 * watchdog.h - 心跳看门狗模块
 *
 * 监控 RGB30 心跳间隔。
 * 超过 500ms 没有 heartbeat → 触发安全状态
 * 安全状态下所有电机控制命令被拦截。
 */

#pragma once

#include <stdint.h>
#include <stdbool.h>

/* 心跳超时阈值 (毫秒) */
#define WDG_TIMEOUT_MS		500

/**
 * 初始化看门狗。
 */
void wdg_init(void);

/**
 * 喂狗 — 每次收到 heartbeat 命令时调用。
 */
void wdg_feed(void);

/**
 * 检查看门狗状态。
 * 应在主循环中周期性调用。
 * 如果超时未被喂狗，内部会自动进入安全状态。
 */
void wdg_check(void);

/**
 * 返回当前是否处于安全状态。
 * 安全状态下应拦截所有电机控制命令。
 */
bool wdg_is_safe(void);

/**
 * 返回距离超时还剩多少毫秒。
 * 用于 motor_status 的 wdg_ms 字段。
 */
int wdg_remaining_ms(void);
