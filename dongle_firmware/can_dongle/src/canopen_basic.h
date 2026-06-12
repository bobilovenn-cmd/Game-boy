/*
 * canopen_basic.h - CiA 402 motor-control helpers for the ESP32 CAN dongle.
 */
#pragma once

#include <stdint.h>

/* ---- NMT ---- */

/** Send NMT start command to a single node. */
int co_nmt_start(uint8_t node);

/** Wait for the node to enter Operational state via heartbeat (0x700+node). */
int co_wait_operational(uint8_t node, int timeout_ms);

/* ---- CiA 402 enable / disable ---- */

/** Full CiA 402 enable sequence: shutdown → switch on → enable operation. */
int co_basic_enable(uint8_t node);

/** Disable the motor (disable voltage). */
int co_basic_disable(uint8_t node);

/* ---- Motion profile ---- */

/** Set velocity mode + configure profile velocity/accel/decel. */
int co_init_profile(uint8_t node);

/* ---- Motion commands ---- */

/** Jog at a given speed (positive = cw, negative = ccw, units: UI rpm). */
int co_basic_jog(uint8_t node, int rpm);

/** Quick-stop the motor. */
int co_basic_stop(uint8_t node);

/** Emergency stop — immediately disable voltage. */
int co_basic_estop(uint8_t node);

/* ---- Live data reads ---- */

/** Read status word (0x6041). Returns value or negative error. */
int co_read_status_word(uint8_t node);

/** Read actual velocity (0x606C). Returns value or negative error. */
int co_read_actual_velocity(uint8_t node);

/** Generic SDO write: download 32-bit value to any object dictionary entry. Returns 0 or negative error. */
int co_sdo_write(uint8_t node, uint16_t index, uint8_t sub, uint32_t value, uint8_t size);

/** Generic SDO read: upload any object dictionary entry. Returns value or negative error. */
int co_sdo_read(uint8_t node, uint16_t index, uint8_t sub);

/** Read actual position (0x6064). Returns value or negative error. */
int co_read_actual_position(uint8_t node);
