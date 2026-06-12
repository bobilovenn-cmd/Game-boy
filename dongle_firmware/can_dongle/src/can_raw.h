/*
 * can_raw.h - CAN 原始帧收发模块
 *
 * 负责:
 *   - CAN 控制器初始化 (1000 kbps)
 *   - 接收/发送 CAN 原始帧
 *   - 将 CAN 帧格式化为可读字符串
 */

#pragma once

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

/* CAN 帧结构 */
typedef struct {
	uint32_t id;       /* 标准帧 11 位 或 扩展帧 29 位 */
	uint8_t  data[8];  /* 数据字节 */
	uint8_t  dlc;      /* 数据长度 (0-8) */
	bool     ext;      /* true = 扩展帧 */
	bool     rtr;      /* true = 远程帧 */
} can_frame_t;

/**
 * 初始化 CAN 控制器。
 * 波特率: 1000000
 * 成功返回 0，失败返回负值。
 */
int can_init(void);

/**
 * 非阻塞接收一个 CAN 帧。
 * @param frame 输出帧
 * @return 1: 成功接收到帧; 0: 没有可用帧; <0: 错误
 */
int can_recv(can_frame_t *frame);

/**
 * 发送一个 CAN 帧。
 * @return 0: 成功; <0: 错误
 */
int can_raw_send(const can_frame_t *frame);

/**
 * 将 CAN 帧格式化为可读字符串。
 * 例: "ID:0x123 EXT:0 DLC:8 DATA:01 02 03 04 05 06 07 08"
 * @return 写入的字节数
 */
int can_frame_to_string(const can_frame_t *frame, char *buf, int buf_size);

/**
 * 诊断 CAN 总线状态：打印状态和错误计数器。
 * 用于判断 CAN 引脚是否连接正确。
 */
void can_diag(void);
