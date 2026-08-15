# runtime/delta_save_strategy.gd
## GF_DeltaSaveStrategy — 增量存档策略（性能路线图 §3.2 DELTA 模式）。
## 存档形态：{base: 全量基底, deltas: [{module_key: data 或 null}, ...]}
## - build：首次写基底；之后每模块与基底 diff（Dictionary 深比较），
##   变化模块追加为一条 delta；null 值表示模块被移除；
## - 压缩：deltas 数量达到 max_deltas_before_compact 时，基底吸收全部
##   delta 重写，deltas 清空；
## - restore：基底 + 按序应用 delta 合成全量数据；
## 大世界 + 频繁存档时，写盘量从 O(全量) 降为 O(变化量)。
class_name GF_DeltaSaveStrategy
extends GF_SaveStrategy

## delta 数量达到该值时压缩回基底
var max_deltas_before_compact: int = 20

var _base: Dictionary = {}
var _deltas: Array[Dictionary] = []
var _has_base: bool = false


func get_mode_name() -> String:
	return "delta"


func build_payload(p_data: Dictionary) -> Dictionary:
	if not _has_base:
		_base = p_data.duplicate(true)
		_deltas.clear()
		_has_base = true
		return {"base": _base, "deltas": []}

	var changes := _diff(_base, p_data)
	_deltas.append(changes)

	if _deltas.size() >= max_deltas_before_compact:
		# 压缩：基底吸收全部 delta，清空增量列表
		_base = p_data.duplicate(true)
		_deltas.clear()
		return {"base": _base, "deltas": []}

	return {"base": _base, "deltas": _deltas.duplicate(true)}


func restore_payload(p_data: Dictionary) -> Dictionary:
	var result: Dictionary = (p_data.get("base", {}) as Dictionary).duplicate(true)
	for delta in p_data.get("deltas", []):
		_apply_changes(result, delta)
	return result


## 重置策略状态（新档、世界重建时使用）。
func reset_state() -> void:
	_base.clear()
	_deltas.clear()
	_has_base = false


## 模块级 diff：新增/变化的模块记新值，消失的模块记 null。
func _diff(p_base: Dictionary, p_current: Dictionary) -> Dictionary:
	var changes := {}
	for key in p_current.keys():
		if not p_base.has(key) or p_base[key] != p_current[key]:
			changes[key] = p_current[key]
	for key in p_base.keys():
		if not p_current.has(key):
			changes[key] = null
	return changes


## 应用变化集：null 删除模块，否则覆盖。
func _apply_changes(p_target: Dictionary, p_changes: Dictionary) -> void:
	for key in p_changes.keys():
		if p_changes[key] == null:
			p_target.erase(key)
		else:
			p_target[key] = p_changes[key]
