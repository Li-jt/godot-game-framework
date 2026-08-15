## GF_LocalSaveProvider
## 本地文件存档提供者。存档存储为 JSON 文件。
## 文件路径：{save_root}/slot_{id}.json
class_name GF_LocalSaveProvider
extends GF_SaveProvider

var _file_system: GF_FileSystemService = null
var _save_root: String = ""
var _log: GF_LogService = null


func configure(p_file_system: GF_FileSystemService, p_save_root: String, p_log: GF_LogService) -> GF_OperationResult:
	if p_file_system == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "configure: file_system 不能为 null", "LocalSave")
	if p_save_root.is_empty():
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "configure: save_root 不能为空", "LocalSave")
	if p_log == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "configure: log 不能为 null", "LocalSave")
	_file_system = p_file_system
	_save_root = p_save_root
	_log = p_log
	return GF_OperationResult.ok()


func save(p_slot: int, p_data: Dictionary, p_meta: GF_SaveMeta) -> GF_OperationResult:
	p_meta.save_time = Time.get_datetime_string_from_system(false, true)

	var wrapper := {
		"meta": _meta_to_dict(p_meta),
		"data": p_data,
	}

	var path := _slot_path(p_slot)

	# 先备份旧存档
	_file_system.backup_file(path)

	# 原子写入：写临时文件 → rename 替换
	var json_text := JSON.stringify(wrapper, "\t")
	if json_text.is_empty():
		return GF_OperationResult.fail(GF_OperationResult.ERR_IO, "JSON 序列化失败 slot=%d" % p_slot, "LocalSave")

	var result := _file_system.write_text_atomic(path, json_text)
	if result.is_fail():
		_log.error("LocalSave", "保存失败 slot=%d: %s" % [p_slot, result.error.message])
		return result

	_log.info("LocalSave", "已保存 slot=%d" % p_slot)
	return GF_OperationResult.ok()


func load(p_slot: int) -> GF_OperationResult:
	var path := _slot_path(p_slot)
	var result := _file_system.read_json(path)
	if result.is_fail():
		result = _try_restore_backup(path)
		if result.is_fail():
			return result

	var wrapper: Dictionary = result.data
	if not wrapper.has("data"):
		return GF_OperationResult.fail(GF_OperationResult.ERR_IO, "存档格式无效 slot=%d" % p_slot, "LocalSave")

	_log.info("LocalSave", "已加载 slot=%d" % p_slot)
	return GF_OperationResult.ok(wrapper.data)


func load_full(p_slot: int) -> GF_OperationResult:
	var path := _slot_path(p_slot)
	var result := _file_system.read_json(path)
	if result.is_fail():
		return _try_restore_backup(path)
	return result


## 主文件读取失败时，尝试从 .bak 备用文件恢复。
func _try_restore_backup(p_path: String) -> GF_OperationResult:
	var bak_path := p_path + ".bak"
	var result := _file_system.read_json(bak_path)
	if result.is_fail():
		return result

	_log.warning("LocalSave", "主存档损坏，已从备份恢复: %s" % p_path)
	# 将备份内容写回主文件
	var json_text := JSON.stringify(result.data, "\t")
	_file_system.write_text_atomic(p_path, json_text)
	return result

func list_slots() -> GF_OperationResult:
	var slots: Array[GF_SaveMeta] = []
	var list_result := _file_system.list_files(_save_root)
	if list_result.is_fail():
		return list_result

	for file_name in (list_result.data as Array):
		if file_name.begins_with("slot_") and file_name.ends_with(".json"):
			var path := _save_root.path_join(file_name)
			var result := _file_system.read_json(path)
			if result.is_ok():
				var wrapper: Dictionary = result.data
				if wrapper.has("meta"):
					slots.append(_meta_from_dict(wrapper.meta))
			else:
				_log.warning("LocalSave", "跳过损坏存档: %s" % file_name)

	slots.sort_custom(func(a: GF_SaveMeta, b: GF_SaveMeta): return a.slot_id < b.slot_id)
	return GF_OperationResult.ok(slots)


func delete(p_slot: int) -> GF_OperationResult:
	var path := _slot_path(p_slot)
	var result := _file_system.delete_file(path)
	if result.is_fail():
		return result
	_log.info("LocalSave", "已删除 slot=%d" % p_slot)
	return GF_OperationResult.ok()


func _slot_path(p_slot: int) -> String:
	return _save_root.path_join("slot_%d.json" % p_slot)


func _meta_to_dict(p_meta: GF_SaveMeta) -> Dictionary:
	return {
		"slot_id": p_meta.slot_id,
		"save_time": p_meta.save_time,
		"save_version": p_meta.save_version,
		"save_mode": p_meta.save_mode,
		"game_version": p_meta.game_version,
		"play_time_seconds": p_meta.play_time_seconds,
		"summary": p_meta.summary,
	}


func _meta_from_dict(p_dict: Dictionary) -> GF_SaveMeta:
	var m := GF_SaveMeta.new()
	m.slot_id = p_dict.get("slot_id", 0)
	m.save_time = p_dict.get("save_time", "")
	m.save_version = p_dict.get("save_version", 1)
	m.save_mode = p_dict.get("save_mode", "full")
	m.game_version = p_dict.get("game_version", "")
	m.play_time_seconds = p_dict.get("play_time_seconds", 0.0)
	m.summary = p_dict.get("summary", "")
	return m
