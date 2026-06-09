"""motor_data.py — 电机实时数据存储与更新"""

import time
from collections import deque
from typing import Dict, List, Tuple

from config import WAVEFORM_HISTORY


class MotorData:
    """电机数据模型，支持实时波形记录"""

    def __init__(self):
        self.current: float = 0.0
        self.voltage: float = 0.0
        self.speed: int = 0
        self.position: float = 0.0
        self.torque: float = 0.0
        self.status_word: int = 0
        self.fault_code: int = 0
        self.mode: int = 0
        self.alive: bool = False
        self.wdg_ms: int = 0

        self._history_size = WAVEFORM_HISTORY
        self._timestamps: deque = deque(maxlen=self._history_size)
        self._current_history: deque = deque(maxlen=self._history_size)
        self._speed_history: deque = deque(maxlen=self._history_size)
        self._torque_history: deque = deque(maxlen=self._history_size)
        self._start_time = time.time()

    def update_from_dict(self, data: Dict):
        if "current" in data:
            self.current = data["current"]
        if "voltage" in data:
            self.voltage = data["voltage"]
        if "speed" in data:
            self.speed = data["speed"]
        if "position" in data:
            self.position = data["position"]
        if "torque" in data:
            self.torque = data["torque"]
        if "fault" in data:
            self.fault_code = data["fault"]
        if "status_word" in data:
            try:
                self.status_word = int(data["status_word"], 16)
            except (ValueError, TypeError):
                pass
        if "alive" in data:
            self.alive = data["alive"]
        if "wdg_ms" in data:
            self.wdg_ms = data["wdg_ms"]

        t = time.time() - self._start_time
        self._timestamps.append(t)
        self._current_history.append(self.current)
        self._speed_history.append(self.speed)
        self._torque_history.append(self.torque)

    def get_waveform_data(self, param: str) -> Tuple[List[float], List[float]]:
        x = list(self._timestamps)
        if param == "current":
            return x, list(self._current_history)
        elif param == "speed":
            return x, list(self._speed_history)
        elif param == "torque":
            return x, list(self._torque_history)
        return x, []

    def get_status_text(self) -> str:
        sw = self.status_word
        if sw & 0x004F == 0x0000:
            return "Not Ready"
        if sw & 0x004F == 0x0040:
            return "Switch Off"
        if sw & 0x006F == 0x0021:
            return "Ready"
        if sw & 0x006F == 0x0023:
            return "Switched On"
        if sw & 0x006F == 0x0027:
            return "Enabled"
        if sw & 0x004F == 0x0008:
            return "FAULT"
        return f"0x{sw:04X}"

    def is_fault(self) -> bool:
        return (self.status_word & 0x0008) != 0 or self.fault_code != 0
