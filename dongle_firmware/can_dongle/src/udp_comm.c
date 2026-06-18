/*
 * udp_comm.c - Wi-Fi + UDP communication module.
 *
 * Supports two modes:
 *   - AP mode: ESP32 creates CAN_Dongle_01 at 192.168.4.1
 *   - STA mode: ESP32 joins the same router Wi-Fi as RGB30
 */

#include "udp_comm.h"
#include "wifi_config.h"

#include <stdio.h>
#include <string.h>
#include <zephyr/kernel.h>
#include <zephyr/net/net_if.h>
#include <zephyr/net/net_mgmt.h>
#include <zephyr/net/net_event.h>
#include <zephyr/net/wifi_mgmt.h>
#include <zephyr/net/socket.h>
#include <zephyr/net/dhcpv4_server.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(udp_comm, LOG_LEVEL_INF);

#define UDP_PORT 5000
#define WIFI_CONNECT_TIMEOUT_MS 15000

static int udp_sock = -1;
static struct sockaddr_in client_addr;
static bool has_client = false;
static struct net_if *wifi_iface = NULL;

static struct net_mgmt_event_callback wifi_cb;
static K_SEM_DEFINE(wifi_connected, 0, 1);

static const char *active_ip(void)
{
#if DONGLE_WIFI_MODE == DONGLE_WIFI_MODE_STA
	return DONGLE_STA_IP;
#else
	return DONGLE_AP_IP;
#endif
}

static const char *active_netmask(void)
{
#if DONGLE_WIFI_MODE == DONGLE_WIFI_MODE_STA
	return DONGLE_STA_NETMASK;
#else
	return DONGLE_AP_NETMASK;
#endif
}

static const char *active_gateway(void)
{
#if DONGLE_WIFI_MODE == DONGLE_WIFI_MODE_STA
	return DONGLE_STA_GATEWAY;
#else
	return DONGLE_AP_GATEWAY;
#endif
}

static void wifi_event_handler(struct net_mgmt_event_callback *cb,
			       uint64_t mgmt_event, struct net_if *iface)
{
	ARG_UNUSED(cb);
	ARG_UNUSED(iface);

	switch (mgmt_event) {
	case NET_EVENT_WIFI_CONNECT_RESULT:
		LOG_INF("Wi-Fi STA connected");
		k_sem_give(&wifi_connected);
		break;
	case NET_EVENT_WIFI_DISCONNECT_RESULT:
		LOG_WRN("Wi-Fi STA disconnected");
		break;
	case NET_EVENT_WIFI_AP_STA_CONNECTED:
		LOG_INF("Client connected to AP");
		break;
	case NET_EVENT_WIFI_AP_STA_DISCONNECTED:
		LOG_INF("Client disconnected from AP");
		break;
	default:
		break;
	}
}

static int configure_static_ip(void)
{
	struct in_addr addr, gateway, netmask;

	if (net_addr_pton(AF_INET, active_ip(), &addr) < 0) {
		LOG_ERR("Invalid IP: %s", active_ip());
		return -EINVAL;
	}
	if (net_addr_pton(AF_INET, active_netmask(), &netmask) < 0) {
		LOG_ERR("Invalid netmask: %s", active_netmask());
		return -EINVAL;
	}
	if (net_addr_pton(AF_INET, active_gateway(), &gateway) < 0) {
		LOG_ERR("Invalid gateway: %s", active_gateway());
		return -EINVAL;
	}

	net_if_ipv4_addr_add(wifi_iface, &addr, NET_ADDR_MANUAL, 0);
	net_if_ipv4_set_netmask_by_addr(wifi_iface, &addr, &netmask);
	net_if_ipv4_set_gw(wifi_iface, &gateway);
	LOG_INF("Static IP configured: %s", active_ip());
	return 0;
}

static int start_ap_mode(void)
{
	int ret;

	static struct wifi_connect_req_params ap_cfg = {0};
	ap_cfg.band = WIFI_FREQ_BAND_2_4_GHZ;
	ap_cfg.channel = 6;
	ap_cfg.security = WIFI_SECURITY_TYPE_NONE;
	ap_cfg.ssid = (const uint8_t *)DONGLE_AP_SSID;
	ap_cfg.ssid_length = strlen(DONGLE_AP_SSID);

	ret = net_mgmt(NET_REQUEST_WIFI_AP_ENABLE, wifi_iface, &ap_cfg,
		       sizeof(struct wifi_connect_req_params));
	if (ret < 0) {
		LOG_ERR("Failed to enable Wi-Fi AP: %d", ret);
		return ret;
	}

	k_sleep(K_MSEC(500));

	struct in_addr dhcp_base;
	net_addr_pton(AF_INET, "192.168.4.100", &dhcp_base);
	ret = net_dhcpv4_server_start(wifi_iface, &dhcp_base);
	if (ret < 0) {
		LOG_WRN("DHCP server start failed: %d", ret);
	} else {
		LOG_INF("DHCP server started, pool from 192.168.4.100");
	}

	LOG_INF("Wi-Fi AP '%s' started, IP: %s", DONGLE_AP_SSID, DONGLE_AP_IP);
	return 0;
}

static int start_sta_mode(void)
{
	int ret;

	if (strlen(DONGLE_STA_SSID) == 0) {
		LOG_ERR("STA mode selected but DONGLE_STA_SSID is empty");
		return -EINVAL;
	}

	static struct wifi_connect_req_params sta_cfg = {0};
	sta_cfg.band = WIFI_FREQ_BAND_2_4_GHZ;
	sta_cfg.channel = WIFI_CHANNEL_ANY;
	sta_cfg.ssid = (const uint8_t *)DONGLE_STA_SSID;
	sta_cfg.ssid_length = strlen(DONGLE_STA_SSID);
	if (strlen(DONGLE_STA_PASSWORD) > 0) {
		sta_cfg.security = WIFI_SECURITY_TYPE_PSK;
		sta_cfg.psk = (const uint8_t *)DONGLE_STA_PASSWORD;
		sta_cfg.psk_length = strlen(DONGLE_STA_PASSWORD);
	} else {
		sta_cfg.security = WIFI_SECURITY_TYPE_NONE;
	}

	LOG_INF("Connecting Wi-Fi STA to '%s' with static IP %s",
		DONGLE_STA_SSID, DONGLE_STA_IP);
	ret = net_mgmt(NET_REQUEST_WIFI_CONNECT, wifi_iface, &sta_cfg,
		       sizeof(struct wifi_connect_req_params));
	if (ret < 0) {
		LOG_ERR("Failed to start Wi-Fi STA connection: %d", ret);
		return ret;
	}

	ret = k_sem_take(&wifi_connected, K_MSEC(WIFI_CONNECT_TIMEOUT_MS));
	if (ret < 0) {
		LOG_ERR("Wi-Fi STA connect timeout");
		return -ETIMEDOUT;
	}

	LOG_INF("Wi-Fi STA ready: SSID=%s IP=%s UDP=%d",
		DONGLE_STA_SSID, DONGLE_STA_IP, UDP_PORT);
	return 0;
}

static int create_udp_socket(void)
{
	udp_sock = zsock_socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
	if (udp_sock < 0) {
		LOG_ERR("Failed to create UDP socket: %d", udp_sock);
		return udp_sock;
	}

	struct sockaddr_in bind_addr = {
		.sin_family = AF_INET,
		.sin_port = htons(UDP_PORT),
		.sin_addr.s_addr = INADDR_ANY,
	};
	int ret = zsock_bind(udp_sock, (struct sockaddr *)&bind_addr, sizeof(bind_addr));
	if (ret < 0) {
		LOG_ERR("Failed to bind UDP port %d: %d", UDP_PORT, ret);
		zsock_close(udp_sock);
		udp_sock = -1;
		return ret;
	}

	struct timeval tv = { .tv_sec = 0, .tv_usec = 100000 };
	zsock_setsockopt(udp_sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
	LOG_INF("UDP socket listening on port %d", UDP_PORT);
	return 0;
}

int udp_init(void)
{
	int ret;

	wifi_iface = net_if_get_first_wifi();
	if (!wifi_iface) {
		LOG_ERR("No Wi-Fi interface found");
		return -ENODEV;
	}
	LOG_INF("Wi-Fi interface: %p", (void *)wifi_iface);

	net_mgmt_init_event_callback(&wifi_cb, wifi_event_handler,
		NET_EVENT_WIFI_CONNECT_RESULT |
		NET_EVENT_WIFI_DISCONNECT_RESULT |
		NET_EVENT_WIFI_AP_STA_CONNECTED |
		NET_EVENT_WIFI_AP_STA_DISCONNECTED);
	net_mgmt_add_event_callback(&wifi_cb);

	ret = configure_static_ip();
	if (ret < 0) return ret;

	net_if_up(wifi_iface);
	k_sleep(K_SECONDS(5));

#if DONGLE_WIFI_MODE == DONGLE_WIFI_MODE_STA
	ret = start_sta_mode();
#else
	ret = start_ap_mode();
#endif
	if (ret < 0) return ret;

	return create_udp_socket();
}

int udp_recv(char *buf, int buf_size, int timeout_ms)
{
	if (udp_sock < 0) return -ENOTCONN;

	struct timeval tv = {
		.tv_sec = timeout_ms / 1000,
		.tv_usec = (timeout_ms % 1000) * 1000,
	};
	zsock_setsockopt(udp_sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

	struct sockaddr_in src_addr;
	socklen_t src_len = sizeof(src_addr);
	int ret = zsock_recvfrom(udp_sock, buf, buf_size - 1, 0,
				 (struct sockaddr *)&src_addr, &src_len);
	if (ret > 0) {
		buf[ret] = '\0';
		memcpy(&client_addr, &src_addr, sizeof(client_addr));
		has_client = true;
	}
	return ret;
}

int udp_send(const char *data, int len)
{
	if (!has_client) return -ENOTCONN;
	ssize_t ret = zsock_sendto(udp_sock, data, len, 0,
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
	ssize_t ret = zsock_sendto(udp_sock, data, len, 0,
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

