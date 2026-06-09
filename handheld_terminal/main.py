#!/usr/bin/env python3
"""main.py — 手持终端程序入口（SDL2 渲染 + D-pad 导航）"""

import sys
import os
import struct
import threading
import time
import logging
import signal

opt_site = "/opt/lib/python3.13/site-packages"
if os.path.exists(opt_site) and opt_site not in sys.path:
    sys.path.insert(0, opt_site)

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", datefmt="%H:%M:%S")
log = logging.getLogger("main")

# 按键映射（已验证）
JS_BTN = {0:"B",1:"A",2:"X",3:"Y",4:"L1",5:"R1",6:"L2",7:"R2",8:"Select",9:"Start",13:"Up",14:"Down",15:"Left",16:"Right"}
JS_ACTION = {0:"back",1:"confirm",2:"enable",3:"disable",4:"jog_ccw",5:"jog_cw",6:"estop",7:"r2",8:"l2",9:"menu",13:"up",14:"down",15:"left",16:"right"}

# 颜色 ARGB
C_BG     = 0xFF1A1A2E
C_PANEL  = 0xFF16213E
C_TEXT   = 0xFFFFFFFF
C_DIM    = 0xFFB0B0C0
C_ACCENT = 0xFF00D4AA
C_RED    = 0xFFE74C3C
C_YELLOW = 0xFFF39C12
C_BORDER = 0xFF3A3A5C
C_INPUT  = 0xFF0A0A1E
C_SEL    = 0xFF0F3460  # 选中项背景
C_WHITE  = 0xFFFFFFFF
C_BLACK  = 0xFF000000

# 共享状态
btn_queue = []
current_tab = [0]
selected = [0, 0, 0]  # 每个页面的选中索引
status_msg = [""]
status_time = [0]

def js_reader():
    fmt = 'IhBB'
    size = struct.calcsize(fmt)
    while True:
        try:
            with open('/dev/input/js0', 'rb') as js:
                log.info("js0 opened")
                while True:
                    data = js.read(size)
                    if data and len(data) >= size:
                        ts, val, etype, num = struct.unpack(fmt, data)
                        if etype & 0x7F == 1 and val == 1:
                            btn_queue.append(num)
        except Exception as e:
            log.error(f"js error: {e}")
            time.sleep(1)

def stop_ui():
    import subprocess
    for cmd in [["systemctl","stop","essway.service"],["killall","-9","emulationstation","sway","swaybg"]]:
        try: subprocess.run(cmd, timeout=5)
        except: pass
    time.sleep(1)
    try:
        with open("/sys/class/graphics/fb0/blank","w") as f: f.write("0")
    except: pass

def start_ui():
    import subprocess
    try:
        subprocess.run(["systemctl","unmask","essway.service"], timeout=5)
        subprocess.run(["systemctl","start","essway.service"], timeout=5)
    except: pass

def main():
    from sdl_display import SDLDisplay
    from config import SCREEN_WIDTH as SW, SCREEN_HEIGHT as SH, HEARTBEAT_INTERVAL_MS, DEFAULT_NODE_ID
    from network.udp_client import UDPClient
    from network.protocol import Protocol
    from core.motor_data import MotorData

    stop_ui()
    time.sleep(1)

    display = SDLDisplay(SW, SH)
    try:
        display.init()
        log.info("Display OK")
    except Exception as e:
        log.error(f"Display fail: {e}")
        start_ui()
        return

    threading.Thread(target=js_reader, daemon=True).start()

    udp_client = UDPClient()
    motor_data = MotorData()
    def on_data(raw):
        data = Protocol.parse(raw)
        if data.get("cmd") == "motor_status":
            motor_data.update_from_dict(data)
        elif data.get("cmd") == "sdo_read_result":
            status_msg[0] = f"Read: {data.get('data','?')}"
            status_time[0] = time.time()
        elif data.get("cmd") == "ack":
            s = data.get("status","")
            m = data.get("msg","")
            status_msg[0] = f"{'OK' if s=='ok' else 'ERR'}: {m}"
            status_time[0] = time.time()
    udp_client.set_callbacks(on_data=on_data, on_connection=lambda c: None)
    udp_client.start()

    running = [True]
    def sig_h(s,f): running[0]=False
    signal.signal(signal.SIGINT, sig_h)
    signal.signal(signal.SIGTERM, sig_h)

    log.info("Started")
    last_hb = 0
    tab_names = ["Monitor", "Config", "OTA"]

    # 监控页菜单项
    mon_items = ["Enable", "Disable", "E-STOP", "Jog CW", "Jog CCW"]
    # 配置页菜单项
    cfg_items = [
        ("Mode", 0x6060, 0),
        ("Control Word", 0x6040, 0),
        ("Target Speed", 0x60FF, 0),
        ("Target Torque", 0x6071, 0),
        ("PID Kp", 0x2010, 0),
        ("PID Ki", 0x2011, 0),
        ("PID Kd", 0x2012, 0),
        ("Current Limit", 0x2013, 0),
        ("Save EEPROM", 0x1010, 1),
    ]
    # OTA 页菜单项
    ota_items = ["Load Firmware", "Send to Dongle", "Verify MD5", "Flash Motor"]

    try:
        while running[0] and display.is_running():
            # 处理按键
            while btn_queue:
                btn = btn_queue.pop(0)
                action = JS_ACTION.get(btn)
                tab = current_tab[0]

                if action == "menu":
                    current_tab[0] = (tab + 1) % 3
                    status_msg[0] = f">> {tab_names[current_tab[0]]}"
                    status_time[0] = time.time()

                elif action == "up":
                    selected[tab] = max(0, selected[tab] - 1)
                elif action == "down":
                    max_idx = len(mon_items)-1 if tab==0 else (len(cfg_items)-1 if tab==1 else len(ota_items)-1)
                    selected[tab] = min(max_idx, selected[tab] + 1)

                elif action == "confirm":  # A 按键
                    if tab == 0:  # Monitor
                        sel = selected[0]
                        if sel == 0: udp_client.send(Protocol.enable(DEFAULT_NODE_ID))
                        elif sel == 1: udp_client.send(Protocol.disable(DEFAULT_NODE_ID))
                        elif sel == 2: udp_client.send(Protocol.estop())
                        elif sel == 3: udp_client.send(Protocol.jog_start(DEFAULT_NODE_ID, "cw", 500))
                        elif sel == 4: udp_client.send(Protocol.jog_start(DEFAULT_NODE_ID, "ccw", 500))
                    elif tab == 1:  # Config
                        sel = selected[1]
                        if sel < len(cfg_items):
                            name, idx, sub = cfg_items[sel]
                            if name == "Save EEPROM":
                                udp_client.send(Protocol.sdo_write(DEFAULT_NODE_ID, 0x1010, 1, 0x65766173))
                            else:
                                udp_client.send(Protocol.sdo_read(DEFAULT_NODE_ID, idx, sub))
                    elif tab == 2:  # OTA
                        status_msg[0] = f"OTA: {ota_items[selected[2]]}"
                        status_time[0] = time.time()

                elif action == "back":  # B 按键
                    if tab == 0:
                        udp_client.send(Protocol.jog_stop(DEFAULT_NODE_ID))
                        status_msg[0] = "Jog stopped"
                        status_time[0] = time.time()

                elif action == "enable":  # X
                    udp_client.send(Protocol.enable(DEFAULT_NODE_ID))
                elif action == "disable":  # Y
                    udp_client.send(Protocol.disable(DEFAULT_NODE_ID))
                elif action == "estop":  # L2 / Select
                    udp_client.send(Protocol.estop())
                elif action == "jog_cw":  # R1
                    udp_client.send(Protocol.jog_start(DEFAULT_NODE_ID, "cw", 500))
                elif action == "jog_ccw":  # L1
                    udp_client.send(Protocol.jog_start(DEFAULT_NODE_ID, "ccw", 500))

            # 心跳
            now = time.time()
            if now - last_hb >= HEARTBEAT_INTERVAL_MS / 1000.0:
                udp_client.send(Protocol.heartbeat())
                last_hb = now

            # 绘制
            d = motor_data
            display.fill(C_BG)
            tab = current_tab[0]

            if tab == 0:
                _draw_monitor(display, d, SW, SH, selected[0], mon_items)
            elif tab == 1:
                _draw_config(display, d, SW, SH, selected[1], cfg_items)
            else:
                _draw_ota(display, SW, SH, selected[2], ota_items)

            # Tab 栏
            tw = SW // 3
            for i, name in enumerate(tab_names):
                x = i * tw
                bg = C_ACCENT if i == tab else C_PANEL
                display.draw_rect(x+2, SH-45, tw-4, 30, bg)
                tc = C_BLACK if i == tab else C_DIM
                display.draw_text(name, x+tw//2-30, SH-42, tc, 18)

            # 连接状态
            conn = "Online" if d.alive else "Offline"
            cc = C_ACCENT if d.alive else C_RED
            display.draw_text(conn, SW-90, 6, cc, 14)

            # 状态消息
            if status_msg[0] and time.time() - status_time[0] < 2:
                display.draw_rect(SW//2-130, SH//2-22, 260, 44, C_PANEL)
                display.draw_rect(SW//2-130, SH//2-22, 260, 44, C_BORDER)
                display.draw_text(status_msg[0], SW//2-115, SH//2-12, C_ACCENT, 16)

            # 底部提示
            display.draw_text("[D-pad]Navigate [A]Select [B]Back [Start]Tab", 10, SH-14, (80,80,100), 11)

            display.flip()
            time.sleep(1.0/30)

    except Exception as e:
        log.error(f"Error: {e}")
        import traceback; traceback.print_exc()
    finally:
        udp_client.stop()
        display.quit()
        start_ui()
        log.info("Exit")


def _draw_monitor(display, d, W, H, sel, items):
    # 标题
    display.draw_text("Motor Monitor", 15, 8, C_ACCENT, 20)

    # 左侧：控制按钮列表
    y = 40
    for i, name in enumerate(items):
        is_sel = (i == sel)
        bg = C_SEL if is_sel else C_PANEL
        display.draw_rect(10, y, 190, 36, bg)
        if is_sel:
            display.draw_rect(10, y, 3, 36, C_ACCENT)
        tc = C_ACCENT if is_sel else C_TEXT
        display.draw_text(name, 20, y+8, tc, 16)
        y += 40

    # 参数显示
    y = 40
    params = [
        ("Current", f"{d.current:.2f} A"),
        ("Voltage", f"{d.voltage:.1f} V"),
        ("Speed",   f"{d.speed} rpm"),
        ("Position", f"{d.position:.1f} deg"),
        ("Torque",  f"{d.torque:.2f} Nm"),
        ("Status",  d.get_status_text()),
    ]
    for name, val in params:
        display.draw_rect(210, y, W-220, 26, C_INPUT)
        display.draw_text(name, 215, y+4, C_DIM, 13)
        display.draw_text(val, W-10, y+4, C_ACCENT, 13)
        y += 30

    # 波形区域
    wave_y = y + 15
    wave_h = H - wave_y - 60
    display.draw_rect(210, wave_y, W-220, wave_h, C_INPUT)
    display.draw_rect(210, wave_y, W-220, 2, C_BORDER)
    display.draw_rect(210, wave_y+wave_h-2, W-220, 2, C_BORDER)
    display.draw_text("Current Waveform", 215, wave_y+5, C_DIM, 12)
    _draw_waveform(display, d, 215, wave_y+22, W-230, wave_h-30)

    # 图例
    ly = wave_y + wave_h + 5
    display.draw_rect(215, ly, 10, 6, C_ACCENT)
    display.draw_text("Current(A)", 230, ly-2, C_DIM, 11)


def _draw_waveform(display, d, x, y, w, h):
    n = min(len(d._current_history), 60)
    if n < 2: return
    vals = list(d._current_history)[-n:]
    vmin, vmax = min(vals), max(vals)
    vr = vmax - vmin if vmax != vmin else 1
    step = w / n
    for i, v in enumerate(vals):
        px = x + int(i * step)
        bh = max(int((v - vmin) / vr * h * 0.85), 1)
        display.draw_rect(px, y + h - bh, max(int(step)-1, 2), bh, C_ACCENT)


def _draw_config(display, d, W, H, sel, items):
    display.draw_text("Parameter Config", 15, 8, C_ACCENT, 20)

    y = 40
    for i, (name, idx, sub) in enumerate(items):
        is_sel = (i == sel)
        bg = C_SEL if is_sel else C_PANEL
        display.draw_rect(10, y, W-20, 36, bg)
        if is_sel:
            display.draw_rect(10, y, 3, 36, C_ACCENT)
        tc = C_ACCENT if is_sel else C_TEXT
        display.draw_text(name, 20, y+8, tc, 15)
        # 显示索引
        display.draw_text(f"0x{idx:04X}:{sub}", W-100, y+8, C_DIM, 12)
        y += 40

    # 底部提示
    display.draw_text("[Up/Down]Select [A]Read [Start]Tab", 10, H-60, C_DIM, 12)


def _draw_ota(display, W, H, sel, items):
    display.draw_text("OTA Firmware Update", 15, 8, C_ACCENT, 20)

    # 固件信息
    display.draw_rect(10, 40, W-20, 45, C_PANEL)
    display.draw_text("No firmware loaded", 20, 50, C_TEXT, 14)
    display.draw_text("Use SSH to copy .bin to /storage/", 20, 68, C_DIM, 12)

    # 操作按钮
    y = 100
    for i, name in enumerate(items):
        is_sel = (i == sel)
        bg = C_SEL if is_sel else C_PANEL
        display.draw_rect(10, y, W-20, 36, bg)
        if is_sel:
            display.draw_rect(10, y, 3, 36, C_ACCENT)
        tc = C_ACCENT if is_sel else C_TEXT
        display.draw_text(name, 20, y+8, tc, 15)
        y += 40

    display.draw_text("[Up/Down]Select [A]Execute [Start]Tab", 10, H-60, C_DIM, 12)


if __name__ == "__main__":
    main()
