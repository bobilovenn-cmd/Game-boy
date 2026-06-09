"""monitor_page.py — 电机状态实时监控（波形 + 参数）"""

import pygame
from config import (
    SCREEN_WIDTH, SCREEN_HEIGHT, COLOR_BG, COLOR_PANEL, COLOR_TEXT, COLOR_TEXT_DIM,
    COLOR_ACCENT, COLOR_RED, COLOR_BORDER, COLOR_INPUT_BG,
    COLOR_WAVE_CURRENT, COLOR_WAVE_SPEED, COLOR_WAVE_TORQUE,
    DEFAULT_NODE_ID
)
from core.motor_data import MotorData
from network.protocol import Protocol
from ui.styles import Fonts, draw_rounded_rect, draw_text, draw_button


class MonitorPage:
    """电机监控页面"""

    def __init__(self, udp_client, motor_data: MotorData):
        self.udp_client = udp_client
        self.motor_data = motor_data
        self._jog_cw_pressed = False
        self._jog_ccw_pressed = False

    def handle_event(self, event, action=None):
        if action == "jog_cw":
            self._jog_cw_pressed = True
            self.udp_client.send(Protocol.jog_start(DEFAULT_NODE_ID, "cw", 500))
        elif action == "jog_cw_release":
            self._jog_cw_pressed = False
            self.udp_client.send(Protocol.jog_stop(DEFAULT_NODE_ID))
        elif action == "jog_ccw":
            self._jog_ccw_pressed = True
            self.udp_client.send(Protocol.jog_start(DEFAULT_NODE_ID, "ccw", 500))
        elif action == "jog_ccw_release":
            self._jog_ccw_pressed = False
            self.udp_client.send(Protocol.jog_stop(DEFAULT_NODE_ID))
        elif action == "enable":
            self.udp_client.send(Protocol.enable(DEFAULT_NODE_ID))
        elif action == "disable":
            self.udp_client.send(Protocol.disable(DEFAULT_NODE_ID))
        elif action == "estop":
            self.udp_client.send(Protocol.estop())

        # 鼠标/触摸事件
        if event and event.type == pygame.MOUSEBUTTONDOWN:
            mx, my = event.pos
            # 急停按钮区域
            if 20 <= mx <= 200 and 20 <= my <= 80:
                self.udp_client.send(Protocol.estop())
            # 使能按钮
            elif 20 <= mx <= 105 and 90 <= my <= 130:
                self.udp_client.send(Protocol.enable(DEFAULT_NODE_ID))
            # 去使能按钮
            elif 115 <= mx <= 200 and 90 <= my <= 130:
                self.udp_client.send(Protocol.disable(DEFAULT_NODE_ID))
            # 正转按钮
            elif 115 <= mx <= 200 and 380 <= my <= 430:
                self.udp_client.send(Protocol.jog_start(DEFAULT_NODE_ID, "cw", 500))
            # 反转按钮
            elif 20 <= mx <= 105 and 380 <= my <= 430:
                self.udp_client.send(Protocol.jog_start(DEFAULT_NODE_ID, "ccw", 500))
        elif event and event.type == pygame.MOUSEBUTTONUP:
            self.udp_client.send(Protocol.jog_stop(DEFAULT_NODE_ID))

    def draw(self, surface):
        d = self.motor_data

        # ===== 左侧面板 =====
        # 急停按钮
        draw_button(surface, "E-STOP", 20, 20, 180, 55,
                    Fonts.title, bg_color=COLOR_RED, text_color=(255, 255, 255))

        # 使能/去使能
        draw_button(surface, "Enable", 20, 90, 80, 35,
                    bg_color=COLOR_ACCENT, text_color=(0, 0, 0))
        draw_button(surface, "Disable", 110, 90, 90, 35,
                    bg_color=COLOR_PANEL)

        # 参数显示
        y = 145
        params = [
            ("Current", f"{d.current:.2f}", "A"),
            ("Voltage", f"{d.voltage:.1f}", "V"),
            ("Speed", f"{d.speed}", "rpm"),
            ("Position", f"{d.position:.1f}", "deg"),
            ("Torque", f"{d.torque:.2f}", "Nm"),
            ("Fault", f"0x{d.fault_code:04X}" if d.fault_code else "None", ""),
        ]
        for name, val, unit in params:
            draw_rounded_rect(surface, COLOR_INPUT_BG, (20, y, 180, 30), 3)
            draw_text(surface, name, Fonts.small, COLOR_TEXT_DIM, 25, y + 2)
            draw_text(surface, f"{val} {unit}", Fonts.mono, COLOR_ACCENT, 195, y + 2, "topright")
            y += 35

        # 状态
        status_color = COLOR_RED if d.is_fault() else COLOR_ACCENT
        draw_text(surface, f"Status: {d.get_status_text()}", Fonts.normal,
                  status_color, 20, y + 5)

        # 连接状态
        conn_color = COLOR_ACCENT if d.alive else COLOR_RED
        conn_text = "Online" if d.alive else "Offline"
        draw_text(surface, f"Dongle: {conn_text}", Fonts.normal,
                  conn_color, 20, y + 30)

        # 点动按钮
        draw_text(surface, "Jog Control:", Fonts.small, COLOR_TEXT_DIM, 20, 360)
        draw_button(surface, "<< CCW", 20, 380, 80, 45)
        draw_button(surface, "CW >>", 115, 380, 85, 45)

        # ===== 右侧：波形 =====
        wave_x = 220
        wave_y = 20
        wave_w = SCREEN_WIDTH - wave_x - 15
        wave_h = 350

        # 波形背景
        draw_rounded_rect(surface, COLOR_INPUT_BG, (wave_x, wave_y, wave_w, wave_h), 4)
        pygame.draw.rect(surface, COLOR_BORDER, (wave_x, wave_y, wave_w, wave_h), 1)

        # 绘制波形
        self._draw_waveform(surface, wave_x + 5, wave_y + 5,
                            wave_w - 10, wave_h - 10)

        # 图例
        legend_y = wave_y + wave_h + 10
        legends = [
            ("Current (A)", COLOR_WAVE_CURRENT),
            ("Speed (rpm)", COLOR_WAVE_SPEED),
            ("Torque (Nm)", COLOR_WAVE_TORQUE),
        ]
        lx = wave_x
        for name, color in legends:
            pygame.draw.rect(surface, color, (lx, legend_y, 15, 10))
            draw_text(surface, name, Fonts.small, COLOR_TEXT_DIM, lx + 20, legend_y - 2)
            lx += 150

        # 底部按键提示
        hint_y = SCREEN_HEIGHT - 35
        hints = "[X]Enable [Y]Disable [L1]CCW [R1]CW [SEL]E-Stop"
        draw_text(surface, hints, Fonts.small, COLOR_TEXT_DIM,
                  SCREEN_WIDTH // 2, hint_y, "center")

    def _draw_waveform(self, surface, x, y, w, h):
        """绘制实时波形"""
        curves = [
            ("current", COLOR_WAVE_CURRENT),
            ("speed", COLOR_WAVE_SPEED),
            ("torque", COLOR_WAVE_TORQUE),
        ]

        for param, color in curves:
            xs, ys = self.motor_data.get_waveform_data(param)
            if len(xs) < 2:
                continue

            # 归一化到显示范围
            y_min = min(ys) if ys else 0
            y_max = max(ys) if ys else 1
            y_range = y_max - y_min if y_max != y_min else 1

            # 时间窗口：显示最近 N 个点
            n = len(xs)
            points = []
            for i in range(n):
                px = x + int(i * w / max(n - 1, 1))
                py = y + h - int((ys[i] - y_min) / y_range * h)
                points.append((px, py))

            if len(points) >= 2:
                pygame.draw.lines(surface, color, False, points, 2)
