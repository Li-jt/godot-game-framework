# runtime/command_log.gd
## GF_CommandLog — 命令日志（性能路线图 §3.3）。
## 命令总线可选开启记录，按执行顺序 append-only 记录确定性命令。
## 用途：
## - SEED_PATCH 存档模式的改动记录默认实现（回档重放 = 按序重发命令）；
## - 回放 / 调试 / 网络同步的通用命令流记录。
##
## 命令约束（文档化）：
## - 只有确定性命令（is_deterministic() 返回 true）才可入日志——
##   同参数重放结果一致，禁止读时钟/随机源；随机改为「命令携带随机数
##   或种子派生」；
## - 非确定命令在日志开启时执行：DEBUG 构建报错提示，命令照常执行但不记录。
##
## 重放：使用方注册命令工厂（command_key → 工厂回调），replay() 按序
## 重建命令并交给注入的 executor 执行。
class_name GF_CommandLog
extends RefCounted

## 已记录命令条目（按执行顺序）: [{key, data}]
var records: Array[Dictionary] = []
## 记录开关
var enabled: bool = false
## 命令工厂注册表: command_key -> Callable(entry_data: Dictionary) -> GF_ICommand
var _factories: Dictionary = {}


func set_enabled(p_enabled: bool) -> void:
	enabled = p_enabled


func is_enabled() -> bool:
	return enabled


## 记录命令（由 GF_CommandBus 在执行前调用）。
## 非确定命令不记录并返回 false；日志关闭时直接返回 false（零开销）。
func record_command(p_command, p_key: String) -> bool:
	if not enabled:
		return false
	if not p_command.has_method("is_deterministic") or not p_command.is_deterministic():
		if OS.is_debug_build():
			push_error("[GF_CommandLog] 非确定命令不可入日志: %s（重放无法还原，已跳过记录）" % p_key)
		return false
	var entry_data := {}
	if p_command.has_method("serialize_for_log"):
		entry_data = p_command.serialize_for_log()
	records.append({"key": p_key, "data": entry_data})
	return true


## 注册命令工厂（重放重建用）。
## [param p_factory] (entry_data: Dictionary) -> GF_ICommand
func register_factory(p_key: String, p_factory: Callable) -> void:
	_factories[p_key] = p_factory


func clear() -> void:
	records.clear()


func record_count() -> int:
	return records.size()


## 按序重放全部记录。逐条重建命令并交给 executor 执行，
## 任一命令重建失败或执行失败即中断并返回失败。
## [param p_executor] (command: GF_ICommand) -> GF_OperationResult
func replay(p_executor: Callable) -> GF_OperationResult:
	for i in records.size():
		var command: Variant = _rebuild(records[i])
		if command == null:
			return GF_OperationResult.fail(
				GF_OperationResult.ERR_NOT_FOUND,
				"命令缺少工厂，无法重建: %s（第 %d 条）" % [records[i].get("key", ""), i],
				"GF_CommandLog"
			)
		var result: Variant = p_executor.call(command)
		if result is GF_OperationResult and result.is_fail():
			return result
	return GF_OperationResult.ok({"replayed": records.size()})


## 序列化（SEED_PATCH 存档的改动记录形态）。
func to_dict() -> Dictionary:
	return {"records": records.duplicate(true)}


## 从序列化数据恢复（保留已有工厂注册）。
func from_dict(p_data: Dictionary) -> void:
	records.clear()
	for entry in p_data.get("records", []):
		records.append({
			"key": entry.get("key", ""),
			"data": entry.get("data", {}),
		})


## 从日志条目重建命令实例。
func _rebuild(p_entry: Dictionary):
	if not _factories.has(p_entry.get("key", "")):
		return null
	return _factories[p_entry.get("key", "")].call(p_entry.get("data", {}))
