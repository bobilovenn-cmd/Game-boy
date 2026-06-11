#!/usr/bin/env python3
"""
Mock ESP32 CAN Dongle Server
Simulates motor telemetry and responds to SDO/control commands over UDP.
Includes a web dashboard with real-time auto-refreshing motor data.
"""
import json
import socket
import threading
import time
import random
import math
from flask import Flask, render_template_string, jsonify, request

# ---------- Config ----------
UDP_PORT = 5000
WEB_PORT = 8080
HEARTBEAT_INTERVAL = 0.15
MOTOR_STATUS_INTERVAL = 0.1

# ---------- Fake Motor State ----------
motor = {
    "current": 0.0,
    "voltage": 24.0,
    "speed": 0,
    "position": 0.0,
    "torque": 0.0,
    "status_word": 0x0027,
    "fault_code": 0,
    "mode": 8,
    "alive": True,
    "wdg_ms": 0,
}
motor_enabled = True
motor_direction = 0
motor_target_speed = 500
motor_mode = 8
pid_kp, pid_ki, pid_kd = 100, 10, 1
current_limit = 10.0

# ---------- Command Log ----------
cmd_log = []
MAX_LOG = 200

# ---------- HTML Template ----------
HTML = """
<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Mock Motor Dashboard</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: -apple-system, monospace; background: #04080e; color: #eaf7fc; padding: 20px; }
  h1 { color: #00e2bc; margin-bottom: 8px; }
  .sub { color: #b2d6e0; font-size: 14px; margin-bottom: 20px; }
  .grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; margin-bottom: 20px; }
  .card { background: #0d1d2b; border: 1px solid #2a5c6e; border-radius: 6px; padding: 14px; }
  .card .label { color: #b2d6e0; font-size: 12px; text-transform: uppercase; }
  .card .value { font-size: 28px; font-weight: bold; margin-top: 4px; }
  .card .unit { font-size: 14px; color: #91b8c4; }
  .green { color: #4bff9c; }
  .blue { color: #389eff; }
  .yellow { color: #ffb84d; }
  .red { color: #ff485c; }
  .cyan { color: #00e2bc; }
  .controls { display: grid; grid-template-columns: repeat(2, 1fr); gap: 12px; margin-bottom: 20px; }
  .control-group { background: #0d1d2b; border: 1px solid #2a5c6e; border-radius: 6px; padding: 14px; }
  .control-group h3 { color: #00e2bc; margin-bottom: 10px; font-size: 14px; }
  .btn { padding: 8px 16px; border: none; border-radius: 4px; cursor: pointer; font-weight: bold; font-size: 13px; margin: 3px; }
  .btn-enable { background: #4bff9c; color: #04080e; }
  .btn-disable { background: #ffb84d; color: #04080e; }
  .btn-estop { background: #ff485c; color: #fff; }
  .btn-cw { background: #389eff; color: #fff; }
  .btn-ccw { background: #00e2bc; color: #04080e; }
  .btn-stop { background: #b2d6e0; color: #04080e; }
  .slider-group { margin: 8px 0; }
  .slider-group label { font-size: 12px; color: #91b8c4; display: block; }
  .slider-group input { width: 100%; margin-top: 4px; }
  .log { background: #030c14; border: 1px solid #2a5c6e; border-radius: 6px; padding: 12px; max-height: 300px; overflow-y: auto; }
  .log .entry { font-size: 12px; padding: 3px 0; border-bottom: 1px solid #0d1d2b; font-family: monospace; }
  .cmd { color: #389eff; }
  .resp { color: #4bff9c; }
  .status { color: #ffb84d; }
  .error { color: #ff485c; }
</style>
</head>
<body>
<h1>Mock ESP32 CAN Dongle</h1>
<p class="sub" id="status_bar">UDP :{{udp_port}} | Web :{{web_port}} | Motor ENABLED | Mode: 8</p>

<div class="grid">
  <div class="card">
    <div class="label">Current</div>
    <div class="value cyan" id="val_current">0.00 <span class="unit">A</span></div>
  </div>
  <div class="card">
    <div class="label">Voltage</div>
    <div class="value blue" id="val_voltage">24.0 <span class="unit">V</span></div>
  </div>
  <div class="card">
    <div class="label">Speed</div>
    <div class="value yellow" id="val_speed">0 <span class="unit">rpm</span></div>
  </div>
  <div class="card">
    <div class="label">Position</div>
    <div class="value" id="val_position">0.0 <span class="unit">°</span></div>
  </div>
  <div class="card">
    <div class="label">Torque</div>
    <div class="value green" id="val_torque">0.00 <span class="unit">Nm</span></div>
  </div>
  <div class="card">
    <div class="label">Status Word</div>
    <div class="value green" id="val_status">0x0027</div>
  </div>
</div>

<div class="controls">
  <div class="control-group">
    <h3>Motor Control</h3>
    <button class="btn btn-enable" onclick="sendCmd('enable')">Enable</button>
    <button class="btn btn-disable" onclick="sendCmd('disable')">Disable</button>
    <button class="btn btn-estop" onclick="sendCmd('estop')">E-STOP</button>
    <button class="btn btn-cw" onclick="sendCmd('jog_cw')">Jog CW</button>
    <button class="btn btn-ccw" onclick="sendCmd('jog_ccw')">Jog CCW</button>
    <button class="btn btn-stop" onclick="sendCmd('jog_stop')">Jog Stop</button>
  </div>
  <div class="control-group">
    <h3>Parameters</h3>
    <div class="slider-group">
      <label>Target Speed: <span id="speed_val">500</span> rpm</label>
      <input type="range" min="0" max="3000" value="500" oninput="setParam('target_speed', this.value)">
    </div>
    <div class="slider-group">
      <label>Voltage: <span id="voltage_val">24.0</span> V</label>
      <input type="range" min="0" max="48" value="24.0" step="0.1" oninput="setParam('voltage', this.value)">
    </div>
    <div class="slider-group">
      <label>Current Limit: <span id="cl_val">10.0</span> A</label>
      <input type="range" min="0" max="20" value="10.0" step="0.1" oninput="setParam('current_limit', this.value)">
    </div>
    <div class="slider-group">
      <label>Simulated Load: <span id="load_val">30</span>%</label>
      <input type="range" min="0" max="100" value="30" oninput="setParam('load', this.value)">
    </div>
  </div>
</div>

<div class="log" id="log_container"></div>

<script>
function sendCmd(cmd) {
  fetch('/api/cmd/' + cmd).then(r => r.json()).then(() => refresh());
}
function setParam(k, v) {
  fetch('/api/set?k=' + k + '&v=' + v).then(() => {
    document.getElementById(k + '_val').textContent = v;
  });
}
function refresh() {
  fetch('/api/state').then(r => r.json()).then(s => {
    var m = s.motor;
    document.getElementById('val_current').innerHTML = m.current.toFixed(2) + ' <span class="unit">A</span>';
    document.getElementById('val_voltage').innerHTML = m.voltage.toFixed(1) + ' <span class="unit">V</span>';
    document.getElementById('val_speed').innerHTML = m.speed + ' <span class="unit">rpm</span>';
    document.getElementById('val_position').innerHTML = m.position.toFixed(1) + ' <span class="unit">&deg;</span>';
    document.getElementById('val_torque').innerHTML = m.torque.toFixed(2) + ' <span class="unit">Nm</span>';
    var swEl = document.getElementById('val_status');
    swEl.innerHTML = '0x' + m.status_word.toString(16).toUpperCase().padStart(4, '0');
    swEl.className = 'value ' + (m.status_word === 0x27 ? 'green' : 'red');

    document.getElementById('status_bar').textContent =
      'UDP :5000 | Web :8080 | Motor ' + (s.enabled ? 'ENABLED' : 'DISABLED') + ' | Mode: ' + s.mode;

    var logHtml = '';
    var entries = s.log.slice(-50).reverse();
    for (var i = 0; i < entries.length; i++) {
      logHtml += '<div class="entry ' + entries[i].type + '">[' + entries[i].ts + '] ' + entries[i].msg + '</div>';
    }
    document.getElementById('log_container').innerHTML = logHtml;
  });
}
setInterval(refresh, 500);
refresh();
</script>
</body>
</html>
"""

# ---------- Flask App ----------
app = Flask(__name__)

@app.route('/')
def index():
    return render_template_string(HTML,
        udp_port=UDP_PORT, web_port=WEB_PORT)

@app.route('/api/state')
def api_state():
    return jsonify(motor=motor, enabled=motor_enabled,
                   mode=motor_mode, target_speed=motor_target_speed,
                   current_limit=current_limit, log=cmd_log[-50:])

@app.route('/api/cmd/<cmd>')
def api_cmd(cmd):
    handle_mock_command(cmd)
    return jsonify(ok=True, cmd=cmd)

@app.route('/api/set')
def api_set():
    global motor_target_speed, current_limit, load_pct
    k = request.args.get('k', '')
    v = float(request.args.get('v', 0))
    if k == 'target_speed': motor_target_speed = int(v)
    elif k == 'voltage': motor['voltage'] = v
    elif k == 'current_limit': current_limit = v
    elif k == 'load': load_pct = int(v)
    return jsonify(ok=True)

# ---------- UDP Server ----------
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.bind(('0.0.0.0', UDP_PORT))
sock.settimeout(0.01)

clients = {}
load_pct = 30

def handle_mock_command(cmd):
    global motor_enabled, motor_direction, motor_target_speed
    if cmd == 'enable':
        motor_enabled = True
        motor['status_word'] = 0x0027
        motor['fault_code'] = 0
        add_log('cmd', 'Motor ENABLED')
    elif cmd == 'disable':
        motor_enabled = False
        motor_direction = 0
        motor['status_word'] = 0x0021
        motor['speed'] = 0
        add_log('cmd', 'Motor DISABLED')
    elif cmd == 'estop':
        motor_enabled = False
        motor_direction = 0
        motor['status_word'] = 0x0008
        motor['fault_code'] = 1
        motor['speed'] = 0
        motor['current'] = 0
        add_log('error', 'E-STOP activated')
    elif cmd == 'jog_cw':
        if motor_enabled:
            motor_direction = 1
            add_log('cmd', 'Jog CW @ {}rpm'.format(motor_target_speed))
    elif cmd == 'jog_ccw':
        if motor_enabled:
            motor_direction = -1
            add_log('cmd', 'Jog CCW @ {}rpm'.format(motor_target_speed))
    elif cmd == 'jog_stop':
        motor_direction = 0
        motor['speed'] = 0
        add_log('cmd', 'Jog STOPPED')

def add_log(typ, msg):
    cmd_log.append({'ts': time.strftime('%H:%M:%S'), 'type': typ, 'msg': msg})
    if len(cmd_log) > MAX_LOG:
        cmd_log.pop(0)

def update_motor(dt):
    speed = motor['speed']
    if motor_enabled and motor_direction != 0:
        target = motor_target_speed * motor_direction
        speed += (target - speed) * 0.1 * dt * 10
        noise = random.gauss(0, motor_target_speed * 0.02)
        speed += noise
        motor['speed'] = int(speed)
        motor['current'] = abs(speed) / motor_target_speed * current_limit * 0.5 + abs(random.gauss(0, 0.1))
        motor['torque'] = motor['current'] * 0.05 + random.gauss(0, 0.01)
        motor['position'] = (motor['position'] + speed * dt / 60.0 * 360.0) % 360.0
    else:
        motor['speed'] = int(random.gauss(0, 8))
        motor['current'] = abs(random.gauss(0.25, 0.12))
        motor['torque'] = abs(random.gauss(0.03, 0.02))
        motor['position'] = (motor['position'] + random.gauss(0, 0.15)) % 360.0

    motor['voltage'] += random.gauss(0, 0.1)
    motor['voltage'] = max(23.5, min(24.5, motor['voltage']))
    motor['wdg_ms'] = int((time.time() * 1000) % 500)

def handle_udp_message(data_str, addr):
    clients[addr] = time.time()
    try:
        msg = json.loads(data_str)
    except:
        return

    cmd = msg.get('cmd', '')
    payload = msg.get('payload', {})
    node = payload.get('node', 1)

    if cmd == 'heartbeat':
        resp = {'cmd': 'ack', 'seq': msg.get('seq', 0), 'ts': int(time.time()),
                'payload': {'status': 'ok', 'msg': 'alive', 'node': node}}
        sock.sendto(json.dumps(resp).encode(), addr)
        return

    if cmd == 'enable':
        handle_mock_command('enable')
        resp = {'cmd': 'ack', 'seq': msg.get('seq', 0), 'ts': int(time.time()),
                'payload': {'status': 'ok', 'msg': 'motor enabled', 'node': node}}
        sock.sendto(json.dumps(resp).encode(), addr)
    elif cmd == 'disable':
        handle_mock_command('disable')
        resp = {'cmd': 'ack', 'seq': msg.get('seq', 0), 'ts': int(time.time()),
                'payload': {'status': 'ok', 'msg': 'motor disabled', 'node': node}}
        sock.sendto(json.dumps(resp).encode(), addr)
    elif cmd == 'estop':
        handle_mock_command('estop')
        resp = {'cmd': 'ack', 'seq': msg.get('seq', 0), 'ts': int(time.time()),
                'payload': {'status': 'ok', 'msg': 'estop activated', 'node': node}}
        sock.sendto(json.dumps(resp).encode(), addr)
    elif cmd == 'jog_start':
        direction = payload.get('direction', 'cw')
        motor_target_speed = payload.get('speed', 500)
        handle_mock_command('jog_cw' if direction == 'cw' else 'jog_ccw')
        resp = {'cmd': 'ack', 'seq': msg.get('seq', 0), 'ts': int(time.time()),
                'payload': {'status': 'ok', 'msg': 'jog {}'.format(direction), 'node': node}}
        sock.sendto(json.dumps(resp).encode(), addr)
    elif cmd == 'jog_stop':
        handle_mock_command('jog_stop')
        resp = {'cmd': 'ack', 'seq': msg.get('seq', 0), 'ts': int(time.time()),
                'payload': {'status': 'ok', 'msg': 'jog stopped', 'node': node}}
        sock.sendto(json.dumps(resp).encode(), addr)
    elif cmd == 'sdo_read':
        index = payload.get('index', 0)
        sub = payload.get('sub', 0)
        sdo_values = {
            0x6060: motor_mode,
            0x6040: 0x000F if motor_enabled else 0x0006,
            0x60FF: motor_target_speed,
            0x6071: int(motor['torque'] * 1000),
            0x2010: pid_kp,
            0x2011: pid_ki,
            0x2012: pid_kd,
            0x2013: int(current_limit * 1000),
        }
        val = sdo_values.get(index, 0)
        resp = {'cmd': 'sdo_read_result', 'seq': msg.get('seq', 0), 'ts': int(time.time()),
                'payload': {'index': index, 'sub': sub, 'data': '{:X}'.format(val), 'node': node}}
        sock.sendto(json.dumps(resp).encode(), addr)
        add_log('resp', 'SDO Read 0x{:04X}:{} = 0x{:X}'.format(index, sub, val))
    elif cmd == 'sdo_write':
        index = payload.get('index', 0)
        data = payload.get('data', 0)
        if index == 0x60FF:
            motor_target_speed = int(data)
        elif index == 0x2010:
            pid_kp = int(data)
        elif index == 0x2011:
            pid_ki = int(data)
        elif index == 0x2012:
            pid_kd = int(data)
        elif index == 0x2013:
            current_limit = float(data) / 1000.0
        resp = {'cmd': 'ack', 'seq': msg.get('seq', 0), 'ts': int(time.time()),
                'payload': {'status': 'ok', 'msg': 'sdo write 0x{:04X}'.format(index), 'node': node}}
        sock.sendto(json.dumps(resp).encode(), addr)
        add_log('cmd', 'SDO Write 0x{:04X} = {}'.format(index, data))
    elif cmd == 'ota_start':
        add_log('cmd', 'OTA start: size={}, md5={}'.format(payload.get('size', 0), payload.get('md5', '')[:16]))
        resp = {'cmd': 'ota_status', 'seq': msg.get('seq', 0), 'ts': int(time.time()),
                'payload': {'state': 'ready', 'msg': 'ready for OTA'}}
        sock.sendto(json.dumps(resp).encode(), addr)
    elif cmd == 'ota_chunk':
        add_log('resp', 'OTA chunk offset={}'.format(payload.get('offset', 0)))
    elif cmd == 'ota_verify':
        add_log('cmd', 'OTA verify requested')
        resp = {'cmd': 'ota_status', 'seq': msg.get('seq', 0), 'ts': int(time.time()),
                'payload': {'state': 'done', 'msg': 'MD5 verified OK'}}
        sock.sendto(json.dumps(resp).encode(), addr)
    elif cmd == 'ota_flash':
        add_log('cmd', 'OTA flash command received')
        resp = {'cmd': 'ota_status', 'seq': msg.get('seq', 0), 'ts': int(time.time()),
                'payload': {'state': 'done', 'msg': 'Flash complete'}}
        sock.sendto(json.dumps(resp).encode(), addr)

def udp_loop():
    last_status = 0
    while True:
        now = time.time()
        try:
            data, addr = sock.recvfrom(4096)
            handle_udp_message(data.decode('utf-8', errors='replace'), addr)
        except socket.timeout:
            pass

        # Clean up stale clients
        stale = [a for a, t in clients.items() if now - t > 2.0]
        for a in stale:
            del clients[a]

        # Update motor simulation and broadcast to connected UDP clients
        if now - last_status >= MOTOR_STATUS_INTERVAL:
            update_motor(MOTOR_STATUS_INTERVAL)
            last_status = now

            if clients:
                payload = {
                    'current': round(motor['current'], 2),
                    'voltage': round(motor['voltage'], 1),
                    'speed': motor['speed'],
                    'position': round(motor['position'], 1),
                    'torque': round(motor['torque'], 2),
                    'status_word': motor['status_word'],
                    'fault': motor['fault_code'],
                    'mode': motor_mode,
                    'alive': motor_enabled,
                    'wdg_ms': motor['wdg_ms'],
                }
                msg = {'cmd': 'motor_status', 'seq': 0, 'ts': int(now),
                       'payload': payload}
                for addr in list(clients.keys()):
                    try:
                        sock.sendto(json.dumps(msg).encode(), addr)
                    except:
                        pass

        time.sleep(0.01)

# ---------- Main ----------
if __name__ == '__main__':
    print("""
╔══════════════════════════════════════════════════╗
║       Mock ESP32 CAN Dongle Server               ║
╠══════════════════════════════════════════════════╣
║  UDP Port (dongle):  {}                         ║
║  Web Dashboard:      http://localhost:{}     ║
║  Motor Status:       {} Hz                          ║
║  Heartbeat:          {} Hz                         ║
╚══════════════════════════════════════════════════╝
""".format(UDP_PORT, WEB_PORT, int(1/MOTOR_STATUS_INTERVAL), int(1/HEARTBEAT_INTERVAL)))
    udp_thread = threading.Thread(target=udp_loop, daemon=True)
    udp_thread.start()
    app.run(host='0.0.0.0', port=WEB_PORT, debug=False)
