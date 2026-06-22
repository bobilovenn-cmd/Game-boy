extends RefCounted

const AppSettings = preload("res://scripts/settings.gd")


static func load_ui_font(owner: Control) -> Font:
	var cjk_font = ResourceLoader.load("res://fonts/AGV_CJK.ttf", "", ResourceLoader.CACHE_MODE_REUSE)
	if cjk_font:
		return cjk_font
	var fallback = owner.get_theme_default_font()
	if fallback == null:
		fallback = ThemeDB.fallback_font
	return fallback


static func configure_udp(udp_client) -> Dictionary:
	udp_client.configure(AppSettings.LOCAL_UDP_PORT, AppSettings.DONGLE_IP, AppSettings.DONGLE_UDP_PORT)
	var err = udp_client.bind_any()
	if err == OK:
		return {
			"ok": true,
			"message": "UDP ready 0.0.0.0:%d -> %s:%d" % [AppSettings.LOCAL_UDP_PORT, AppSettings.DONGLE_IP, AppSettings.DONGLE_UDP_PORT],
			"kind": "info",
		}
	return {
		"ok": false,
		"message": "UDP bind failed: %d" % err,
		"kind": "error",
	}


static func start_raw_input(raw_input) -> Dictionary:
	var err = raw_input.start()
	if err == OK:
		return {"ok": true}
	return {
		"ok": false,
		"message": "Event input bridge unavailable; using Godot joypad fallback",
		"kind": "warn",
	}
