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
#define CAN_BAUDRATE		1000000

/* ---- 消息队列: 缓冲接收到的 CAN 帧 ---- */
CAN_MSGQ_DEFINE(can_rx_msgq, 16);

/* ---- 状态 ---- */
static const struct device *can_dev = NULL;
static bool initialized = false;
static int rx_filter_id = -1;
static K_SEM_DEFINE(tx_done_sem, 0, 1);
static int tx_done_error;

static void log_can_state(const char *where)
{
	enum can_state state;
	struct can_bus_err_cnt err_cnt;
	int ret;

	if (!can_dev) {
		return;
	}

	ret = can_get_state(can_dev, &state, &err_cnt);
	if (ret < 0) {
		LOG_WRN("%s: failed to get CAN state: %d", where, ret);
		return;
	}

	LOG_WRN("%s: CAN state=%d tx_err=%u rx_err=%u",
		where, state, err_cnt.tx_err_cnt, err_cnt.rx_err_cnt);
}

static void can_tx_done(const struct device *dev, int error, void *user_data)
{
	ARG_UNUSED(dev);
	ARG_UNUSED(user_data);
	tx_done_error = error;
	if (error != 0) {
		LOG_WRN("CAN TX completed with error: %d", error);
	}
	k_sem_give(&tx_done_sem);
}

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

	/* 配置位时序: 1000 kbps */
	ret = can_set_bitrate(can_dev, CAN_BAUDRATE);
	if (ret < 0) {
		LOG_ERR("Failed to set CAN bitrate: %d", ret);
		return ret;
	}

	/* 设置滤波: 接收所有帧，放入消息队列 */
	const struct can_filter all_filter = {
		.flags = 0,  /* 匹配所有帧 (标准和扩展, 数据和远程) */
		.id = 0,
		.mask = 0,
	};
	rx_filter_id = can_add_rx_filter_msgq(can_dev, &can_rx_msgq, &all_filter);
	if (rx_filter_id < 0) {
		LOG_ERR("Failed to add CAN filter: %d", rx_filter_id);
		return rx_filter_id;
	}

	/* 启动 CAN 控制器 */
	ret = can_start(can_dev);
	if (ret < 0) {
		LOG_ERR("Failed to start CAN: %d", ret);
		return ret;
	}

	initialized = true;
	LOG_INF("CAN initialized at %d kbps", CAN_BAUDRATE / 1000);
	return 0;
}

int can_recv(can_frame_t *frame)
{
	struct can_frame z_frame;

	if (!initialized) return -EAGAIN;

	/* 非阻塞从消息队列读取 CAN 帧 */
	int ret = k_msgq_get(&can_rx_msgq, &z_frame, K_NO_WAIT);
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

int can_raw_send(const can_frame_t *frame)
{
	int ret;
	struct can_frame z_frame;

	if (!initialized) return -EAGAIN;

	memset(&z_frame, 0, sizeof(z_frame));
	z_frame.id = frame->id;
	z_frame.dlc = can_bytes_to_dlc(frame->dlc);
	memcpy(z_frame.data, frame->data, MIN(frame->dlc, 8));

	if (frame->ext) z_frame.flags |= CAN_FRAME_IDE;
	if (frame->rtr) z_frame.flags |= CAN_FRAME_RTR;

	while (k_sem_take(&tx_done_sem, K_NO_WAIT) == 0) {
		/* Drain stale completion signals before submitting a new frame. */
	}
	tx_done_error = 0;

	ret = can_send(can_dev, &z_frame, K_MSEC(5), can_tx_done, NULL);
	if (ret < 0) {
		LOG_WRN("CAN TX submit failed id=0x%X ret=%d", frame->id, ret);
		log_can_state("tx submit failed");
		return ret;
	}

	ret = k_sem_take(&tx_done_sem, K_MSEC(30));
	if (ret < 0) {
		LOG_WRN("CAN TX timeout/no ACK id=0x%X", frame->id);
		log_can_state("tx timeout");
		return -ETIMEDOUT;
	}

	if (tx_done_error != 0) {
		LOG_WRN("CAN TX done error id=0x%X err=%d",
			frame->id, tx_done_error);
		log_can_state("tx done error");
		return tx_done_error;
	}

	return 0;
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
