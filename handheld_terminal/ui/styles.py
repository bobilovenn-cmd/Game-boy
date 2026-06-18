"""styles.py — pygame UI 颜色和字体定义"""

import pygame
from config import (
    COLOR_BG, COLOR_PANEL, COLOR_TEXT, COLOR_TEXT_DIM,
    COLOR_ACCENT, COLOR_RED, COLOR_YELLOW, COLOR_BORDER,
    COLOR_INPUT_BG
)


class Fonts:
    """字体管理"""
    _initialized = False
    title = None
    normal = None
    small = None
    value = None
    mono = None

    @classmethod
    def init(cls):
        if cls._initialized:
            return
        pygame.font.init()
        cls.title = pygame.font.SysFont("dejavusansmono", 24, bold=True)
        cls.normal = pygame.font.SysFont("dejavusansmono", 16)
        cls.small = pygame.font.SysFont("dejavusansmono", 13)
        cls.value = pygame.font.SysFont("dejavusansmono", 28, bold=True)
        cls.mono = pygame.font.SysFont("dejavusansmono", 14)
        cls._initialized = True


def draw_rounded_rect(surface, color, rect, radius=6):
    """绘制圆角矩形"""
    x, y, w, h = rect
    pygame.draw.rect(surface, color, (x + radius, y, w - 2 * radius, h))
    pygame.draw.rect(surface, color, (x, y + radius, w, h - 2 * radius))
    pygame.draw.circle(surface, color, (x + radius, y + radius), radius)
    pygame.draw.circle(surface, color, (x + w - radius, y + radius), radius)
    pygame.draw.circle(surface, color, (x + radius, y + h - radius), radius)
    pygame.draw.circle(surface, color, (x + w - radius, y + h - radius), radius)


def draw_text(surface, text, font, color, x, y, anchor="topleft"):
    """绘制文本，支持多种锚点"""
    rendered = font.render(text, True, color)
    rect = rendered.get_rect()
    setattr(rect, anchor, (x, y))
    surface.blit(rendered, rect)
    return rect


def draw_button(surface, text, x, y, w, h, font=None,
                bg_color=COLOR_PANEL, text_color=COLOR_TEXT,
                border_color=COLOR_BORDER, pressed=False):
    """绘制按钮"""
    if font is None:
        font = Fonts.normal
    color = COLOR_ACCENT if pressed else bg_color
    draw_rounded_rect(surface, color, (x, y, w, h))
    pygame.draw.rect(surface, border_color, (x, y, w, h), 1)
    tc = COLOR_BG if pressed else text_color
    draw_text(surface, text, font, tc, x + w // 2, y + h // 2, "center")
    return pygame.Rect(x, y, w, h)


def draw_progress_bar(surface, x, y, w, h, progress, label=""):
    """绘制进度条"""
    draw_rounded_rect(surface, COLOR_INPUT_BG, (x, y, w, h), 3)
    bar_w = int((w - 4) * min(progress, 100) / 100)
    if bar_w > 0:
        draw_rounded_rect(surface, COLOR_ACCENT, (x + 2, y + 2, bar_w, h - 4), 2)
    if label:
        draw_text(surface, label, Fonts.small, COLOR_TEXT, x + w // 2, y + h // 2, "center")
