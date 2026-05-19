## MemoryLogSink
## 内存日志 Sink。保留最近 N 条日志，供 Debug 面板查看。
class_name MemoryLogSink
extends LogSink

class Entry:
	var level: LogLevel.Level
	var tag: String
	var message: String
	var context: Dictionary
	var timestamp: String

var _entries: Array[Entry] = []
var max_entries: int = 500


func _init(p_max: int = 500):
	sink_name = "MemorySink"
	max_entries = p_max


func write(p_level: LogLevel.Level, p_tag: String, p_message: String, p_context: Dictionary) -> void:
	if p_level < min_level:
		return

	var entry := Entry.new()
	entry.level = p_level
	entry.tag = p_tag
	entry.message = p_message
	entry.context = p_context
	entry.timestamp = Time.get_datetime_string_from_system(false, true)
	_entries.append(entry)

	while _entries.size() > max_entries:
		_entries.pop_front()


## 获取最近 N 条日志
func get_entries(p_count: int = 50) -> Array[Entry]:
	var result: Array[Entry] = []
	var start := maxi(0, _entries.size() - p_count)
	for i in range(start, _entries.size()):
		result.append(_entries[i])
	return result


## 清除所有日志
func clear() -> void:
	_entries.clear()
