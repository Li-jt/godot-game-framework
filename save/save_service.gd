## SaveService
## 存档服务。管理槽位、版本、迁移链、Provider 路由、ISaveable 收集。
##
## 存档流程：
##   Game 层注册 ISaveable → SaveService._build_save_data() 自动打包 → Provider 写入
## 读取流程：
##   Provider 读取 → 版本迁移 → _restore_save_data() 自动分发
##
## 网络兼容：
##   on_save() 产出的模块级字典可直接作为网络 delta 发送；
##   服务端收到后按 save_key 合并或校验。
class_name SaveService
extends ModuleLifecycle

var _provider: SaveProvider = null
var _path_resolver: PathResolver = null
var _log: LogService = null

## from_version → SaveVersionMigrator
var _migrators: Dictionary = {}

## 注册的可存档模块（按 save_key 索引，后注册覆盖先注册）
var _saveables: Dictionary = {}  # String key → ISaveable


func _on_init() -> OperationResult:
	return OperationResult.ok()


func configure(p_provider: SaveProvider, p_path_resolver: PathResolver, p_log: LogService) -> OperationResult:
	if p_provider == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "provider 不能为 null", module_name)
	if p_path_resolver == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "path_resolver 不能为 null", module_name)
	if p_log == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "log 不能为 null", module_name)
	_provider = p_provider
	_path_resolver = p_path_resolver
	_log = p_log
	return OperationResult.ok()


# ============================================================
# 迁移器注册
# ============================================================

func register_migrator(p_migrator: SaveVersionMigrator) -> void:
	_migrators[p_migrator.from_version] = p_migrator
	_log.info("Save", "注册迁移器: v%d → v%d" % [p_migrator.from_version, p_migrator.to_version])


# ============================================================
# ISaveable 注册
# ============================================================

## 注册可存档模块。同一 save_key 后注册的覆盖先注册的。
func register_saveable(p_saveable: ISaveable) -> void:
	var key := p_saveable.save_key()
	if key.is_empty():
		_log.warning("Save", "ISaveable.save_key() 为空，跳过注册")
		return
	_saveables[key] = p_saveable
	_log.info("Save", "注册存档模块: %s" % key)


## 取消注册
func unregister_saveable(p_key: String) -> void:
	_saveables.erase(p_key)


# ============================================================
# 公开方法
# ============================================================

## 保存全部已注册的 ISaveable 模块
func save_all(p_slot: int, p_meta: SaveMeta) -> OperationResult:
	var data := _build_save_data()
	return save(p_slot, data, p_meta)


## 保存指定数据
func save(p_slot: int, p_data: Dictionary, p_meta: SaveMeta) -> OperationResult:
	p_meta.save_version = SaveVersion.CURRENT
	return _provider.save(p_slot, p_data, p_meta)


## 读取并自动恢复所有已注册的 ISaveable 模块
func load_and_restore(p_slot: int) -> OperationResult:
	var result := load(p_slot)
	if result.is_fail():
		return result
	_restore_save_data(result.data as Dictionary)
	return OperationResult.ok()


## 读取原始数据（不自动恢复）
func load(p_slot: int) -> OperationResult:
	var raw_result := _provider.load_full(p_slot)
	if raw_result.is_fail():
		return raw_result

	var wrapper: Dictionary = raw_result.data
	var meta: Dictionary = wrapper.get("meta", {})
	var data: Dictionary = wrapper.get("data", {})
	var data_version: int = meta.get("save_version", 0)

	if data_version == SaveVersion.CURRENT:
		return OperationResult.ok(data)

	if data_version > SaveVersion.CURRENT:
		return OperationResult.fail(
			OperationResult.ERR_MIGRATION,
			"存档版本(v%d)高于当前版本(v%d)，请升级游戏" % [data_version, SaveVersion.CURRENT],
			module_name
		)

	var v := data_version
	while v < SaveVersion.CURRENT:
		var migrator: SaveVersionMigrator = _migrators.get(v, null)
		if migrator == null:
			return OperationResult.fail(
				OperationResult.ERR_MIGRATION,
				"缺少迁移器: v%d → v%d" % [v, v + 1],
				module_name
			)
		var migrate_result := migrator.migrate(data)
		if migrate_result.is_fail():
			_log.error("Save", "迁移失败 v%d→v%d: %s" % [v, migrator.to_version, migrate_result.error.message])
			return migrate_result

		data = migrate_result.data
		v = migrator.to_version
		_log.info("Save", "迁移完成: v%d → v%d" % [migrator.from_version, migrator.to_version])

	_log.info("Save", "存档版本迁移完成 v%d → v%d" % [data_version, SaveVersion.CURRENT])
	return OperationResult.ok(data)


func list_slots() -> OperationResult:
	return _provider.list_slots()


func delete(p_slot: int) -> OperationResult:
	return _provider.delete(p_slot)


# ============================================================
# 内部
# ============================================================

## 遍历所有 ISaveable，调用 on_save() 构建存档字典
func _build_save_data() -> Dictionary:
	var data := {}
	for key in _saveables.keys():
		var saveable: ISaveable = _saveables[key]
		data[key] = saveable.on_save()
	_log.info("Save", "构建存档数据完成，模块数: %d" % data.size())
	return data


## 遍历存档字典，按 key 匹配 ISaveable 调用 on_load()
func _restore_save_data(p_data: Dictionary) -> void:
	var restored := 0
	for key in p_data.keys():
		if _saveables.has(key):
			var saveable: ISaveable = _saveables[key]
			saveable.on_load(p_data[key])
			restored += 1
		else:
			_log.warning("Save", "存档中存在未注册模块: %s（已跳过）" % key)
	_log.info("Save", "恢复存档数据完成，恢复模块数: %d" % restored)
