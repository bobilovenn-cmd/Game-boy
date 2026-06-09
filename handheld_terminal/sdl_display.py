"""sdl_display.py — SDL2 显示封装（使用系统 SDL2 via ctypes）"""

import ctypes
import ctypes.util
import os
import struct
import time

# SDL2 constants
SDL_INIT_VIDEO = 0x00000020
SDL_INIT_JOYSTICK = 0x00002000
SDL_WINDOW_SHOWN = 0x00000004
SDL_QUIT = 0x100
SDL_KEYDOWN = 0x300
SDL_KEYUP = 0x301
SDL_JOYBUTTONDOWN = 0x603
SDL_JOYBUTTONUP = 0x604
SDL_JOYHATMOTION = 0x602
SDL_JOYAXISMOTION = 0x600

# SDL_Rect structure
class SDL_Rect(ctypes.Structure):
    _fields_ = [
        ('x', ctypes.c_int32),
        ('y', ctypes.c_int32),
        ('w', ctypes.c_int32),
        ('h', ctypes.c_int32),
    ]


class SDLDisplay:
    """SDL2 显示封装"""

    def __init__(self, width=720, height=720):
        self.width = width
        self.height = height
        self._sdl = None
        self._window = None
        self._surface = None
        self._joystick = None
        self._running = False
        self._font_cache = {}

    def init(self):
        os.environ.setdefault('SDL_VIDEODRIVER', 'KMSDRM')
        os.environ.setdefault('XDG_RUNTIME_DIR', '/tmp/runtime-root')

        self._sdl = ctypes.CDLL('/usr/lib/libSDL2-2.0.so.0')

        ret = self._sdl.SDL_Init(SDL_INIT_VIDEO)
        if ret != 0:
            raise RuntimeError(f"SDL_Init failed: {ret}")

        self._sdl.SDL_CreateWindow.restype = ctypes.c_void_p
        self._window = self._sdl.SDL_CreateWindow(
            b'DiagTool', 0, 0, 0, self.width, self.height, SDL_WINDOW_SHOWN
        )
        if not self._window:
            raise RuntimeError("SDL_CreateWindow failed")

        self._update_surface()

        # Open joystick
        self._sdl.SDL_NumJoysticks.restype = ctypes.c_int
        n = self._sdl.SDL_NumJoysticks()
        if n > 0:
            self._sdl.SDL_JoystickOpen.restype = ctypes.c_void_p
            self._joystick = self._sdl.SDL_JoystickOpen(0)
            if self._joystick:
                self._sdl.SDL_JoystickName.restype = ctypes.c_char_p
                name = self._sdl.SDL_JoystickName(self._joystick)
                print(f"Joystick: {name.decode() if name else 'unknown'}")

        # Try to load SDL2_ttf for text rendering
        self._ttf = None
        try:
            self._ttf = ctypes.CDLL('/usr/lib/libSDL2_ttf-2.0.so.0')
            self._ttf.TTF_Init()
            self._ttf.TTF_OpenFont.restype = ctypes.c_void_p
            self._font = self._ttf.TTF_OpenFont(b'/usr/share/fonts/liberation/LiberationMono-Regular.ttf', 28)
            if not self._font:
                # Try any available font
                import glob
                fonts = glob.glob('/usr/share/fonts/**/*.ttf', recursive=True)
                if fonts:
                    self._font = self._ttf.TTF_OpenFont(fonts[0].encode(), 20)
            if self._font:
                print("Font loaded")
            else:
                print("No font found")
                self._ttf = None
        except Exception:
            print("SDL2_ttf not available")

        self._running = True
        self._text_cache = {}  # (text, r, g, b) -> surface pointer

    def _update_surface(self):
        self._sdl.SDL_GetWindowSurface.restype = ctypes.c_void_p
        self._surface = self._sdl.SDL_GetWindowSurface(self._window)

    def fill(self, color):
        """Fill surface with ARGB color"""
        if self._surface:
            self._sdl.SDL_FillRect(self._surface, None, color)

    def flip(self):
        if self._window:
            self._sdl.SDL_UpdateWindowSurface(self._window)

    def draw_rect(self, x, y, w, h, color):
        """Draw a filled rectangle"""
        rect = struct.pack('iiii', x, y, w, h)
        rect_buf = ctypes.create_string_buffer(rect)
        if self._surface:
            self._sdl.SDL_FillRect(self._surface, rect_buf, color)

    def draw_text(self, text, x, y, color=(224, 224, 224), size=20):
        """Draw text using SDL2_ttf. color can be (r,g,b) tuple or ARGB int."""
        if not self._ttf or not self._font:
            return

        if isinstance(color, int):
            r = (color >> 16) & 0xFF
            g = (color >> 8) & 0xFF
            b = color & 0xFF
        else:
            r, g, b = color

        # Check cache
        cache_key = (text, r, g, b)
        text_surf = self._text_cache.get(cache_key)

        if not text_surf:
            sdl_color = struct.pack('BBBB', r, g, b, 255)
            color_buf = ctypes.create_string_buffer(sdl_color)
            self._ttf.TTF_RenderUTF8_Blended.restype = ctypes.c_void_p
            text_surf = self._ttf.TTF_RenderUTF8_Blended(
                self._font, text.encode('utf-8'), color_buf
            )
            if not text_surf:
                return
            self._text_cache[cache_key] = text_surf

        # Blit to window surface
        rect = struct.pack('iiii', x, y, 0, 0)
        rect_buf = ctypes.create_string_buffer(rect)
        self._sdl.SDL_UpperBlit(text_surf, None, self._surface, rect_buf)

    def poll_events(self):
        """Poll SDL events, return list of (type, detail) tuples"""
        events = []
        ev = ctypes.create_string_buffer(56)
        while self._sdl.SDL_PollEvent(ev):
            ev_type = ctypes.c_uint.from_buffer_copy(ev, 0).value
            # Debug: uncomment to see events
            # print(f"SDL event: {ev_type:#x}")
            if ev_type == SDL_QUIT:
                self._running = False
                events.append(('quit', None))
            elif ev_type == SDL_KEYDOWN:
                key = ctypes.c_uint.from_buffer_copy(ev, 16).value
                events.append(('keydown', key))
            elif ev_type == SDL_JOYBUTTONDOWN:
                button = ctypes.c_uint.from_buffer_copy(ev, 4).value
                events.append(('joydown', button))
            elif ev_type == SDL_JOYBUTTONUP:
                button = ctypes.c_uint.from_buffer_copy(ev, 4).value
                events.append(('joyup', button))
            elif ev_type == SDL_JOYHATMOTION:
                hat_val = ctypes.c_int.from_buffer_copy(ev, 8).value
                events.append(('hat', hat_val))
        return events

    def is_running(self):
        return self._running

    def quit(self):
        # Free cached text surfaces
        for surf in self._text_cache.values():
            self._sdl.SDL_FreeSurface(surf)
        self._text_cache.clear()

        if self._ttf and self._font:
            self._ttf.TTF_CloseFont(self._font)
            self._ttf.TTF_Quit()
        if self._joystick:
            self._sdl.SDL_JoystickClose(self._joystick)
        if self._window:
            self._sdl.SDL_DestroyWindow(self._window)
        self._sdl.SDL_Quit()
        self._running = False
