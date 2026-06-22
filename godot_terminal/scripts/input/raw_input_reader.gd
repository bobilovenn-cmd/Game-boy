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


func drain_events() -> Array[int]:
	var events: Array[int] = []
	while udp.get_available_packet_count() > 0:
		var message = udp.get_packet().get_string_from_utf8().strip_edges()
		last_bridge_msec = Time.get_ticks_msec()
		ok = true
		fallback_enabled = false
		if message == "ready":
			continue
		if message.is_valid_int():
			events.append(int(message))

	if ok and Time.get_ticks_msec() - last_bridge_msec > BRIDGE_TIMEOUT_MSEC:
		ok = false
		fallback_enabled = true
	return events


static func normalized_button_id(event_code: int) -> int:
	return int(EVENT_CODE_TO_BUTTON_ID.get(event_code, -1))
