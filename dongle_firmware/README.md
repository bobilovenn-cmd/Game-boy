# ESP32 CAN Dongle Development Guide

This directory is reserved for the real ESP32 CAN dongle firmware.

Project role:

- RGB30 runs the Godot diagnostic UI.
- ESP32-S3 dongle listens on UDP port 5000.
- RGB30 listens on UDP port 5001.
- Messages are UTF-8 JSON.
- The dongle converts UI commands to CAN/CANopen traffic and reports motor state back to RGB30.

## Current Target

Build the first real dongle in two steps.

Phase 0: UDP + CAN raw gateway

- Start Wi-Fi AP `CAN_Dongle_01`.
- Use dongle IP `192.168.4.1`.
- Listen for JSON commands on UDP `5000`.
- Remember the latest RGB30 address from any incoming packet.
- Reply to `heartbeat`, `enable`, `disable`, `estop`, `jog_start`, `jog_stop`, `sdo_read`, `sdo_write`, and OTA commands with the same JSON shape used by `mock_server/mock_dongle.py`.
- Initialize CAN at `500000`.
- Receive all CAN frames and forward readable CAN log rows to RGB30.
- Periodically send `motor_status` so the Monitor page has live data.

Phase 1: CANopen motor control

- Convert `enable`, `disable`, `jog_start`, and `jog_stop` into CiA 402 SDO/PDO writes.
- Implement expedited SDO read/write for object dictionary entries shown on the Config page.
- Decode status word, current, voltage, speed, position, torque, fault, mode, and heartbeat into `motor_status`.
- Keep the 500 ms heartbeat watchdog. If RGB30 stops sending heartbeat, send NMT stop / safe stop.

Phase 2: motor firmware flashing

- Receive firmware from RGB30 via `ota_start` and `ota_chunk`.
- Verify MD5 on `ota_verify`.
- On `ota_flash`, transfer the file to the selected motor node using the motor vendor's bootloader protocol.

## Existing Protocol Contract

The source of truth is:

- `/Users/guoweifeng/Game Boy/godot_terminal/scripts/protocol.gd`
- `/Users/guoweifeng/Game Boy/godot_terminal/API接口文档.md`
- `/Users/guoweifeng/Game Boy/mock_server/mock_dongle.py`

Required UDP settings:

```text
Dongle UDP: 192.168.4.1:5000
RGB30 UDP: 0.0.0.0:5001
Heartbeat: 150 ms from RGB30
CAN bitrate: 500000
JSON encoding: UTF-8
```

Development/mock setting currently used by Godot:

```text
godot_terminal/scripts/settings.gd
DONGLE_IP = "192.168.31.128"
```

For the real dongle, change it back to:

```gdscript
const DONGLE_IP = "192.168.4.1"
```

## Hardware Assumption

Current project memory says the planned board is:

```text
Waveshare ESP32-S3-RS485-CAN
CAN RX: GPIO19
CAN TX: GPIO20
CAN transceiver: TJA1050
Termination: enable 120 ohm only if this dongle is at one end of the CAN bus
Power: 7-36 V DC or USB-C 5 V
```

If the board changes, keep the UDP protocol unchanged and only change the Zephyr board/overlay.

## Build Environment

A Zephyr workspace already exists on this Mac:

```text
/Users/guoweifeng/esp32-can-dongle
/Users/guoweifeng/zephyrproject/.venv/bin/west
```

The existing build cache is currently from Zephyr `hello_world`, not the dongle app, so the dongle firmware should be created as a new app directory instead of modifying Zephyr samples.

Suggested app location:

```text
/Users/guoweifeng/Game Boy/dongle_firmware/can_dongle
```

Suggested build command:

```sh
cd /Users/guoweifeng/esp32-can-dongle
source /Users/guoweifeng/zephyrproject/.venv/bin/activate
west build -b esp32s3_devkitm /Users/guoweifeng/Game\ Boy/dongle_firmware/can_dongle -d build-can-dongle
```

Suggested flash command after plugging in the ESP32-S3:

```sh
cd /Users/guoweifeng/esp32-can-dongle
source /Users/guoweifeng/zephyrproject/.venv/bin/activate
west flash -d build-can-dongle
```

## First Verification Checklist

1. RGB30 connects to `CAN_Dongle_01`.
2. RGB30 can ping `192.168.4.1`.
3. Godot `UDP` status is green.
4. Godot `LINK` status becomes green after receiving `motor_status`.
5. CAN page shows raw frames, for example:

```text
0x0010: c0a8 1f7d 1388 1389 00a3 e915 7b22 636d
```

6. Selecting a node from 1-127 only affects that node's commands.
7. If RGB30 stops sending heartbeat for more than 500 ms, dongle sends a safe stop.

## Implementation Order

1. `main.c`: initialize Wi-Fi, UDP, CAN, watchdog, and status timer.
2. `udp_comm.c`: bind UDP 5000, receive JSON, store RGB30 address, send JSON replies.
3. `json_protocol.c`: parse commands and format `ack`, `motor_status`, `sdo_read_result`, `ota_status`, and CAN log packets.
4. `can_raw.c`: initialize TWAI/CAN, send/receive raw frames, format readable frames for the CAN log page.
5. `canopen_bridge.c`: implement expedited SDO read/write and CiA 402 control helpers.
6. `ota_manager.c`: receive firmware, verify MD5, later flash to the motor.

## Safety Rules

- `estop` must not depend on normal UI state.
- Heartbeat timeout must stop the motor even if UDP parsing or OTA is busy.
- OTA must not run motor control writes at the same time unless explicitly allowed.
- Node IDs outside `1..127` must be rejected.
- Unknown commands must return an `ack` with `status="error"` instead of doing nothing silently.

