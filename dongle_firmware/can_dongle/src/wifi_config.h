/*
 * wifi_config.h - Wi-Fi mode configuration for the ESP32 dongle.
 *
 * Keep real passwords in src/wifi_secrets.h. That file is ignored by git.
 */
#pragma once

#define DONGLE_WIFI_MODE_AP  0
#define DONGLE_WIFI_MODE_STA 1

/* Default fallback: self-hosted AP. */
#define DONGLE_WIFI_MODE     DONGLE_WIFI_MODE_AP

#define DONGLE_AP_SSID       "CAN_Dongle_01"
#define DONGLE_AP_IP         "192.168.4.1"
#define DONGLE_AP_NETMASK    "255.255.255.0"
#define DONGLE_AP_GATEWAY    "192.168.4.1"

/*
 * Same-router STA mode defaults.
 * Override these in wifi_secrets.h.
 */
#define DONGLE_STA_SSID      ""
#define DONGLE_STA_PASSWORD  ""
#define DONGLE_STA_IP        "192.168.31.126"
#define DONGLE_STA_NETMASK   "255.255.255.0"
#define DONGLE_STA_GATEWAY   "192.168.31.1"

#ifdef DONGLE_USE_LOCAL_WIFI_SECRETS
#include "wifi_secrets.h"
#endif
