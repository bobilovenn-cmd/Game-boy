#!/usr/bin/env python3
"""Bridge stable Linux input event codes to the local Godot UI."""

import socket
import select
import struct
import time

DEVICE = "/dev/input/by-path/platform-rocknix-singleadc-joypad-event-joystick"
DESTINATION = ("127.0.0.1", 5010)
EVENT = struct.Struct("llHHI")
EV_KEY = 1

EVENT_CODE_TO_BUTTON_ID = {
    304: 0,   # BTN_SOUTH = physical B
    305: 1,   # BTN_EAST = physical A
    307: 2,   # BTN_NORTH = physical X
    308: 3,   # BTN_WEST = physical Y
    310: 4,   # BTN_TL = L1
    311: 5,   # BTN_TR = R1
    312: 6,   # BTN_TL2 = L2
    313: 7,   # BTN_TR2 = R2
    314: 8,   # BTN_SELECT
    315: 9,   # BTN_START
    544: 13,  # BTN_DPAD_UP
    545: 14,  # BTN_DPAD_DOWN
    546: 15,  # BTN_DPAD_LEFT
    547: 16,  # BTN_DPAD_RIGHT
}


def send(sock: socket.socket, value: str) -> None:
    sock.sendto(value.encode("ascii"), DESTINATION)


def main() -> None:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(1.0)
    last_ready = 0.0

    with open(DEVICE, "rb", buffering=0) as device:
        while True:
            now = time.monotonic()
            if now - last_ready >= 1.0:
                send(sock, "ready")
                last_ready = now

            readable, _, _ = select.select([device], [], [], 0.25)
            if not readable:
                continue
            data = device.read(EVENT.size)
            if len(data) != EVENT.size:
                continue
            _, _, event_type, code, value = EVENT.unpack(data)
            if event_type != EV_KEY or code not in EVENT_CODE_TO_BUTTON_ID:
                continue

            button_id = EVENT_CODE_TO_BUTTON_ID[code]
            if value == 1:
                send(sock, str(button_id))
            elif value == 0 and button_id in (4, 5):
                send(sock, str(1000 + button_id))


if __name__ == "__main__":
    main()
