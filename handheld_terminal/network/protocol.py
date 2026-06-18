"""protocol.py — 母机与子机之间的 JSON 协议封装"""

import json
import time
from typing import Optional, Dict, Any


class Protocol:
    _seq_counter = 0

    @classmethod
    def _next_seq(cls) -> int:
        cls._seq_counter += 1
        return cls._seq_counter

    @staticmethod
    def _build(cmd: str, payload: Optional[Dict] = None) -> str:
        msg = {
            "cmd": cmd,
            "seq": Protocol._next_seq(),
            "ts": int(time.time()),
        }
        if payload:
            msg["payload"] = payload
        return json.dumps(msg, separators=(",", ":"))

    @staticmethod
    def heartbeat() -> str:
        return Protocol._build("heartbeat")

    @staticmethod
    def sdo_read(node: int, index: int, sub: int = 0) -> str:
        return Protocol._build("sdo_read", {
            "node": node, "index": index, "sub": sub
        })

    @staticmethod
    def sdo_write(node: int, index: int, sub: int, data: int) -> str:
        return Protocol._build("sdo_write", {
            "node": node, "index": index, "sub": sub, "data": data
        })

    @staticmethod
    def enable(node: int) -> str:
        return Protocol._build("enable", {"node": node})

    @staticmethod
    def disable(node: int) -> str:
        return Protocol._build("disable", {"node": node})

    @staticmethod
    def estop() -> str:
        return Protocol._build("estop")

    @staticmethod
    def jog_start(node: int, direction: str = "cw", speed: int = 500) -> str:
        return Protocol._build("jog_start", {
            "node": node, "direction": direction, "speed": speed
        })

    @staticmethod
    def jog_stop(node: int) -> str:
        return Protocol._build("jog_stop", {"node": node})

    @staticmethod
    def ota_start(size: int, md5: str) -> str:
        return Protocol._build("ota_start", {"size": size, "md5": md5})

    @staticmethod
    def ota_chunk(offset: int, data_b64: str) -> str:
        return Protocol._build("ota_chunk", {
            "offset": offset, "data": data_b64
        })

    @staticmethod
    def ota_verify() -> str:
        return Protocol._build("ota_verify")

    @staticmethod
    def ota_flash(node: int = 1) -> str:
        return Protocol._build("ota_flash", {"node": node})

    @staticmethod
    def parse(data: str) -> Dict[str, Any]:
        try:
            return json.loads(data)
        except json.JSONDecodeError:
            return {"cmd": "unknown", "error": "json_parse_failed"}
