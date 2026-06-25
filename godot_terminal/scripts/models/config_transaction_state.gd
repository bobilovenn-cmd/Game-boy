## 配置事务状态
## 保存 RGB30 配置页中高风险事务的本地状态，例如修改电机节点 ID。
## 这里只保存 UI 状态，不伪造 ESP32 或驱动器结果。

extends RefCounted

var old_node := 0
var new_node := 0
var prepared := false
var busy := false
var phase := ""
var progress := 0
var message := ""
var last_error := ""


func reset() -> void:
	old_node = 0
	new_node = 0
	prepared = false
	busy = false
	phase = ""
	progress = 0
	message = ""
	last_error = ""


func start_prepare(current_node: int, target_node: int) -> void:
	old_node = current_node
	new_node = target_node
	prepared = false
	busy = true
	phase = "prepare"
	progress = 0
	message = "checking node %d -> %d" % [old_node, new_node]
	last_error = ""


func apply_prepare_ack(ok: bool, text: String) -> void:
	busy = false
	prepared = ok
	phase = "prepare_ok" if ok else "prepare_failed"
	message = "prepare ok, press A again to commit" if ok else text
	last_error = "" if ok else text


func start_commit() -> void:
	busy = true
	prepared = false
	phase = "commit"
	progress = 0
	message = "committing node %d -> %d" % [old_node, new_node]
	last_error = ""


func apply_status(state: String, value: int) -> void:
	busy = true
	phase = state
	progress = value
	message = "%s %d%%" % [state, progress]


func apply_result(ok: bool, active_node: int, text: String) -> void:
	busy = false
	prepared = false
	phase = "done" if ok else "failed"
	progress = 100 if ok else progress
	message = "node changed, active node %d" % active_node if ok else text
	last_error = "" if ok else text


func can_commit_prepared() -> bool:
	return prepared and not busy and new_node >= 1 and new_node <= 127


func can_commit(current_node: int) -> bool:
	## 保留严格接口给需要核对当前 UI 节点的调用点。
	## 实际高风险提交以 ESP32 prepare OK 的事务为准；切换节点时必须 reset。
	return prepared and not busy and old_node == current_node and new_node >= 1 and new_node <= 127
