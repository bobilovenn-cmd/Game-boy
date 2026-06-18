"""config_page.py — 电机参数配置页"""

import pygame
from config import COLOR_BG, COLOR_PANEL, COLOR_TEXT, COLOR_TEXT_DIM, COLOR_ACCENT, DEFAULT_NODE_ID, SCREEN_WIDTH, SCREEN_HEIGHT
from network.protocol import Protocol
from ui.styles import Fonts, draw_rounded_rect, draw_text, draw_button

OD_ITEMS = [
    ("Mode (0x6060)", 0x6060, 0, "1=PP 3=PV 4=PT"),
    ("Control Word (0x6040)", 0x6040, 0, "CiA 402"),
    ("Target Speed (0x60FF)", 0x60FF, 0, "rpm"),
    ("Target Torque (0x6071)", 0x6071, 0, "permille"),
    ("PID Kp (0x2010)", 0x2010, 0, "proportional"),
    ("PID Ki (0x2011)", 0x2011, 0, "integral"),
    ("PID Kd (0x2012)", 0x2012, 0, "derivative"),
    ("Current Limit (0x2013)", 0x2013, 0, "amps"),
]


class ConfigPage:
    """参数配置页面"""

    def __init__(self, udp_client):
        self.udp_client = udp_client
        self._selected_row = 0
        self._input_text = ""
        self._input_active = False
        self._result = ""
        self._scroll_offset = 0

    def handle_event(self, event, action=None):
        if action == "up":
            self._selected_row = max(0, self._selected_row - 1)
        elif action == "down":
            self._selected_row = min(len(OD_ITEMS) - 1, self._selected_row + 1)
        elif action == "confirm":
            # 读取选中的参数
            name, index, sub, hint = OD_ITEMS[self._selected_row]
            self.udp_client.send(Protocol.sdo_read(DEFAULT_NODE_ID, index, sub))
            self._result = f"Reading 0x{index:04X}..."
        elif action == "back":
            self._input_active = False
            self._input_text = ""

        # 键盘输入
        if event and event.type == pygame.KEYDOWN:
            if event.key == pygame.K_RETURN and self._input_text:
                # 写入当前值
                try:
                    value = int(self._input_text, 0)
                    name, index, sub, hint = OD_ITEMS[self._selected_row]
                    self.udp_client.send(
                        Protocol.sdo_write(DEFAULT_NODE_ID, index, sub, value)
                    )
                    self._result = f"Write 0x{index:04X} = {value}"
                    self._input_text = ""
                except ValueError:
                    self._result = "Invalid value"
            elif event.key == pygame.K_BACKSPACE:
                self._input_text = self._input_text[:-1]
            elif event.unicode and len(self._input_text) < 16:
                self._input_text += event.unicode

    def handle_reply(self, data: dict):
        if data.get("cmd") == "sdo_read_result":
            index = data.get("index")
            result = data.get("data", "")
            try:
                val = int(result, 16)
                self._result = f"0x{index:04X} = 0x{result} ({val})"
            except ValueError:
                self._result = f"0x{index:04X} = 0x{result}"
        elif data.get("cmd") == "ack":
            status = data.get("status", "")
            msg = data.get("msg", "")
            self._result = "OK" if status == "ok" else f"Error: {msg}"

    def draw(self, surface):
        draw_text(surface, "Parameter Config", Fonts.title, COLOR_ACCENT, 20, 15)

        # 参数列表
        y = 55
        visible = min(len(OD_ITEMS), 8)
        for i in range(visible):
            idx = i + self._scroll_offset
            if idx >= len(OD_ITEMS):
                break
            name, index, sub, hint = OD_ITEMS[idx]

            # 选中高亮
            is_selected = (idx == self._selected_row)
            bg = COLOR_ACCENT if is_selected else COLOR_PANEL
            tc = (0, 0, 0) if is_selected else COLOR_TEXT

            draw_rounded_rect(surface, bg, (15, y, SCREEN_WIDTH - 30, 38), 4)
            draw_text(surface, name, Fonts.normal, tc, 25, y + 5)
            draw_text(surface, hint, Fonts.small,
                      (0, 0, 0) if is_selected else COLOR_TEXT_DIM,
                      25, y + 22)

            # Read/Write 按钮提示
            if is_selected:
                draw_text(surface, "[A]Read [Enter]Write", Fonts.small,
                          (0, 0, 0), SCREEN_WIDTH - 40, y + 10, "topright")
            y += 42

        # 输入框
        input_y = y + 15
        draw_text(surface, "Value:", Fonts.normal, COLOR_TEXT_DIM, 20, input_y)
        draw_rounded_rect(surface, (10, 10, 30), (80, input_y, 200, 28), 3)
        draw_text(surface, self._input_text + "_", Fonts.mono, COLOR_ACCENT,
                  85, input_y + 3)

        # 写入保存按钮
        draw_button(surface, "Save to EEPROM", 20, input_y + 40, 180, 35,
                    bg_color=COLOR_PANEL)

        # 结果显示
        if self._result:
            draw_text(surface, self._result, Fonts.mono, COLOR_ACCENT,
                      20, input_y + 85)

        # 按键提示
        hint_y = SCREEN_HEIGHT - 35
        hints = "[D-pad]Navigate [A]Read [Enter]Write [B]Back"
        draw_text(surface, hints, Fonts.small, COLOR_TEXT_DIM,
                  SCREEN_WIDTH // 2, hint_y, "center")
