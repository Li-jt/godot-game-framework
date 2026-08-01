# tests/helpers/dynamic_saveable.gd
## 动态 ISaveable 测试替身。通过属性注入 key/data/callback/priority。
extends GF_ISaveable

var s_key: String = ""
var s_data: Dictionary = {}
var s_on_load: Callable = Callable()
var s_priority: int = 100
var was_loaded: bool = false


func save_key() -> String:
	return s_key


func on_save() -> Dictionary:
	return s_data


func on_load(p_data: Dictionary) -> void:
	was_loaded = true
	if s_on_load.is_valid():
		s_on_load.call(p_data)


func restore_priority() -> int:
	return s_priority
