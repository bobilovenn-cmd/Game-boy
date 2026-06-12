/*
 * udp_comm.c - UDP 通信模块实现
 *
 * Wi-Fi AP 模式 + UDP socket 收发。
 * 基于 Zephyr 网络栈和 ESP32 Wi-Fi 驱动。
 */

#include "udp_comm.h"

#include <stdio.h>
#include <string.h>
#include <zephyr/kernel.h>
#include <zephyr/net/net_if.h>
#include <zephyr/net/net_mgmt.h>
#include <zephyr/net/net_event.h>
#include <zephyr/net/wifi_mgmt.h>
#include <zephyr/net/socket.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(udp_comm, LOG_LEVEL_INF);

/* ---- 配置 ---- */
#define UDP_PORT		5000
#define WIFI_SSID		"CAN_Dongle_01"
#define DONGLE_IP		"192.168.4.1"
#define DONGLE_NETMASK		"255.255.255.0"
#define DONGLE_GATEWAY		"192.168.4.1"

/* ---- 状态 ---- */
static int udp_sock = -1;
static struct sockaddr_in client_addr;
static bool has_client = false;
static struct net_if *wifi_iface = NULL;

/* Wi-Fi 事件回调 */
static struct net_mgmt_event_callback wifi_cb;
static K_SEM_DEFINE(wifi_connected, 0, 1);
static K_SEM_DEFINE(wifi_ready, 0, 1);

static void wifi_event_handler(struct net_mgmt_event_callback *cb,
			       uint32_t mgmt_event, struct net_if *iface)
{
	switch (mgmt_event) {
	case NET_EVENT_WIFI_AP_READY:
		LOG_INF("Wi-Fi AP ready");
		k_sem_give(&wifi_ready);
		break;
	case NET_EVENT_WIFI_AP_STA_CONNECTED:
		LOG_INF("Client connected to AP");
		k_sem_give(&wifi_connected);
		break;
	case NET_EVENT_WIFI_AP_STA_DISCONNECTED:
		LOG_INF("Client disconnected from AP");
		break;
	default:
		break;
	}
}

int udp_init(void)
{
	int ret;

	/* ---- 1. 获取 Wi-Fi 网络接口 ---- */
	wifi_iface = net_if_get_first_wifi();
	if (!wifi_iface) {
		LOG_ERR("No Wi-Fi interface found");
		return -ENODEV;
	}
	LOG_INF("Wi-Fi interface: %p", (void *)wifi_iface);

	/* ---- 2. 注册 Wi-Fi 事件回调 ---- */
	net_mgmt_init_event_callback(&wifi_cb, wifi_event_handler,
		NET_EVENT_WIFI_AP_READY |
		NET_EVENT_WIFI_AP_STA_CONNECTED |
		NET_EVENT_WIFI_AP_STA_DISCONNECTED);
	net_mgmt_add_event_callback(&wifi_cb);

	/* ---- 3. 配置静态 IP ---- */
	struct in_addr addr, gateway, netmask;
	if (net_addr_pton(AF_INET, DONGLE_IP, &addr) < 0) {
		LOG_ERR("Invalid IP: %s", DONGLE_IP);
		return -EINVAL;
	}
	if (net_addr_pton(AF_INET, DONGLE_NETMASK, &netmask) < 0) {
		LOG_ERR("Invalid netmask");
		return -EINVAL;
	}
	if (net_addr_pton(AF_INET, DONGLE_GATEWAY, &gateway) < 0) {
		LOG_ERR("Invalid gateway");
		return -EINVAL;
	}

	net_if_ipv4_addr_add(wifi_iface, &addr, NET_ADDR_MANUAL, 0);
	net_if_ipv4_set_netmask(wifi_iface, &netmask);
	net_if_ipv4_set_gw(wifi_iface, &gateway);
	LOG_INF("Static IP configured: %s", DONGLE_IP);

	/* ---- 4. 启动 Wi-Fi AP ---- */
	struct wifi_ap_config ap_cfg = {0};
	ap_cfg.band = WIFI_FREQ_BAND_2_4_GHZ;
	ap_cfg.channel = 6;
	ap_cfg.security = WIFI_SECURITY_TYPE_NONE; /* 开放热点 */
	strncpy(ap_cfg.ssid, WIFI_SSID, sizeof(ap_cfg.ssid) - 1);
	ap_cfg.ssid_len = strlen(WIFI_SSID);

	ret = net_mgmt(NET_REQUEST_WIFI_AP_START, wifi_iface, &ap_cfg,
		       sizeof(ap_cfg));
	if (ret < 0) {
		LOG_ERR("Failed to start Wi-Fi AP: %d", ret);
		return ret;
	}

	/* 等待 AP 就绪 */
	ret = k_sem_take(&wifi_ready, K_SECONDS(10));
	if (ret < 0) {
		LOG_ERR("Wi-Fi AP start timeout");
		return -ETIMEDOUT;
	}

	/* 确保网络接口已启动 */
	net_if_up(wifi_iface);
	LOG_INF("Wi-Fi AP '%s' started, IP: %s", WIFI_SSID, DONGLE_IP);

	/* ---- 5. 创建 UDP socket ---- */
	udp_sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
	if (udp_sock < 0) {
		LOG_ERR("Failed to create UDP socket: %d", udp_sock);
		return udp_sock;
	}

	struct sockaddr_in bind_addr = {
		.sin_family = AF_INET,
		.sin_port = htons(UDP_PORT),
		.sin_addr.s_addr = INADDR_ANY,
	};
	ret = bind(udp_sock, (struct sockaddr *)&bind_addr, sizeof(bind_addr));
	if (ret < 0) {
		LOG_ERR("Failed to bind UDP port %d: %d", UDP_PORT, ret);
		close(udp_sock);
		udp_sock = -1;
		return ret;
	}

	/* 设置非阻塞 + 超时 */
	struct timeval tv = { .tv_sec = 0, .tv_usec = 100000 }; /* 100ms */
	setsockopt(udp_sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

	LOG_INF("UDP socket listening on port %d", UDP_PORT);
	return 0;
}

int udp_recv(char *buf, int buf_size, int timeout_ms)
{
	if (udp_sock < 0) return -ENOTCONN;

	/* 设置接收超时 */
	struct timeval tv = {
		.tv_sec = timeout_ms / 1000,
		.tv_usec = (timeout_ms % 1000) * 1000,
	};
	setsockopt(udp_sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

	struct sockaddr_in src_addr;
	socklen_t src_len = sizeof(src_addr);
	int ret = recvfrom(udp_sock, buf, buf_size - 1, 0,
			   (struct sockaddr *)&src_addr, &src_len);
	if (ret > 0) {
		buf[ret] = '\0';
		/* 记录客户端地址 */
		memcpy(&client_addr, &src_addr, sizeof(client_addr));
		has_client = true;
	}
	return ret;
}

int udp_send(const char *data, int len)
{
	if (!has_client) return -ENOTCONN;
	ssize_t ret = sendto(udp_sock, data, len, 0,
			     (struct sockaddr *)&client_addr,
			     sizeof(client_addr));
	return (int)ret;
}

int udp_sendto(const char *data, int len, const char *ip, int port)
{
	struct sockaddr_in dest = {
		.sin_family = AF_INET,
		.sin_port = htons(port),
	};
	if (net_addr_pton(AF_INET, ip, &dest.sin_addr) < 0) {
		return -EINVAL;
	}
	ssize_t ret = sendto(udp_sock, data, len, 0,
			     (struct sockaddr *)&dest, sizeof(dest));
	return (int)ret;
}

const char *udp_client_ip(void)
{
	if (!has_client) return "0.0.0.0";
	static char ip_str[16];
	net_addr_ntop(AF_INET, &client_addr.sin_addr, ip_str, sizeof(ip_str));
	return ip_str;
}
