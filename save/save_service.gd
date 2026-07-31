## GF_SaveService
## 存档服务。管理槽位、版本、迁移链、Provider 路由、GF_ISaveable 收集。
##
## 存档流程：
##   Game 层注册 GF_ISaveable → GF_SaveService._build_save_data() 自动打包 → Provider 写入
## 读取流程：
##   Provider 读取 → 版本迁移 → _restore_save_data() 自动分发
##
## GF_ISaveable 注册路径：
##   1. collect_from_node(root) — 场景树自动扫描（Node-based GF_ISaveable）
##   2. child_entering_tree 信号 — 增量注册（collect 之后挂入的新节点）
##   3. register_saveable() — 手动注册（纯数据、Service、Mod GF_ISaveable）
##
## 网络兼容：
##   on_save() 产出的模块级字典可直接作为网络 delta 发送；
##   服务端收到后按 save_key 合并或校验。
class_name GF_SaveService
extends GF_ModuleLifecycle

var _provider: GF_SaveProvider = null
var _path_resolver: GF_PathResolver = null
var _log: GF_LogService = null

var _migrators: Dictionary = {}
var _saveables: Dictionary = {}  # String key → Variant（GF_ISaveable 或 Node 子类）


func _on_init() -> GF_OperationResult:
	return GF_OperationResult.ok()


func configure(p_provider: GF_SaveProvider, p_path_resolver: GF_PathResolver, p_log: GF_LogService) -> GF_OperationResult:
	if p_provider == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "provider 不能为 null", module_name)
	if p_path_resolver == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "path_resolver 不能为 null", module_name)
	if p_log == null:
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "log 不能为 null", module_name)
	_provider = p_provider
	_path_resolver = p_path_resolver
	_log = p_log
	return GF_OperationResult.ok()


# ============================================================
# 迁移器注册
# ============================================================

func register_migrator(p_migrator: GF_SaveVersionMigrator) -> void:
	_migrators[p_migrator.from_version] = p_migrator
	_log.info("Save", "注册迁移器: v%d → v%d" % [p_migrator.from_version, p_migrator.to_version])


# ============================================================
# GF_ISaveable 注册
# ============================================================

## 注册 GF_ISaveable 实例。存盘时 save_all() 自动收集其 on_save() 数据。
## 适用于：GF_ISaveable 子类（RefCounted）、实现 GF_ISaveable 接口的 Node、Mod 注册的 saveable。
## accept 任何实现了 save_key() / on_save() / on_load() 的对象（鸭子类型）。
func register_saveable(p_saveable) -> void:
	var key: String = p_saveable.save_key()
	if key.is_empty():
		_log.warning("Save", "GF_ISaveable.save_key() 为空，跳过注册")
		return
	_saveables[key] = p_saveable
	_log.info("Save", "注册存档模块: %s" % key)


func unregister_saveable(p_key: String) -> void:
	_saveables.erase(p_key)


## 从节点树一次性扫描 GF_ISaveable 后代节点并注册。
## 之后通过 child_entering_tree/child_exiting_tree 信号做增量注册，无需重复调用。
## 调用时机：GF_WorldRoot._on_world_setup() 中，场景树构建完成后。
## [br]
## [param root] 要扫描的根节点
## [br]
## [return] 收集到的 GF_ISaveable 数量
func collect_from_node(p_root: Node) -> int:
	if p_root == null:
		return 0
	var count := 0
	_collect_recursive(p_root, count)
	_log.info("Save", "collect_from_node(%s) → 收集 %d 个 GF_ISaveable" % [p_root.name, count])

	# 从此之后增量注册
	if not p_root.child_entering_tree.is_connected(_on_saveable_child_entered):
		p_root.child_entering_tree.connect(_on_saveable_child_entered)
	if not p_root.child_exiting_tree.is_connected(_on_saveable_child_exited):
		p_root.child_exiting_tree.connect(_on_saveable_child_exited)

	return count


## 按 key 前缀批量注销（世界切换、Mod 卸载时使用）。
## [br]
## [return] 被注销的数量
func unregister_by_prefix(p_prefix: String) -> int:
	var removed := 0
	var keys_to_remove: Array[String] = []
	for key in _saveables:
		if key.begins_with(p_prefix):
			keys_to_remove.append(key)
	for key in keys_to_remove:
		_saveables.erase(key)
		removed += 1
	if removed > 0:
		_log.info("Save", "unregister_by_prefix(%s) → 注销 %d 个" % [p_prefix, removed])
	return removed


## 世界切换时调用：注销旧世界 GF_ISaveable，扫描新世界后代并注册。
## p_old_root 传 null 表示首次加载（跳过注销步骤）。
## p_prefix 默认为 "world."，区分世界数据与 Profile 级数据。
func on_world_switch(p_old_root: Node, p_new_root: Node, p_prefix: String = "world.") -> void:
	if p_old_root != null:
		if p_old_root.child_entering_tree.is_connected(_on_saveable_child_entered):
			p_old_root.child_entering_tree.disconnect(_on_saveable_child_entered)
		if p_old_root.child_exiting_tree.is_connected(_on_saveable_child_exited):
			p_old_root.child_exiting_tree.disconnect(_on_saveable_child_exited)
		unregister_by_prefix(p_prefix)

	if p_new_root != null:
		collect_from_node(p_new_root)


## 从一组对象中批量注册（鸭子类型：只要实现了 save_key/on_save/on_load 即可）。
func collect_from(p_saveables: Array) -> GF_OperationResult:
	var errors: Array[String] = []
	for obj in p_saveables:
		if not _is_saveable(obj):
			continue
		var key: String = obj.save_key()
		if key.is_empty():
			errors.append("save_key() 返回空字符串: %s" % str(obj))
			continue
		register_saveable(obj)
	if not errors.is_empty():
		return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, ", ".join(errors), module_name)
	return GF_OperationResult.ok()


## 按 owner 注销所有 GF_ISaveable（按 save_key 前缀匹配，如 "mod:xxx:"）。
func unregister_saveables_by_owner(p_owner: String) -> int:
	var removed := 0
	var keys_to_remove: Array[String] = []
	for key in _saveables:
		if key.begins_with(p_owner):
			keys_to_remove.append(key)
	for key in keys_to_remove:
		_saveables.erase(key)
		removed += 1
	return removed


# ============================================================
# 公开方法
# ============================================================

## 保存全部已注册的 GF_ISaveable 模块
func save_all(p_slot: int, p_meta: GF_SaveMeta) -> GF_OperationResult:
	var data := _build_save_data()
	return save(p_slot, data, p_meta)


## 保存指定数据。写入时自动标记当前 GF_SaveVersion。
func save(p_slot: int, p_data: Dictionary, p_meta: GF_SaveMeta) -> GF_OperationResult:
	p_meta.save_version = GF_SaveVersion.CURRENT
	return _provider.save(p_slot, p_data, p_meta)


## 读取并自动恢复所有已注册的 GF_ISaveable 模块
func load_and_restore(p_slot: int) -> GF_OperationResult:
	var result := load_slot(p_slot)
	if result.is_fail():
		return result
	_restore_save_data(result.data as Dictionary)
	return GF_OperationResult.ok()


## 读取原始存档数据（不自动恢复）。自动检测版本并执行迁移链。
## 注意：方法名用 load_slot 避免与 Godot 内置 load() 冲突。
func load_slot(p_slot: int) -> GF_OperationResult:
	var raw_result := _provider.load_full(p_slot)
	if raw_result.is_fail():
		return raw_result

	var wrapper: Dictionary = raw_result.data
	var meta: Dictionary = wrapper.get("meta", {})
	var data: Dictionary = wrapper.get("data", {})
	var data_version: int = meta.get("save_version", 0)

	if data_version == GF_SaveVersion.CURRENT:
		return GF_OperationResult.ok(data)

	if data_version > GF_SaveVersion.CURRENT:
		return GF_OperationResult.fail(
			GF_OperationResult.ERR_MIGRATION,
			"存档版本(v%d)高于当前版本(v%d)，请升级游戏" % [data_version, GF_SaveVersion.CURRENT],
			module_name
		)

	var v := data_version
	while v < GF_SaveVersion.CURRENT:
		var migrator: GF_SaveVersionMigrator = _migrators.get(v, null)
		if migrator == null:
			return GF_OperationResult.fail(
				GF_OperationResult.ERR_MIGRATION,
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

	_log.info("Save", "存档版本迁移完成 v%d → v%d" % [data_version, GF_SaveVersion.CURRENT])
	return GF_OperationResult.ok(data)


func list_slots() -> GF_OperationResult:
	return _provider.list_slots()


func delete_slot(p_slot: int) -> GF_OperationResult:
	return _provider.delete(p_slot)


# ============================================================
# 内部
# ============================================================

func _build_save_data() -> Dictionary:
	var data := {}
	for key in _saveables.keys():
		var saveable: Variant = _saveables[key]
		data[key] = saveable.on_save()
	_log.info("Save", "构建存档数据完成，模块数: %d" % data.size())
	return data


func _restore_save_data(p_data: Dictionary) -> void:
	# 按恢复优先级排序所有 saveable
	var sorted: Array = []
	for key in p_data.keys():
		if _saveables.has(key):
			var saveable: Variant = _saveables[key]
			sorted.append({"key": key, "saveable": saveable, "priority": saveable.restore_priority()})

	sorted.sort_custom(func(a, b): return a["priority"] < b["priority"])

	var restored := 0
	var skipped := 0
	for entry in sorted:
		var key: String = entry["key"]
		var saveable: Variant = entry["saveable"]
		saveable.on_load(p_data[key])
		restored += 1

	# 处理存档中存在但未注册的 key（按原始顺序遍历）
	for key in p_data.keys():
		if not _saveables.has(key):
			_log.warning("Save", "存档中存在未注册模块: %s（已跳过）" % key)
			skipped += 1
	_log.info("Save", "恢复存档数据完成，恢复模块数: %d，跳过: %d" % [restored, skipped])


## 递归扫描节点树，收集实现了 GF_ISaveable 接口的后代节点。
func _collect_recursive(p_node: Node, p_count: int) -> void:
	if _is_saveable(p_node):
		register_saveable(p_node)
		p_count += 1
	for child in p_node.get_children():
		_collect_recursive(child, p_count)


## child_entering_tree 回调：新节点挂入时自动注册。
func _on_saveable_child_entered(p_child: Node) -> void:
	if _is_saveable(p_child):
		register_saveable(p_child)


## child_exiting_tree 回调：节点移出时自动注销。
func _on_saveable_child_exited(p_child: Node) -> void:
	if _is_saveable(p_child):
		var key := p_child.save_key() as String
		unregister_saveable(key)


## 鸭子类型检查：对象是否实现了 GF_ISaveable 所需的方法。
## Node 和 RefCounted 是不同的继承链，不能用 is 检查，故用方法存在性判断。
func _is_saveable(p_obj) -> bool:
	return p_obj.has_method("save_key") and p_obj.has_method("on_save") and p_obj.has_method("on_load")
