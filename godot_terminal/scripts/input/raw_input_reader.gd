extends RefCounted

const RELEASE_OFFSET = 1000
const BRIDGE_PORT = 5010
const BRIDGE_TIMEOUT_MSEC = 2000

# Stable Linux event codes normalized by rgb30_input_bridge.py.
const EVENT_CODE_TO_BUTTON_ID = {
	304: 0,  # BTN_SOUTH = physical B
	305: 1,  # BTN_EAST = physical A
	307: 2,  # BTN_NORTH = physical X
	308: 3,  # BTN_WEST = physical Y
	310: 4,  # BTN_TL = L1
	311: 5,  # BTN_TR = R1
	312: 6,  # BTN_TL2 = L2
	313: 7,  # BTN_TR2 = R2
	314: 8,  # BTN_SELECT
	315: 9,  # BTN_START
	544: 13, # BTN_DPAD_UP
	545: 14, # BTN_DPAD_DOWN
	546: 15, # BTN_DPAD_LEFT
	547: 16, # BTN_DPAD_RIGHT
}

var udp = PacketPeerUDP.new()
var ok = false
var fallback_enabled = true
var last_bridge_msec = 0


func start() -> int:
	var err = udp.bind(BRIDGE_PORT, "127.0.0.1")
	if err != OK:
		ok = false
		fallback_enabled = true
	return err


func stop() -> void:
	udp.close()


func drain_events() -> Array:
	var events: Array = []
	while udp.get_available_packet_count() > 0:
		var message = udp.get_packet().get_string_from_utf8().strip_edges()
		last_bridge_msec = Time.get_ticks_msec()
		ok = true
		fallback_enabled = false
		if message == "ready":
			continue
		var parsed = parse_bridge_message(message)
		if not parsed.is_empty():
			events.append(parsed)

	if ok and Time.get_ticks_msec() - last_bridge_msec > BRIDGE_TIMEOUT_MSEC:
		ok = false
		fallback_enabled = true
	return events


static func normalized_button_id(event_code: int) -> int:
	return int(EVENT_CODE_TO_BUTTON_ID.get(event_code, -1))


static func parse_bridge_message(message: String) -> Dictionary:
	if message.is_valid_int():
		return {"type": "button", "value": int(message)}
	var parts = message.split(":")
	if parts.size() != 3 or parts[0] != "axis":
		return {}
	if not parts[1].is_valid_int() or not parts[2].is_valid_float():
		return {}
	return {
		"type": "axis",
		"axis": int(parts[1]),
		"value": clamp(float(parts[2]), -1.0, 1.0),
	}
