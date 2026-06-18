"""ota_page.py — OTA 固件升级页面"""

import pygame
import hashlib
import base64
import os
import time
import threading
from config import (
    COLOR_BG, COLOR_PANEL, COLOR_TEXT, COLOR_TEXT_DIM,
    COLOR_ACCENT, COLOR_RED, COLOR_YELLOW, SCREEN_WIDTH, SCREEN_HEIGHT,
    OTA_CHUNK_SIZE, OTA_SEND_INTERVAL
)
from network.protocol import Protocol
from ui.styles import Fonts, draw_rounded_rect, draw_text, draw_button, draw_progress_bar


class OTAPage:
    """OTA 固件升级页面"""

    def __init__(self, udp_client):
        self.udp_client = udp_client
        self._firmware_data = None
        self._firmware_md5 = None
        self._firmware_name = ""
        self._firmware_size = 0
        self._sending = False
        self._progress = 0
        self._speed = 0
        self._state = "idle"  # idle, sending, verifying, done, error
        self._log_lines = []
        self._selected_action = 0  # 0=browse, 1=send, 2=verify, 3=flash

    def _log(self, msg):
        ts = time.strftime("%H:%M:%S")
        self._log_lines.append(f"[{ts}] {msg}")
        if len(self._log_lines) > 8:
            self._log_lines.pop(0)

    def load_firmware(self, path):
        try:
            with open(path, "rb") as f:
                self._firmware_data = f.read()
            self._firmware_md5 = hashlib.md5(self._firmware_data).hexdigest()
            self._firmware_name = os.path.basename(path)
            self._firmware_size = len(self._firmware_data)
            self._log(f"Loaded: {self._firmware_name} ({self._firmware_size // 1024}KB)")
            return True
        except Exception as e:
            self._log(f"Load failed: {e}")
            return False

    def handle_event(self, event, action=None):
        if action == "up":
            self._selected_action = max(0, self._selected_action - 1)
        elif action == "down":
            self._selected_action = min(3, self._selected_action + 1)
        elif action == "confirm":
            if self._selected_action == 0:
                self._log("Use SSH to copy firmware, then set path")
            elif self._selected_action == 1 and self._firmware_data:
                self._start_transfer()
            elif self._selected_action == 2:
                self.udp_client.send(Protocol.ota_verify())
                self._log("Requesting MD5 verify...")
            elif self._selected_action == 3:
                self.udp_client.send(Protocol.ota_flash(1))
                self._log("Flash command sent!")

    def _start_transfer(self):
        if not self._firmware_data:
            return
        self._sending = True
        self._progress = 0
        self._state = "sending"
        self._log("Starting transfer...")
        threading.Thread(target=self._send_thread, daemon=True).start()

    def _send_thread(self):
        total = len(self._firmware_data)
        self.udp_client.send(Protocol.ota_start(total, self._firmware_md5))
        time.sleep(0.1)

        offset = 0
        start = time.time()
        while offset < total and self._sending:
            chunk = self._firmware_data[offset:offset + OTA_CHUNK_SIZE]
            b64 = base64.b64encode(chunk).decode("ascii")
            self.udp_client.send(Protocol.ota_chunk(offset, b64))
            offset += len(chunk)
            elapsed = time.time() - start
            self._progress = int(offset * 100 / total)
            self._speed = (offset / 1024) / elapsed if elapsed > 0 else 0
            time.sleep(OTA_SEND_INTERVAL)

        if self._sending:
            self._state = "verify"
            self._log(f"Transfer done! {self._speed:.1f} KB/s")

    def handle_reply(self, data: dict):
        cmd = data.get("cmd", "")
        if cmd == "ota_status":
            state = data.get("state", "")
            if state == "done":
                self._state = "done"
                self._log("Flash complete!")
            elif state == "error":
                self._state = "error"
                self._log("OTA error!")
        elif cmd == "ack":
            status = data.get("status", "")
            msg = data.get("msg", "")
            self._log(f"{'OK' if status == 'ok' else 'ERR'}: {msg}")
            if "md5" in msg.lower() and "pass" in msg.lower():
                self._state = "ready"

    def draw(self, surface):
        draw_text(surface, "OTA Firmware Update", Fonts.title, COLOR_ACCENT, 20, 15)

        # 固件信息
        y = 55
        draw_rounded_rect(surface, COLOR_PANEL, (15, y, SCREEN_WIDTH - 30, 60), 4)
        name = self._firmware_name or "No firmware loaded"
        draw_text(surface, name, Fonts.normal, COLOR_TEXT, 25, y + 8)
        if self._firmware_data:
            size_kb = self._firmware_size / 1024
            draw_text(surface, f"Size: {size_kb:.1f} KB  MD5: {self._firmware_md5[:16]}...",
                      Fonts.small, COLOR_TEXT_DIM, 25, y + 32)

        # 操作按钮
        y = 130
        actions = ["Load Firmware", "Send to Dongle", "Verify MD5", "Flash Motor"]
        for i, label in enumerate(actions):
            is_sel = (i == self._selected_action)
            bg = COLOR_ACCENT if is_sel else COLOR_PANEL
            tc = (0, 0, 0) if is_sel else COLOR_TEXT
            draw_button(surface, label, 20, y, 280, 38, bg_color=bg, text_color=tc)
            y += 45

        # 进度条
        if self._state == "sending":
            draw_progress_bar(surface, 20, y + 10, SCREEN_WIDTH - 40, 25,
                              self._progress, f"{self._progress}%  {self._speed:.1f} KB/s")
        elif self._state == "verify":
            draw_text(surface, "Verifying...", Fonts.normal, COLOR_YELLOW, 20, y + 15)
        elif self._state == "done":
            draw_text(surface, "Complete!", Fonts.normal, COLOR_ACCENT, 20, y + 15)
        elif self._state == "error":
            draw_text(surface, "Error!", Fonts.normal, COLOR_RED, 20, y + 15)

        # 日志
        log_y = max(y + 50, 400)
        draw_text(surface, "Log:", Fonts.small, COLOR_TEXT_DIM, 20, log_y)
        log_y += 20
        for line in self._log_lines:
            draw_text(surface, line, Fonts.small, COLOR_TEXT, 20, log_y)
            log_y += 18

        # 提示
        hint_y = SCREEN_HEIGHT - 35
        hints = "[D-pad]Select [A]Execute [B]Back"
        draw_text(surface, hints, Fonts.small, COLOR_TEXT_DIM,
                  SCREEN_WIDTH // 2, hint_y, "center")
