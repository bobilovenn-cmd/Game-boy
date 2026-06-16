extends RefCounted

var peer = PacketPeerUDP.new()
var ready = false
var last_error = OK

var local_port = 0
var dest_ip = ""
var dest_port = 0


func configure(local_port_value: int, dest_ip_value: String, dest_port_value: int) -> void:
	local_port = local_port_value
	dest_ip = dest_ip_value
	dest_port = dest_port_value


func bind_any() -> int:
	last_error = peer.bind(local_port, "0.0.0.0")
	ready = last_error == OK
	if ready:
		peer.set_dest_address(dest_ip, dest_port)
	return last_error


func send_text(message: String) -> int:
	if not ready:
		return ERR_UNCONFIGURED
	peer.set_dest_address(dest_ip, dest_port)
	return peer.put_packet(message.to_utf8_buffer())


func poll_text_packets() -> Array[String]:
	var packets: Array[String] = []
	if not ready:
		return packets
	while peer.get_available_packet_count() > 0:
		packets.append(peer.get_packet().get_string_from_utf8())
	return packets
