extends RefCounted

const AppSettings = preload("res://scripts/settings.gd")
const Protocol = preload("res://scripts/protocol.gd")


func process(ota, now: int) -> Array[String]:
	if ota.state != "sending":
		return []
	if now - ota.last_send_msec < AppSettings.OTA_SEND_INTERVAL_MS:
		return []
	ota.last_send_msec = now

	if not ota.started:
		ota.started = true
		return [Protocol.ota_start(ota.firmware_size, ota.firmware_md5)]

	if ota.offset >= ota.firmware_size:
		ota.mark_transfer_done()
		return []

	var end = min(ota.offset + AppSettings.OTA_CHUNK_SIZE, ota.firmware_size)
	var chunk = ota.firmware_data.slice(ota.offset, end)
	var message = Protocol.ota_chunk(ota.offset, Marshalls.raw_to_base64(chunk))
	ota.offset = end

	var elapsed = max(0.001, float(now - ota.start_msec) / 1000.0)
	ota.progress = int(float(ota.offset) * 100.0 / float(ota.firmware_size))
	ota.speed_kbps = (float(ota.offset) / 1024.0) / elapsed
	return [message]
