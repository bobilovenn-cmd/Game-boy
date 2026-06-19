/*
 * sdo_transport.h - CANopen SDO 传输层
 *
 * 封装 SDO 读写、CAN 帧等待、NMT 操作，不包含 CiA 402 运动控制逻辑。
 */

#pragma once

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include "can_raw.h"

/* ---- CiA 402 object dictionary indices (被上层引用) ---- */
#define OD_CONTROL_WORD          0x6040
#define OD_STATUS_WORD           0x6041
#define OD_MODE_OPERATION        0x6060
#define OD_MODE_DISPLAY          0x6061
#define OD_TARGET_VELOCITY       0x60FF
#define OD_TARGET_POSITION       0x607A
#define OD_PROFILE_VELOCITY      0x6081
#define OD_PROFILE_ACCELERATION  0x6083
#define OD_PROFILE_DECELERATION  0x6084
#define OD_ACTUAL_VELOCITY       0x606C
#define OD_ACTUAL_POSITION       0x6064
#define OD_CURRENT_ACTUAL        0x3001
#define OD_CURRENT_ACTUAL_STD    0x6078
#define OD_DC_LINK_VOLTAGE       0x6079
#define OD_TORQUE_ACTUAL         0x6077

/* ---- CiA 402 control word bits ---- */
#define CW_DISABLE_VOLTAGE       0x0000
#define CW_SHUTDOWN              0x0006
#define CW_SWITCH_ON             0x0007
#define CW_ENABLE_OPERATION      0x000F
#define CW_QUICK_STOP            0x0002
#define CW_FAULT_RESET           0x0080
#define CW_NEW_SET_POINT         0x001F
#define CW_CHANGE_IMM            0x003F

/* ---- Mode codes ---- */
#define MODE_PROFILE_VELOCITY    3
#define MODE_PROFILE_POSITION    1

/* ---- Timing (ms) ---- */
#define SDO_RESPONSE_TIMEOUT_MS  500
#define NMT_START_TIMEOUT_MS     5000
#define HEARTBEAT_POLL_MS        50

/* ---- Default motion parameters ---- */
#define DEFAULT_PROFILE_VELOCITY      100000
#define DEFAULT_PROFILE_ACCELERATION  100000
#define DEFAULT_PROFILE_DECELERATION  100000

/* ---- NMT states ---- */
#define NMT_STATE_OPERATIONAL  0x05
#define NMT_STATE_PRE_OP       0x7F
#define NMT_STATE_STOPPED      0x04

int sdo_write(uint8_t node, uint16_t index, uint8_t sub, uint32_t value, uint8_t size);

int sdo_read_u32(uint8_t node, uint16_t index, uint8_t sub, uint32_t *value);
int sdo_read_i8(uint8_t node, uint16_t index, uint8_t sub, int8_t *value);
int sdo_read_i16(uint8_t node, uint16_t index, uint8_t sub, int16_t *value);
int sdo_read_u16(uint8_t node, uint16_t index, uint8_t sub, uint16_t *value);
int sdo_read_i32(uint8_t node, uint16_t index, uint8_t sub, int32_t *value);

int nmt_start(uint8_t node);
int nmt_pre_operational(uint8_t node);
int nmt_reset_comm(uint8_t node);
int nmt_wait_operational(uint8_t node, int timeout_ms);
