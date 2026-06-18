/*
 * udp_comm.h - UDP 通信模块
 *
 * 负责:
 *   - 初始化 ESP32-S3 Wi-Fi AP 热点 (SSID: CAN_Dongle_01)
 *   - 设置静态 IP 192.168.4.1
 *   - 监听 UDP 端口 5000
 *   - 记录最近通信的客户端地址
 */
#pragma once

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

/**
 * 初始化 Wi-Fi AP 和 UDP socket。
 * 成功返回 0，失败返回负值。
 */
int udp_init(void);

/**
 * 非阻塞接收一个 UDP 报文。
 * @param buf     接收缓冲区
 * @param buf_size 缓冲区大小
 * @param timeout_ms 等待超时（毫秒），0 表示立即返回
 * @return >0: 实际接收字节数; 0: 超时无数据; <0: 错误
 */
int udp_recv(char *buf, int buf_size, int timeout_ms);

/**
 * 向最近通信的客户端发送 UDP 数据。
 * 如果没有已知客户端，不发送。
 * @return >=0: 发送字节数; <0: 错误
 */
int udp_send(const char *data, int len);

/**
 * 向指定地址发送 UDP 数据。
 * @return >=0: 发送字节数; <0: 错误
 */
int udp_sendto(const char *data, int len, const char *ip, int port);

/**
 * 返回最近通信客户端的 IP 地址字符串。
 * 如果没有客户端，返回 "0.0.0.0"。
 */
const char *udp_client_ip(void);
