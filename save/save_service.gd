## SaveService
## 存档服务。管理槽位、版本、迁移链、Provider 路由。
class_name SaveService
extends ModuleLifecycle

var _provider: SaveProvider = null
var _path_resolver: PathResolver = null
var _log: LogService = null

## from_version → SaveVersionMigrator
var _migrators: Dictionary = {}


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

## 注册版本迁移器。每个迁移器负责一个版本跨度（如 v1→v2）。
func register_migrator(p_migrator: SaveVersionMigrator) -> void:
	_migrators[p_migrator.from_version] = p_migrator
	_log.info("Save", "注册迁移器: v%d → v%d" % [p_migrator.from_version, p_migrator.to_version])


# ============================================================
# 公开方法
# ============================================================

## 保存。自动写入当前 SaveVersion。
func save(p_slot: int, p_data: Dictionary, p_meta: SaveMeta) -> OperationResult:
	p_meta.save_version = SaveVersion.CURRENT
	return _provider.save(p_slot, p_data, p_meta)


## 读取。自动检测版本并执行迁移链。
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

	# 执行迁移链
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
