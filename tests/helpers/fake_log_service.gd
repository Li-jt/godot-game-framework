# tests/helpers/fake_log_service.gd
## 测试用 GF_LogService，记录所有输出供断言。
class_name GF_FakeLogService
extends GF_LogService

var messages: Array[Dictionary] = []


func _on_init() -> GF_OperationResult:
	return GF_OperationResult.ok()


func debug(p_tag: String, p_message: String, p_context: Dictionary = {}) -> void:
	messages.append({"level": "debug", "source": p_tag, "message": p_message})


func info(p_tag: String, p_message: String, p_context: Dictionary = {}) -> void:
	messages.append({"level": "info", "source": p_tag, "message": p_message})


func warning(p_tag: String, p_message: String, p_context: Dictionary = {}) -> void:
	messages.append({"level": "warning", "source": p_tag, "message": p_message})


func error(p_tag: String, p_message: String, p_context: Dictionary = {}) -> void:
	messages.append({"level": "error", "source": p_tag, "message": p_message})


func last_message() -> String:
	return messages[-1]["message"] if messages.size() > 0 else ""


func last_level() -> String:
	return messages[-1]["level"] if messages.size() > 0 else ""


func has_message_containing(p_text: String) -> bool:
	for m in messages:
		if p_text in str(m.message):
			return true
	return false


func count_by_level(p_level: String) -> int:
	var c: int = 0
	for m in messages:
		if m.level == p_level:
			c += 1
	return c


func reset() -> void:
	messages.clear()
