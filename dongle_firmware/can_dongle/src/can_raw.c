/*
 * can_raw.c - CAN 原始帧收发模块实现
 *
 * 使用 Zephyr CAN 驱动。硬件假设:
 *   - ESP32-S3 内部 TWAI 控制器
 *   - 外部 TJA1050 收发器
 *   - RX: GPIO19, TX: GPIO20 (在 overlay 中定义)
 */

#include "can_raw.h"

#include <stdio.h>
#include <string.h>
#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/can.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(can_raw, LOG_LEVEL_INF);

/* ---- 配置 ---- */
#define CAN_BAUDRATE		500000

/* ---- 状态 ---- */
static const struct device *can_dev = NULL;
static bool initialized = false;

int can_init(void)
{
	int ret;

	/* 获取 CAN 设备 */
	can_dev = DEVICE_DT_GET(DT_ALIAS(can0));
	if (!device_is_ready(can_dev)) {
		LOG_ERR("CAN device not ready");
		return -ENODEV;
	}
	LOG_INF("CAN device: %s", can_dev->name);

	/* 配置位时序: 500 kbps */
	/* Zephyr CAN 驱动会根据 bus-speed DT 属性自动配置，
	 * 这里手动指定以覆盖默认值 */
	ret = can_set_bitrate(can_dev, CAN_BAUDRATE);
	if (ret < 0) {
		LOG_ERR("Failed to set CAN bitrate: %d", ret);
		return ret;
	}

	/* 设置滤波: 接收所有帧 */
	const struct can_filter all_filter = {
		.flags = CAN_FILTER_DATA | CAN_FILTER_STD | CAN_FILTER_EXT,
		.id = 0,
		.mask = 0,
	};
	ret = can_add_rx_filter(can_dev, NULL, &all_filter);
	if (ret < 0) {
		LOG_ERR("Failed to add CAN filter: %d", ret);
		return ret;
	}

	/* 启动 CAN 控制器 */
	ret = can_start(can_dev);
	if (ret < 0) {
		LOG_ERR("Failed to start CAN: %d", ret);
		return ret;
	}

	initialized = true;
	LOG_INF("CAN initialized at %d bps", CAN_BAUDRATE);
	return 0;
}

int can_recv(can_frame_t *frame)
{
	int ret;
	struct can_frame z_frame;

	if (!initialized) return -EAGAIN;

	ret = can_receive(can_dev, &z_frame, K_NO_WAIT);
	if (ret == -ENOMSG) {
		return 0; /* 无可用帧 */
	}
	if (ret < 0) {
		return ret;
	}

	/* 转换为我们的帧结构 */
	frame->id = z_frame.id;
	frame->dlc = (uint8_t)can_dlc_to_bytes(z_frame.dlc);
	memcpy(frame->data, z_frame.data, MIN(frame->dlc, 8));
	frame->ext = (z_frame.flags & CAN_FRAME_IDE) != 0;
	frame->rtr = (z_frame.flags & CAN_FRAME_RTR) != 0;

	return 1;
}

int can_send(const can_frame_t *frame)
{
	int ret;
	struct can_frame z_frame;

	if (!initialized) return -EAGAIN;

	z_frame.id = frame->id;
	z_frame.dlc = can_bytes_to_dlc(frame->dlc);
	memcpy(z_frame.data, frame->data, MIN(frame->dlc, 8));

	if (frame->ext) z_frame.flags |= CAN_FRAME_IDE;
	if (frame->rtr) z_frame.flags |= CAN_FRAME_RTR;

	ret = can_send(can_dev, &z_frame, K_MSEC(100), NULL, NULL);
	return ret;
}

int can_frame_to_string(const can_frame_t *frame, char *buf, int buf_size)
{
	int pos = 0;
	pos += snprintf(buf + pos, buf_size - pos,
			"ID:0x%X EXT:%d DLC:%d DATA:",
			frame->id, frame->ext ? 1 : 0, frame->dlc);
	for (int i = 0; i < frame->dlc && i < 8; i++) {
		pos += snprintf(buf + pos, buf_size - pos,
				"%s%02X", (i > 0 ? " " : ""), frame->data[i]);
	}
	return pos;
}
