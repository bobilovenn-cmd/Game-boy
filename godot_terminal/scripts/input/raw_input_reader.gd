extends RefCounted

const RELEASE_OFFSET = 1000

var device_path = "/dev/input/js0"
var thread: Thread
var mutex = Mutex.new()
var queue: Array[int] = []
var running = false
var ok = false
var fallback_enabled = true


func start() -> int:
	running = true
	thread = Thread.new()
	var err = thread.start(Callable(self, "_loop"))
	if err != OK:
		running = false
		ok = false
		fallback_enabled = true
	return err


func stop() -> void:
	running = false
	if thread and thread.is_started():
		thread.wait_to_finish()


func drain_events() -> Array[int]:
	var events: Array[int] = []
	mutex.lock()
	if not queue.is_empty():
		events = queue.duplicate()
		queue.clear()
	mutex.unlock()
	return events


func _loop() -> void:
	var f = FileAccess.open(device_path, FileAccess.READ)
	if f == null:
		mutex.lock()
		ok = false
		fallback_enabled = true
		mutex.unlock()
		return

	mutex.lock()
	ok = true
	fallback_enabled = false
	mutex.unlock()

	while running:
		var buf = f.get_buffer(8)
		if buf.size() < 8:
			OS.delay_msec(8)
			continue
		var value = _i16_le(buf[4], buf[5])
		var event_type = buf[6] & 0x7f
		var number = buf[7]
		if event_type == 1:
			mutex.lock()
			if value == 1:
				queue.append(number)
			elif value == 0 and (number == 4 or number == 5):
				queue.append(RELEASE_OFFSET + number)
			mutex.unlock()


static func _i16_le(lo: int, hi: int) -> int:
	var v = (hi << 8) | lo
	if v >= 32768:
		v -= 65536
	return v
