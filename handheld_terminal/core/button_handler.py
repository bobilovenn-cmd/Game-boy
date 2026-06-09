"""button_handler.py — RGB30 按键处理"""

import struct
import threading
import time
import logging
from typing import Callable, Optional

logger = logging.getLogger(__name__)

JS_EVENT_FORMAT = 'IhBB'
JS_EVENT_SIZE = struct.calcsize(JS_EVENT_FORMAT)

JS_BTN_MAP = {
    0: "confirm",   # A
    1: "back",      # B
    2: "enable",    # X
    3: "disable",   # Y
    4: "jog_ccw",   # L1
    5: "jog_cw",    # R1
    6: "estop",     # Select
    7: "menu",      # Start
    10: "up",
    11: "down",
    12: "left",
    13: "right",
}


class ButtonHandler:
    def __init__(self):
        self._callback = None
        self._running = False

    def set_callback(self, callback):
        self._callback = callback

    def start(self):
        self._running = True
        t = threading.Thread(target=self._loop, daemon=True)
        t.start()

    def stop(self):
        self._running = False

    def _loop(self):
        logger.info("按键线程启动")
        while self._running:
            try:
                with open('/dev/input/js0', 'rb') as js:
                    logger.info("js0 已打开")
                    while self._running:
                        data = js.read(JS_EVENT_SIZE)
                        if not data or len(data) < JS_EVENT_SIZE:
                            continue
                        ts, val, etype, num = struct.unpack(JS_EVENT_FORMAT, data)
                        if etype & 0x7F == 1:  # button
                            action = JS_BTN_MAP.get(num)
                            if action and self._callback:
                                if val == 1:
                                    self._callback(action)
                                elif val == 0 and action in ("jog_cw", "jog_ccw"):
                                    self._callback(action + "_release")
            except Exception as e:
                logger.error(f"手柄错误: {e}")
                time.sleep(1)

    def process_pygame_event(self, event):
        pass
