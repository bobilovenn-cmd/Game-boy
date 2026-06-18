# config.py — 全局配置

# ===== 网络配置 =====
DONGLE_IP = "192.168.31.126"
DONGLE_UDP_PORT = 5000
LOCAL_UDP_PORT = 5001

# ===== 心跳配置 =====
HEARTBEAT_INTERVAL_MS = 150

# ===== CANopen 默认配置 =====
DEFAULT_NODE_ID = 2
CAN_BAUDRATE = 1000000

# ===== OTA 配置 =====
OTA_CHUNK_SIZE = 512
OTA_SEND_INTERVAL = 0.01

# ===== UI 配置（RGB30 720x720）=====
SCREEN_WIDTH = 720
SCREEN_HEIGHT = 720
FPS = 30
WAVEFORM_HISTORY = 200

# ===== 颜色主题 =====
COLOR_BG = (26, 26, 46)
COLOR_PANEL = (22, 33, 62)
COLOR_TEXT = (224, 224, 224)
COLOR_TEXT_DIM = (160, 160, 176)
COLOR_ACCENT = (0, 212, 170)
COLOR_ACCENT_DIM = (0, 150, 120)
COLOR_RED = (231, 76, 60)
COLOR_RED_DARK = (192, 57, 43)
COLOR_YELLOW = (243, 156, 18)
COLOR_BORDER = (58, 58, 92)
COLOR_INPUT_BG = (10, 10, 30)
COLOR_WAVE_CURRENT = (0, 212, 170)
COLOR_WAVE_SPEED = (243, 156, 18)
COLOR_WAVE_TORQUE = (231, 76, 60)

# ===== 按键映射（evdev scancode）=====
# RGB30 retrogame_joypad 按键码，需要根据实际 evtest 结果调整
BTN_A = 304        # A按钮
BTN_B = 305        # B按钮
BTN_X = 307        # X按钮
BTN_Y = 308        # Y按钮
BTN_L1 = 310       # L1
BTN_R1 = 311       # R1
BTN_L2 = 312       # L2
BTN_R2 = 313       # R2
BTN_SELECT = 314   # Select
BTN_START = 315    # Start
BTN_DPAD_UP = 103  # D-pad Up
BTN_DPAD_DOWN = 108  # D-pad Down
BTN_DPAD_LEFT = 105  # D-pad Left
BTN_DPAD_RIGHT = 106  # D-pad Right

# 按键功能映射
BTN_MAP = {
    BTN_A: "confirm",
    BTN_B: "back",
    BTN_X: "enable",
    BTN_Y: "disable",
    BTN_L1: "jog_ccw",
    BTN_R1: "jog_cw",
    BTN_SELECT: "estop",
    BTN_START: "menu",
    BTN_DPAD_UP: "up",
    BTN_DPAD_DOWN: "down",
    BTN_DPAD_LEFT: "left",
    BTN_DPAD_RIGHT: "right",
}

# ===== 默认 WiFi 配置 =====
DONGLE_SSID = "CAN_Dongle_01"
DONGLE_PASSWORD = "C@nDongle2024"
