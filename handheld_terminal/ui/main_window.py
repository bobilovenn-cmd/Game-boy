"""main_window.py — 主窗口，整合所有页面"""

import pygame
from config import (
    SCREEN_WIDTH, SCREEN_HEIGHT, HEARTBEAT_INTERVAL_MS,
    COLOR_BG, COLOR_PANEL, COLOR_TEXT, COLOR_TEXT_DIM, COLOR_ACCENT, COLOR_BORDER,
    COLOR_RED, DEFAULT_NODE_ID
)
from network.udp_client import UDPClient
from network.protocol import Protocol
from core.motor_data import MotorData
from core.button_handler import ButtonHandler
from ui.monitor_page import MonitorPage
from ui.config_page import ConfigPage
from ui.ota_page import OTAPage
from ui.styles import Fonts, draw_text, draw_rounded_rect


class MainWindow:
    """主窗口"""

    TABS = ["Monitor", "Config", "OTA"]

    def __init__(self):
        self.screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
        pygame.display.set_caption("AGV Motor Diagnostic Tool")
        Fonts.init()

        self.udp_client = UDPClient()
        self.motor_data = MotorData()
        self.button_handler = ButtonHandler()

        self.monitor_page = MonitorPage(self.udp_client, self.motor_data)
        self.config_page = ConfigPage(self.udp_client)
        self.ota_page = OTAPage(self.udp_client)

        self._pages = [self.monitor_page, self.config_page, self.ota_page]
        self._current_tab = 0
        self._last_heartbeat = 0
        self._connected = False

        # 设置回调
        self.udp_client.set_callbacks(
            on_data=self._on_data_received,
            on_connection=self._on_connection_changed
        )
        self.button_handler.set_callback(self._on_button)

        # 启动通信
        self.udp_client.start()
        self.button_handler.start()

    def _on_data_received(self, raw: str):
        data = Protocol.parse(raw)
        cmd = data.get("cmd", "")
        if cmd == "motor_status":
            self.motor_data.update_from_dict(data)
        elif cmd == "sdo_read_result":
            self.config_page.handle_reply(data)
        elif cmd == "ota_status":
            self.ota_page.handle_reply(data)
        elif cmd == "ack":
            page = self._pages[self._current_tab]
            if hasattr(page, "handle_reply"):
                page.handle_reply(data)

    def _on_connection_changed(self, connected: bool):
        self._connected = connected

    def _on_button(self, action: str):
        if action == "menu":
            self._current_tab = (self._current_tab + 1) % len(self.TABS)
            return
        if action == "back":
            self._current_tab = max(0, self._current_tab - 1)
            return

        # 转发给当前页面
        page = self._pages[self._current_tab]
        if hasattr(page, "handle_event"):
            page.handle_event(None, action=action)

    def handle_event(self, event):
        """处理 pygame 事件"""
        if event.type == pygame.QUIT:
            return False

        # Tab 切换：L/R 按键或数字键
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_TAB:
                self._current_tab = (self._current_tab + 1) % len(self.TABS)
                return True
            if event.key == pygame.K_ESCAPE:
                return False

        # 手柄事件
        self.button_handler.process_pygame_event(event)

        # 传递给当前页面
        page = self._pages[self._current_tab]
        if hasattr(page, "handle_event"):
            page.handle_event(event)

        return True

    def update(self):
        """周期更新（心跳等）"""
        now = pygame.time.get_ticks()
        if now - self._last_heartbeat >= HEARTBEAT_INTERVAL_MS:
            self.udp_client.send(Protocol.heartbeat())
            self._last_heartbeat = now

    def draw(self):
        """绘制界面"""
        self.screen.fill(COLOR_BG)

        # 绘制当前页面
        page = self._pages[self._current_tab]
        page.draw(self.screen)

        # 顶部 Tab 栏
        tab_y = SCREEN_HEIGHT - 55
        tab_w = SCREEN_WIDTH // len(self.TABS)
        for i, name in enumerate(self.TABS):
            x = i * tab_w
            is_active = (i == self._current_tab)
            bg = COLOR_ACCENT if is_active else COLOR_PANEL
            tc = (0, 0, 0) if is_active else COLOR_TEXT_DIM
            draw_rounded_rect(self.screen, bg, (x + 2, tab_y, tab_w - 4, 30), 4)
            draw_text(self.screen, name, Fonts.normal, tc,
                      x + tab_w // 2, tab_y + 6, "center")

        # 顶部状态栏
        conn_text = "Connected" if self._connected else "No Link"
        conn_color = COLOR_ACCENT if self._connected else COLOR_RED
        draw_text(self.screen, conn_text, Fonts.small, conn_color,
                  SCREEN_WIDTH - 10, 5, "topright")

        hb_text = f"HB:{HEARTBEAT_INTERVAL_MS}ms"
        draw_text(self.screen, hb_text, Fonts.small, COLOR_TEXT_DIM,
                  SCREEN_WIDTH - 10, 20, "topright")

        pygame.display.flip()

    def cleanup(self):
        self.button_handler.stop()
        self.udp_client.stop()
