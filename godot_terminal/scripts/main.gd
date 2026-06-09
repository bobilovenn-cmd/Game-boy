extends Control

const AppSettings = preload("res://scripts/settings.gd")
const Protocol = preload("res://scripts/protocol.gd")
const MotorDataScript = preload("res://scripts/motor_data.gd")

const C_BG = Color8(4, 8, 14)
const C_BG_2 = Color8(8, 18, 28)
const C_PANEL = Color8(13, 29, 43)
const C_PANEL_2 = Color8(18, 42, 58)
const C_INPUT = Color8(3, 12, 20)
const C_LINE = Color8(42, 92, 110)
const C_GRID = Color8(22, 58, 72)
const C_TEXT = Color8(234, 247, 252)
const C_DIM = Color8(178, 214, 224)
const C_DIM_2 = Color8(145, 184, 196)
const C_ACCENT = Color8(0, 226, 188)
const C_ACCENT_2 = Color8(56, 158, 255)
const C_WARN = Color8(255, 184, 77)
const C_RED = Color8(255, 72, 92)
const C_GREEN = Color8(75, 255, 156)
const C_BLACK = Color8(0, 0, 0)

const TAB_NAMES = ["MONITOR", "CONFIG", "OTA"]
const MONITOR_ITEMS = ["ENABLE", "DISABLE", "E-STOP", "JOG CW", "JOG CCW"]
const CONFIG_ITEMS = [
	["Mode", 0x6060, 0, "drive mode"],
	["Control Word", 0x6040, 0, "CiA 402"],
	["Target Speed", 0x60FF, 0, "rpm"],
	["Target Torque", 0x6071, 0, "permille"],
	["PID Kp", 0x2010, 0, "proportional"],
	["PID Ki", 0x2011, 0, "integral"],
	["PID Kd", 0x2012, 0, "derivative"],
	["Current Limit", 0x2013, 0, "amps"],
	["Save EEPROM", 0x1010, 1, "persist"],
]
const OTA_ITEMS = ["LOAD FIRMWARE", "SEND TO DONGLE", "VERIFY MD5", "FLASH MOTOR"]

# Verified RGB30 raw /dev/input/js0 button IDs from the project memory.
const RGB30_RAW_BUTTONS = {
	0: "back",
	1: "confirm",
	2: "enable",
	3: "disable",
	4: "jog_ccw",
	5: "jog_cw",
	6: "estop",
	7: "r2",
	8: "estop",
	9: "menu",
	13: "up",
	14: "down",
	15: "left",
	16: "right",
}

# Fallback for Godot/SDL normalized joypad events. The raw reader is preferred.
const GODOT_STANDARD_BUTTONS = {
	0: "confirm",
	1: "back",
	2: "enable",
	3: "disable",
	4: "estop",
	6: "menu",
	9: "jog_ccw",
	10: "jog_cw",
	11: "up",
	12: "down",
	13: "left",
	14: "right",
}

var font: Font
var udp = PacketPeerUDP.new()
var motor = MotorDataScript.new()

var current_tab = 0
var selected = [0, 0, 0]
var status_msg = ""
var status_kind = "info"
var status_until_msec = 0
var result_msg = "No SDO transaction"
var last_heartbeat_msec = 0
var last_rx_msec = 0
var udp_ready = false

var firmware_data = PackedByteArray()
var firmware_md5 = ""
var firmware_name = ""
var firmware_size = 0
var ota_state = "idle"
var ota_progress = 0
var ota_speed_kbps = 0.0
var ota_log: Array[String] = []
var ota_offset = 0
var ota_started = false
var ota_start_msec = 0
var last_ota_send_msec = 0

var raw_thread: Thread
var raw_mutex = Mutex.new()
var raw_queue: Array[int] = []
var raw_running = false
var raw_input_ok = false
var last_input_label = "none"
var last_raw_button = -1
var godot_input_enabled = false


func _ready() -> void:
	font = get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font

	var err = udp.bind(AppSettings.LOCAL_UDP_PORT, "0.0.0.0")
	if err == OK:
		udp.set_dest_address(AppSettings.DONGLE_IP, AppSettings.DONGLE_UDP_PORT)
		udp_ready = true
		_set_status("UDP ready 0.0.0.0:%d -> %s:%d" % [AppSettings.LOCAL_UDP_PORT, AppSettings.DONGLE_IP, AppSettings.DONGLE_UDP_PORT])
	else:
		_set_status("UDP bind failed: %d" % err, "error")

	_start_raw_input()
	_log_ota("Godot terminal ready")
	set_process(true)


func _exit_tree() -> void:
	raw_running = false
	if raw_thread and raw_thread.is_started():
		raw_thread.wait_to_finish()


func _process(_delta: float) -> void:
	var now = Time.get_ticks_msec()
	_drain_raw_input()
	_poll_udp()

	if udp_ready and now - last_heartbeat_msec >= AppSettings.HEARTBEAT_INTERVAL_MS:
		_send(Protocol.heartbeat())
		last_heartbeat_msec = now

	if last_rx_msec > 0 and now - last_rx_msec > 1500:
		motor.alive = false

	_process_ota(now)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event.keycode)
	elif godot_input_enabled and event is InputEventJoypadButton:
		_handle_godot_joy_button(event.button_index, event.pressed)


func _draw() -> void:
	_draw_background()
	_draw_header()
	_draw_tabs()

	match current_tab:
		0:
			_draw_monitor_page()
		1:
			_draw_config_page()
		2:
			_draw_ota_page()

	_draw_status_overlay()
	_draw_footer()


func _start_raw_input() -> void:
	raw_running = true
	raw_thread = Thread.new()
	var err = raw_thread.start(Callable(self, "_raw_input_loop"))
	if err != OK:
		raw_input_ok = false
		godot_input_enabled = true
		_set_status("Raw input thread failed; using Godot joypad fallback", "warn")


func _raw_input_loop() -> void:
	var f = FileAccess.open("/dev/input/js0", FileAccess.READ)
	if f == null:
		raw_mutex.lock()
		raw_input_ok = false
		godot_input_enabled = true
		raw_mutex.unlock()
		return

	raw_mutex.lock()
	raw_input_ok = true
	godot_input_enabled = false
	raw_mutex.unlock()

	while raw_running:
		var buf = f.get_buffer(8)
		if buf.size() < 8:
			OS.delay_msec(8)
			continue
		var value = _i16_le(buf[4], buf[5])
		var event_type = buf[6] & 0x7f
		var number = buf[7]
		if event_type == 1:
			raw_mutex.lock()
			if value == 1:
				raw_queue.append(number)
			elif value == 0 and (number == 4 or number == 5):
				raw_queue.append(1000 + number)
			raw_mutex.unlock()


func _drain_raw_input() -> void:
	var events: Array[int] = []
	raw_mutex.lock()
	if not raw_queue.is_empty():
		events = raw_queue.duplicate()
		raw_queue.clear()
	raw_mutex.unlock()

	for raw in events:
		if raw >= 1000:
			var release_id = raw - 1000
			last_raw_button = release_id
			last_input_label = "raw %d -> jog_stop" % release_id
			_handle_action("jog_stop")
			continue
		last_raw_button = raw
		var action = RGB30_RAW_BUTTONS.get(raw, "")
		last_input_label = "raw %d -> %s" % [raw, action if action != "" else "unmapped"]
		if action != "":
			_handle_action(action)
		else:
			_set_status("Unmapped raw button %d" % raw, "warn")


func _handle_godot_joy_button(button_index: int, pressed: bool) -> void:
	if not GODOT_STANDARD_BUTTONS.has(button_index):
		return
	var action: String = GODOT_STANDARD_BUTTONS[button_index]
	last_input_label = "godot %d -> %s" % [button_index, action]
	if pressed:
		_handle_action(action)
	elif action == "jog_cw" or action == "jog_ccw":
		_handle_action("jog_stop")


func _handle_key(keycode: int) -> void:
	match keycode:
		KEY_TAB:
			_handle_action("menu")
		KEY_UP:
			_handle_action("up")
		KEY_DOWN:
			_handle_action("down")
		KEY_LEFT:
			_handle_action("left")
		KEY_RIGHT:
			_handle_action("right")
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_handle_action("confirm")
		KEY_ESCAPE:
			_handle_action("back")
		KEY_X:
			_handle_action("enable")
		KEY_Y:
			_handle_action("disable")
		KEY_Q:
			_handle_action("jog_ccw")
		KEY_E:
			_handle_action("jog_cw")
		KEY_S:
			_handle_action("estop")


func _handle_action(action: String) -> void:
	match action:
		"menu":
			current_tab = (current_tab + 1) % TAB_NAMES.size()
			_set_status("PAGE %s" % TAB_NAMES[current_tab])
		"up":
			selected[current_tab] = max(0, int(selected[current_tab]) - 1)
		"down":
			var max_idx = MONITOR_ITEMS.size() - 1
			if current_tab == 1:
				max_idx = CONFIG_ITEMS.size() - 1
			elif current_tab == 2:
				max_idx = OTA_ITEMS.size() - 1
			selected[current_tab] = min(max_idx, int(selected[current_tab]) + 1)
		"left":
			current_tab = (current_tab + TAB_NAMES.size() - 1) % TAB_NAMES.size()
			_set_status("PAGE %s" % TAB_NAMES[current_tab])
		"right":
			current_tab = (current_tab + 1) % TAB_NAMES.size()
			_set_status("PAGE %s" % TAB_NAMES[current_tab])
		"confirm":
			_confirm_current_selection()
		"back":
			_send(Protocol.jog_stop(AppSettings.DEFAULT_NODE_ID), "Jog stopped")
		"enable":
			_send(Protocol.enable(AppSettings.DEFAULT_NODE_ID), "Enable sent")
		"disable":
			_send(Protocol.disable(AppSettings.DEFAULT_NODE_ID), "Disable sent")
		"estop":
			_send(Protocol.estop(), "E-STOP sent", "error")
		"jog_cw":
			_send(Protocol.jog_start(AppSettings.DEFAULT_NODE_ID, "cw", 500), "Jog CW")
		"jog_ccw":
			_send(Protocol.jog_start(AppSettings.DEFAULT_NODE_ID, "ccw", 500), "Jog CCW")
		"jog_stop":
			_send(Protocol.jog_stop(AppSettings.DEFAULT_NODE_ID), "Jog stopped")
		"r2":
			_set_status("R2 reserved")


func _confirm_current_selection() -> void:
	if current_tab == 0:
		match int(selected[0]):
			0:
				_send(Protocol.enable(AppSettings.DEFAULT_NODE_ID), "Enable sent")
			1:
				_send(Protocol.disable(AppSettings.DEFAULT_NODE_ID), "Disable sent")
			2:
				_send(Protocol.estop(), "E-STOP sent", "error")
			3:
				_send(Protocol.jog_start(AppSettings.DEFAULT_NODE_ID, "cw", 500), "Jog CW")
			4:
				_send(Protocol.jog_start(AppSettings.DEFAULT_NODE_ID, "ccw", 500), "Jog CCW")
	elif current_tab == 1:
		var item: Array = CONFIG_ITEMS[int(selected[1])]
		var name: String = item[0]
		var index: int = item[1]
		var sub: int = item[2]
		if name == "Save EEPROM":
			_send(Protocol.sdo_write(AppSettings.DEFAULT_NODE_ID, index, sub, 0x65766173), "Save EEPROM")
		else:
			result_msg = "Reading 0x%s..." % _hex(index)
			_send(Protocol.sdo_read(AppSettings.DEFAULT_NODE_ID, index, sub), result_msg)
	elif current_tab == 2:
		match int(selected[2]):
			0:
				_load_default_firmware()
			1:
				_start_ota_transfer()
			2:
				_send(Protocol.ota_verify(), "Verify requested")
				_log_ota("Requesting MD5 verify")
			3:
				_send(Protocol.ota_flash(AppSettings.DEFAULT_NODE_ID), "Flash command sent")
				_log_ota("Flash command sent")


func _poll_udp() -> void:
	if not udp_ready:
		return
	while udp.get_available_packet_count() > 0:
		var raw = udp.get_packet().get_string_from_utf8()
		var data = Protocol.parse(raw)
		_handle_message(data)


func _handle_message(data: Dictionary) -> void:
	last_rx_msec = Time.get_ticks_msec()
	var cmd = str(data.get("cmd", ""))
	var payload = data
	if data.has("payload") and typeof(data["payload"]) == TYPE_DICTIONARY:
		payload = data["payload"]
		payload["cmd"] = cmd

	match cmd:
		"motor_status":
			motor.update_from_dict(payload)
			motor.alive = true
		"sdo_read_result":
			_handle_sdo_result(payload)
		"ota_status":
			_handle_ota_status(payload)
		"ack":
			var status = str(payload.get("status", ""))
			var msg = str(payload.get("msg", ""))
			var text = "OK: %s" % msg if status == "ok" else "ERR: %s" % msg
			_set_status(text, "info" if status == "ok" else "error")
			result_msg = text
			_log_ota(text)


func _handle_sdo_result(data: Dictionary) -> void:
	var index = int(data.get("index", 0))
	var result = str(data.get("data", ""))
	var val_text = result
	if result.is_valid_hex_number():
		val_text = "0x%s (%d)" % [result, result.hex_to_int()]
	result_msg = "0x%s = %s" % [_hex(index), val_text]
	_set_status(result_msg)


func _handle_ota_status(data: Dictionary) -> void:
	var state = str(data.get("state", ""))
	if state == "done":
		ota_state = "done"
		ota_progress = 100
		_log_ota("Flash complete")
	elif state == "error":
		ota_state = "error"
		_log_ota("OTA error")
	else:
		_log_ota("OTA: %s" % state)


func _send(message: String, ui_msg: String = "", kind: String = "info") -> bool:
	if not udp_ready:
		if ui_msg != "":
			_set_status("UDP not ready", "error")
		return false
	udp.set_dest_address(AppSettings.DONGLE_IP, AppSettings.DONGLE_UDP_PORT)
	var err = udp.put_packet(message.to_utf8_buffer())
	if err == OK:
		if ui_msg != "":
			_set_status(ui_msg, kind)
		return true
	if ui_msg != "":
		_set_status("Send failed: %d" % err, "error")
	return false


func _process_ota(now: int) -> void:
	if ota_state != "sending":
		return
	if now - last_ota_send_msec < AppSettings.OTA_SEND_INTERVAL_MS:
		return
	last_ota_send_msec = now

	if not ota_started:
		_send(Protocol.ota_start(firmware_size, firmware_md5))
		ota_started = true
		return

	if ota_offset >= firmware_size:
		ota_state = "verify"
		ota_progress = 100
		_log_ota("Transfer done %.1f KB/s" % ota_speed_kbps)
		return

	var end = min(ota_offset + AppSettings.OTA_CHUNK_SIZE, firmware_size)
	var chunk = firmware_data.slice(ota_offset, end)
	_send(Protocol.ota_chunk(ota_offset, Marshalls.raw_to_base64(chunk)))
	ota_offset = end

	var elapsed = max(0.001, float(now - ota_start_msec) / 1000.0)
	ota_progress = int(float(ota_offset) * 100.0 / float(firmware_size))
	ota_speed_kbps = (float(ota_offset) / 1024.0) / elapsed


func _load_default_firmware() -> bool:
	for path in AppSettings.FIRMWARE_PATHS:
		if FileAccess.file_exists(path):
			var bytes = FileAccess.get_file_as_bytes(path)
			if bytes.is_empty():
				continue
			firmware_data = bytes
			firmware_size = firmware_data.size()
			firmware_name = path.get_file()
			firmware_md5 = FileAccess.get_md5(path)
			ota_state = "ready"
			ota_progress = 0
			_log_ota("Loaded %s (%d KB)" % [firmware_name, firmware_size / 1024])
			_set_status("Firmware loaded")
			return true
	_log_ota("No firmware found in /storage")
	_set_status("No firmware found", "warn")
	return false


func _start_ota_transfer() -> void:
	if firmware_data.is_empty() and not _load_default_firmware():
		return
	ota_state = "sending"
	ota_progress = 0
	ota_offset = 0
	ota_started = false
	ota_start_msec = Time.get_ticks_msec()
	last_ota_send_msec = 0
	_log_ota("Starting transfer")


func _draw_background() -> void:
	draw_rect(Rect2(0, 0, 720, 720), C_BG, true)
	for y in range(0, 720, 24):
		draw_line(Vector2(0, y), Vector2(720, y), Color(C_GRID, 0.22), 1.0)
	for x in range(0, 720, 24):
		draw_line(Vector2(x, 0), Vector2(x, 720), Color(C_GRID, 0.12), 1.0)
	draw_circle(Vector2(610, 90), 150, Color(C_ACCENT_2, 0.055))
	draw_circle(Vector2(110, 660), 170, Color(C_ACCENT, 0.045))


func _draw_header() -> void:
	_draw_panel(Rect2(14, 12, 692, 64), C_PANEL, C_LINE)
	_draw_text("AGV MOTOR DIAGNOSTIC TERMINAL", 30, 28, C_TEXT, 20)
	_draw_text("RGB30 720x720  |  CANopen over UDP  |  Node %d" % AppSettings.DEFAULT_NODE_ID, 32, 54, C_DIM, 14)

	var link = motor.alive or (last_rx_msec > 0 and Time.get_ticks_msec() - last_rx_msec <= 1500)
	_draw_status_chip(Rect2(505, 23, 84, 24), "LINK", link)
	_draw_status_chip(Rect2(598, 23, 84, 24), "UDP", udp_ready)
	_draw_text("%d ms" % AppSettings.HEARTBEAT_INTERVAL_MS, 616, 55, C_DIM, 12)


func _draw_tabs() -> void:
	var x = 18.0
	for i in TAB_NAMES.size():
		var rect = Rect2(x, 88, 218, 38)
		var active = i == current_tab
		draw_rect(rect, C_ACCENT if active else C_PANEL_2, true)
		draw_rect(rect, C_ACCENT if active else C_LINE, false, 1.0)
		_draw_text(TAB_NAMES[i], rect.position.x, rect.position.y + 9, C_BLACK if active else C_TEXT, 15, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
		x += 234


func _draw_monitor_page() -> void:
	_draw_action_rail(Rect2(18, 140, 188, 360), MONITOR_ITEMS, int(selected[0]))
	_draw_telemetry_grid(Rect2(224, 140, 478, 190))
	_draw_waveform_panel(Rect2(224, 346, 478, 196))
	_draw_command_matrix(Rect2(18, 516, 188, 88))
	_draw_live_debug(Rect2(224, 558, 478, 46))


func _draw_config_page() -> void:
	_draw_panel(Rect2(18, 140, 684, 386), C_PANEL, C_LINE)
	_draw_text("OBJECT DICTIONARY", 36, 158, C_ACCENT, 17)
	_draw_text("A read selected   D-pad navigate   Start page", 330, 162, C_DIM, 14)
	var y = 194.0
	for i in CONFIG_ITEMS.size():
		var item: Array = CONFIG_ITEMS[i]
		var selected_row = i == int(selected[1])
		var row_rect = Rect2(34, y, 652, 32)
		draw_rect(row_rect, C_PANEL_2 if selected_row else C_INPUT, true)
		draw_rect(row_rect, C_ACCENT if selected_row else C_LINE, false, 2.0 if selected_row else 1.0)
		if selected_row:
			draw_rect(Rect2(row_rect.position.x, row_rect.position.y, 5, row_rect.size.y), C_ACCENT, true)
		var tc = C_TEXT
		var dc = C_DIM
		_draw_text(item[0], 46, y + 8, tc, 14)
		_draw_text("0x%s:%d" % [_hex(item[1]), item[2]], 288, y + 8, dc, 14)
		_draw_text(item[3], 408, y + 8, dc, 14)
		y += 36
	_draw_panel(Rect2(18, 542, 684, 62), C_INPUT, C_LINE)
	_draw_text("SDO RESULT", 36, 560, C_DIM, 14)
	_draw_text(result_msg, 36, 586, C_ACCENT, 16)


func _draw_ota_page() -> void:
	_draw_panel(Rect2(18, 140, 684, 120), C_PANEL, C_LINE)
	_draw_text("FIRMWARE UPDATE", 36, 160, C_ACCENT, 18)
	var fw = firmware_name if firmware_name != "" else "No firmware loaded"
	_draw_text(fw, 36, 194, C_TEXT, 16)
	var meta = "Copy firmware to /storage/firmware.bin"
	if firmware_size > 0:
		meta = "Size %.1f KB  MD5 %s..." % [float(firmware_size) / 1024.0, firmware_md5.substr(0, 16)]
	_draw_text(meta, 36, 224, C_DIM, 14)

	_draw_action_rail(Rect2(18, 284, 260, 226), OTA_ITEMS, int(selected[2]))
	_draw_panel(Rect2(300, 284, 402, 226), C_PANEL, C_LINE)
	_draw_text("TRANSFER STATE", 318, 304, C_DIM, 14)
	_draw_text(ota_state.to_upper(), 318, 336, _state_color(), 25)
	_draw_progress_bar(Rect2(318, 382, 360, 30), ota_progress, "%d%%  %.1f KB/s" % [ota_progress, ota_speed_kbps])
	_draw_text("Target: ESP32 CAN Dongle 192.168.4.1:5000", 318, 444, C_DIM, 14)

	_draw_panel(Rect2(18, 548, 684, 92), C_INPUT, C_LINE)
	_draw_text("OTA LOG", 36, 566, C_DIM, 14)
	var log_y = 591.0
	for line in ota_log:
		_draw_text(line, 36, log_y, C_TEXT, 11)
		log_y += 15


func _draw_action_rail(rect: Rect2, items: Array, selected_index: int) -> void:
	_draw_panel(rect, C_PANEL, C_LINE)
	_draw_text("COMMANDS", rect.position.x + 18, rect.position.y + 18, C_DIM, 14)
	var y = rect.position.y + 48
	for i in items.size():
		var is_sel = i == selected_index
		var r = Rect2(rect.position.x + 14, y, rect.size.x - 28, 38)
		draw_rect(r, C_PANEL_2 if is_sel else C_INPUT, true)
		draw_rect(r, C_ACCENT if is_sel else C_LINE, false, 2.0 if is_sel else 1.0)
		if is_sel:
			draw_rect(Rect2(r.position.x, r.position.y, 5, r.size.y), C_ACCENT, true)
		_draw_text(items[i], r.position.x, r.position.y + 10, C_TEXT, 15, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		y += 46


func _draw_telemetry_grid(rect: Rect2) -> void:
	_draw_panel(rect, C_PANEL, C_LINE)
	_draw_text("REAL-TIME TELEMETRY", rect.position.x + 18, rect.position.y + 18, C_DIM, 14)
	var cards = [
		["CURRENT", "%.2f" % motor.current, "A", C_ACCENT],
		["VOLTAGE", "%.1f" % motor.voltage, "V", C_ACCENT_2],
		["SPEED", "%d" % motor.speed, "rpm", C_WARN],
		["POSITION", "%.1f" % motor.position, "deg", C_TEXT],
		["TORQUE", "%.2f" % motor.torque, "Nm", C_GREEN],
		["STATUS", motor.get_status_text(), "", C_RED if motor.is_fault() else C_GREEN],
	]
	var idx = 0
	for row in 2:
		for col in 3:
			var card = cards[idx]
			var x = rect.position.x + 16 + col * 150
			var y = rect.position.y + 46 + row * 62
			_draw_metric_card(Rect2(x, y, 138, 52), card[0], card[1], card[2], card[3])
			idx += 1


func _draw_metric_card(rect: Rect2, label: String, value: String, unit: String, color: Color) -> void:
	draw_rect(rect, C_INPUT, true)
	draw_rect(rect, Color(color, 0.75), false, 1.0)
	_draw_text(label, rect.position.x + 8, rect.position.y + 7, C_DIM, 12)
	_draw_text(value, rect.position.x + 8, rect.position.y + 33, color, 16)
	if unit != "":
		_draw_text(unit, rect.position.x + rect.size.x - 38, rect.position.y + 33, C_DIM, 12)


func _draw_waveform_panel(rect: Rect2) -> void:
	_draw_panel(rect, C_PANEL, C_LINE)
	_draw_text("CURRENT WAVEFORM", rect.position.x + 18, rect.position.y + 18, C_DIM, 14)
	var plot = Rect2(rect.position.x + 18, rect.position.y + 46, rect.size.x - 36, rect.size.y - 66)
	draw_rect(plot, C_INPUT, true)
	for i in range(1, 5):
		var gy = plot.position.y + plot.size.y * i / 5.0
		draw_line(Vector2(plot.position.x, gy), Vector2(plot.end.x, gy), Color(C_GRID, 0.55), 1.0)
	for i in range(1, 7):
		var gx = plot.position.x + plot.size.x * i / 7.0
		draw_line(Vector2(gx, plot.position.y), Vector2(gx, plot.end.y), Color(C_GRID, 0.45), 1.0)
	draw_rect(plot, C_LINE, false, 1.0)

	var vals = motor.current_history
	var n = min(vals.size(), 96)
	if n < 2:
		_draw_text("Waiting for motor_status packets...", plot.position.x, plot.position.y + plot.size.y * 0.5 - 8, C_DIM, 15, HORIZONTAL_ALIGNMENT_CENTER, plot.size.x)
		return
	var start = vals.size() - n
	var vmin = vals[start]
	var vmax = vals[start]
	for i in range(start, vals.size()):
		vmin = min(vmin, vals[i])
		vmax = max(vmax, vals[i])
	var vrange = vmax - vmin
	if absf(vrange) < 0.001:
		vrange = 1.0
	var points = PackedVector2Array()
	for i in n:
		var v: float = vals[start + i]
		var px = plot.position.x + float(i) * plot.size.x / float(max(n - 1, 1))
		var py = plot.position.y + plot.size.y - ((v - vmin) / vrange * plot.size.y)
		points.append(Vector2(px, py))
	draw_polyline(points, C_ACCENT, 2.0)


func _draw_command_matrix(rect: Rect2) -> void:
	_draw_panel(rect, C_PANEL, C_LINE)
	_draw_text("HOTKEYS", rect.position.x + 14, rect.position.y + 16, C_DIM, 13)
	_draw_text("X ENABLE", rect.position.x + 14, rect.position.y + 42, C_ACCENT, 13)
	_draw_text("Y DISABLE", rect.position.x + 96, rect.position.y + 42, C_WARN, 13)
	_draw_text("L1/R1 JOG", rect.position.x + 14, rect.position.y + 66, C_TEXT, 13)
	_draw_text("L2/SEL STOP", rect.position.x + 96, rect.position.y + 66, C_RED, 13)


func _draw_live_debug(rect: Rect2) -> void:
	_draw_panel(rect, C_INPUT, C_LINE)
	var input_state = "RAW /dev/input/js0" if raw_input_ok else "GODOT FALLBACK"
	_draw_text("INPUT", rect.position.x + 14, rect.position.y + 16, C_DIM, 13)
	_draw_text(input_state, rect.position.x + 76, rect.position.y + 16, C_ACCENT if raw_input_ok else C_WARN, 13)
	_draw_text("LAST", rect.position.x + 270, rect.position.y + 16, C_DIM, 13)
	_draw_text(last_input_label, rect.position.x + 314, rect.position.y + 16, C_TEXT, 13)


func _draw_status_overlay() -> void:
	if status_msg == "" or Time.get_ticks_msec() > status_until_msec:
		return
	var color = C_ACCENT
	if status_kind == "warn":
		color = C_WARN
	elif status_kind == "error":
		color = C_RED
	var rect = Rect2(110, 622, 500, 42)
	draw_rect(rect, Color(C_INPUT, 0.96), true)
	draw_rect(rect, color, false, 2.0)
	_draw_text(status_msg, rect.position.x, rect.position.y + 13, color, 14, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


func _draw_footer() -> void:
	_draw_panel(Rect2(14, 670, 692, 36), C_PANEL, C_LINE)
	_draw_text("START page   D-PAD select   A execute   B stop   X enable   Y disable   L2/SEL E-STOP", 24, 694, C_DIM, 12)


func _draw_status_chip(rect: Rect2, label: String, ok: bool) -> void:
	var color = C_GREEN if ok else C_RED
	draw_rect(rect, Color(color, 0.18), true)
	draw_rect(rect, color, false, 1.0)
	_draw_text(label, rect.position.x, rect.position.y + 7, color, 10, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


func _draw_panel(rect: Rect2, fill: Color, border: Color) -> void:
	draw_rect(rect, fill, true)
	draw_rect(rect, border, false, 1.0)
	draw_line(rect.position, rect.position + Vector2(18, 0), C_ACCENT, 2.0)
	draw_line(rect.position, rect.position + Vector2(0, 18), C_ACCENT, 2.0)
	draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x - 18, rect.position.y), C_ACCENT_2, 2.0)
	draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.position.y + 18), C_ACCENT_2, 2.0)


func _draw_progress_bar(rect: Rect2, progress: int, label: String) -> void:
	draw_rect(rect, C_INPUT, true)
	var bar_w = (rect.size.x - 4) * clamp(progress, 0, 100) / 100.0
	if bar_w > 0:
		draw_rect(Rect2(rect.position.x + 2, rect.position.y + 2, bar_w, rect.size.y - 4), C_ACCENT, true)
	draw_rect(rect, C_LINE, false, 1.0)
	_draw_text(label, rect.position.x, rect.position.y + 9, C_TEXT, 11, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


func _draw_text(text: String, x: float, y: float, color: Color, font_size: int = 16, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	if font == null:
		return
	draw_string(font, Vector2(x, y + font_size), text, align, width, font_size, color)


func _set_status(message: String, kind: String = "info") -> void:
	status_msg = message
	status_kind = kind
	status_until_msec = Time.get_ticks_msec() + (2600 if kind == "error" else 1800)


func _log_ota(message: String) -> void:
	var ts = Time.get_time_string_from_system()
	ota_log.append("[%s] %s" % [ts, message])
	while ota_log.size() > 4:
		ota_log.pop_front()


func _state_color() -> Color:
	if ota_state == "error":
		return C_RED
	if ota_state == "sending" or ota_state == "verify":
		return C_WARN
	if ota_state == "done" or ota_state == "ready":
		return C_ACCENT
	return C_DIM


func _hex(value: int, width: int = 4) -> String:
	return ("%X" % value).pad_zeros(width)


func _i16_le(lo: int, hi: int) -> int:
	var v = (hi << 8) | lo
	if v >= 32768:
		v -= 65536
	return v
