/*
 * telemetry.h - 周期性 motor_status 上报
 */

#pragma once

/** 每隔 MOTOR_STATUS_INTERVAL_MS 在主循环中调用一次。 */
void telemetry_send(void);

/** 切换活动节点后清除旧节点的轮询退避与数据有效性。 */
void telemetry_reset(void);
