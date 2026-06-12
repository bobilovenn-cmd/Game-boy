/*
 * Copy this file to src/wifi_secrets.h and fill in your Wi-Fi details.
 *
 * src/wifi_secrets.h is ignored by git, so the password will stay local.
 */
#pragma once

#undef DONGLE_WIFI_MODE
#define DONGLE_WIFI_MODE     DONGLE_WIFI_MODE_STA

#undef DONGLE_STA_SSID
#define DONGLE_STA_SSID      "HC_PRODUCTS_TEST_ANT"

#undef DONGLE_STA_PASSWORD
#define DONGLE_STA_PASSWORD  "PUT_WIFI_PASSWORD_HERE"

/*
 * Pick an unused IP on the same Wi-Fi as RGB30.
 * Current known devices:
 * - RGB30 often uses 192.168.31.125
 * - Mac often uses   192.168.31.128
 */
#undef DONGLE_STA_IP
#define DONGLE_STA_IP        "192.168.31.126"

#undef DONGLE_STA_GATEWAY
#define DONGLE_STA_GATEWAY   "192.168.31.1"

