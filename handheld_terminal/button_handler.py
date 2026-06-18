"""button_handler.py — RGB30 按键处理（直接读取 /dev/input/js0）"""

import struct
import threading
import logging
from typing import Callable, Optional

logger = logging.getLogger(__name__)

# js event types
JS_EVENT_BUTTON = 0x01
JS_EVENT_AXIS = 0x02
JS_EVENT_INIT = 0x80

# Button mapping (joystick button index -> action)
JS_BTN_MAP = {
    0: "confirm",   # A
    1: "back",      # B
    2: "enable",    # X
    3: "disable",   # Y
    4: "jog_ccw",   # L1
    5: "jog_cw",    # R1
    6: "estop",     # Select
    7: "menu",      # Start
    10: "up",       # D-pad up
    11: "down",     # D-pad down
    12: "left",     # D-pad left
    13: "right",    # D-pad right
}

JS_HAT_MAP = {
    (0, 1): "up",
    (0, -1): "down",
    (-1, 0): "left",
    (1, 0): "right",
}


class ButtonHandler:
    """RGB30 按键处理，直接读取 /dev/input/js0"""

    def __init__(self):
        self._callback: Optional[Callable[[str], None]] = None
        self._running = False
        self._thread: Optional[threading.Thread] = None

    def set_callback(self, callback: Callable[[str], None]):
        self._callback = callback

    def start(self):
        self._running = True
        self._thread = threading.Thread(target=self._read_loop, daemon=True)
        self._thread.start()

    def stop(self):
        self._running = False

    def _read_loop(self):
        """读取 /dev/input/js0 事件"""
        JS_EVENT_FORMAT = 'IhBB'  # time, value, type, number
        JS_EVENT_SIZE = struct.calcsize(JS_EVENT_FORMAT)

        try:
            with open('/dev/input/js0', 'rb') as js:
                logger.info("手柄设备已打开: /dev/input/js0")
                while self._running:
                    data = js.read(JS_EVENT_SIZE)
                    if not data or len(data) < JS_EVENT_SIZE:
                        continue

                    timestamp, value, event_type, number = struct.unpack(JS_EVENT_FORMAT, data)

                    # 过滤 init 事件
                    if event_type & JS_EVENT_INIT:
                        event_type &= ~JS_EVENT_INIT

                    if event_type == JS_EVENT_BUTTON and self._callback:
                        action = JS_BTN_MAP.get(number)
                        if action:
                            if value == 1:  # 按下
                                self._callback(action)
                            elif value == 0 and action in ("jog_cw", "jog_ccw"):
                                self._callback(action + "_release")

                    elif event_type == JS_EVENT_AXIS and self._callback:
                        # D-pad 可能是 axis 0/1
                        pass

        except FileNotFoundError:
            logger.warning("未找到 /dev/input/js0")
        except Exception as e:
            if self._running:
                logger.error(f"手柄读取错误: {e}")

    def process_pygame_event(self, event):
        """兼容接口（不使用）"""
        pass
