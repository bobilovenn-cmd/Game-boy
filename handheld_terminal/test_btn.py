#!/usr/bin/env python3
"""test_btn.py — 按键测试"""
import sys, os, struct, time, threading

sys.path.insert(0, '/storage/handheld_terminal')
from sdl_display import SDLDisplay

JS_EVENT_FORMAT = 'IhBB'
JS_EVENT_SIZE = struct.calcsize(JS_EVENT_FORMAT)
btn_pressed = []

def read_buttons():
    with open('/dev/input/js0', 'rb') as js:
        while True:
            data = js.read(JS_EVENT_SIZE)
            if data and len(data) >= JS_EVENT_SIZE:
                ts, val, etype, num = struct.unpack(JS_EVENT_FORMAT, data)
                if etype & 0x7F == 1 and val == 1:
                    btn_pressed.append(num)
                    print(f'Button {num} pressed')

t = threading.Thread(target=read_buttons, daemon=True)
t.start()

display = SDLDisplay(720, 720)
display.init()

for frame in range(300):
    display.fill(0xFF1A1A2E)
    if btn_pressed:
        last = btn_pressed[-1]
        names = {0:'A',1:'B',2:'X',3:'Y',4:'L1',5:'R1',6:'Select',7:'Start'}
        name = names.get(last, f'Btn{last}')
        display.draw_rect(100, 300, 520, 100, 0xFF00D4AA)
        display.draw_text(f'Button: {name}', 200, 330, (0,0,0), 36)
    display.draw_text('Press buttons to test', 150, 200, (224,224,224), 24)
    display.flip()
    time.sleep(1.0/30)

display.quit()
