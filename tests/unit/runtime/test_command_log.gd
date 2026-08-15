# tests/unit/runtime/test_command_log.gd
## GF_CommandLog 单元测试（性能路线图 §3.3）。
## 开关、确定性过滤、序列化、重放、总线集成、SeedPatch 接线。
extends GutTest

var _log: GF_CommandLog
var _bus: GF_CommandBus


func before_each() -> void:
	_log = GF_CommandLog.new()
	_bus = GF_CommandBus.new()
	# 静默报错回调：行为断言与 push_error 输出解耦（GUT 将 push_error 判为错误）
	_log.error_reporter = func(_msg: String): pass


func after_each() -> void:
	_log = null
	_bus = null


# ============================================================
# 开关与记录
# ============================================================

func test_disabled_log_does_not_record() -> void:
	assert_false(_log.record_command(_DeterministicCommand.new(), "test_det"))
	assert_eq(_log.record_count(), 0)


func test_enabled_log_records_deterministic() -> void:
	_log.set_enabled(true)
	var cmd := _DeterministicCommand.new()
	cmd.amount = 5
	assert_true(_log.record_command(cmd, cmd.command_key()))
	assert_eq(_log.record_count(), 1)
	assert_eq(_log.records[0].key, "test_det")
	assert_eq(_log.records[0].data.amount, 5)


func test_nondeterministic_not_recorded() -> void:
	_log.set_enabled(true)
	var cmd := _NondeterministicCommand.new()
	assert_false(_log.record_command(cmd, cmd.command_key()))
	assert_eq(_log.record_count(), 0)


func test_nondeterministic_triggers_error_reporter() -> void:
	_log.set_enabled(true)
	# 数组包装：GDScript lambda 值捕获，值类型需经引用语义容器回传
	var holder := [""]
	_log.error_reporter = func(msg: String): holder[0] = msg
	_log.record_command(_NondeterministicCommand.new(), "test_nondet")
	assert_true(holder[0].contains("test_nondet"), "报错回调应收到命令键")


# ============================================================
# 序列化往返
# ============================================================

func test_to_dict_from_dict_roundtrip() -> void:
	_log.set_enabled(true)
	var cmd := _DeterministicCommand.new()
	cmd.amount = 7
	_log.record_command(cmd, "test_det")

	var restored := GF_CommandLog.new()
	restored.from_dict(_log.to_dict())
	assert_eq(restored.record_count(), 1)
	assert_eq(restored.records[0].key, "test_det")
	assert_eq(restored.records[0].data.amount, 7)


# ============================================================
# 重放
# ============================================================

func test_replay_rebuilds_and_executes_in_order() -> void:
	_log.set_enabled(true)
	var c1 := _DeterministicCommand.new()
	c1.amount = 1
	var c2 := _DeterministicCommand.new()
	c2.amount = 2
	_log.record_command(c1, "test_det")
	_log.record_command(c2, "test_det")
	_log.register_factory("test_det", func(data: Dictionary):
		var c := _DeterministicCommand.new()
		c.amount = data.get("amount", 0)
		return c
	)

	var seen: Array[int] = []
	var result := _log.replay(func(command):
		seen.append(command.amount)
		return GF_OperationResult.ok()
	)
	assert_true(result.is_ok())
	assert_eq(seen, [1, 2], "按记录顺序重放")


func test_replay_missing_factory_fails() -> void:
	_log.set_enabled(true)
	_log.record_command(_DeterministicCommand.new(), "test_det")
	var result := _log.replay(func(_c): return GF_OperationResult.ok())
	assert_true(result.is_fail())


func test_replay_stops_on_executor_failure() -> void:
	_log.set_enabled(true)
	_log.record_command(_DeterministicCommand.new(), "test_det")
	_log.register_factory("test_det", func(_d: Dictionary): return _DeterministicCommand.new())

	# 数组包装：GDScript lambda 值捕获，int 需经引用语义容器回传
	var counter := [0]
	var result := _log.replay(func(_c):
		counter[0] += 1
		return GF_OperationResult.fail(GF_OperationResult.ERR_INTERNAL, "boom", "test")
	)
	assert_true(result.is_fail())
	assert_eq(counter[0], 1, "执行失败即中断")


# ============================================================
# 命令总线集成
# ============================================================

func test_bus_auto_records_when_log_enabled() -> void:
	_bus.attach_command_log(_log)
	_log.set_enabled(true)
	_bus.execute(_DeterministicCommand.new(), {})
	assert_eq(_log.record_count(), 1)


func test_bus_skips_nondeterministic() -> void:
	_bus.attach_command_log(_log)
	_log.set_enabled(true)
	_bus.execute(_NondeterministicCommand.new(), {})
	assert_eq(_log.record_count(), 0)


func test_bus_records_after_validate_passes() -> void:
	# validate 失败的命令不记录
	_bus.attach_command_log(_log)
	_log.set_enabled(true)
	var cmd := _DeterministicCommand.new()
	cmd.fail_validate = true
	var result := _bus.execute(cmd, {})
	assert_true(result.is_fail())
	assert_eq(_log.record_count(), 0, "校验失败的命令不入日志")


# ============================================================
# SeedPatch 接线（改动记录默认实现）
# ============================================================

func test_seed_patch_uses_command_log_as_patch_records() -> void:
	var seed := GF_SeedPatchSaveStrategy.new()
	_log.set_enabled(true)
	_log.record_command(_DeterministicCommand.new(), "test_det")
	seed.command_log = _log
	var payload := seed.build_payload({"profile": {}})
	assert_true(payload.patch_records is Dictionary)
	assert_eq(payload.patch_records.records.size(), 1)


# ============================================================
# 内部测试命令
# ============================================================

class _DeterministicCommand extends GF_ICommand:
	var amount: int = 0
	var fail_validate: bool = false

	func command_key() -> String:
		return "test_det"

	func is_deterministic() -> bool:
		return true

	func serialize_for_log() -> Dictionary:
		return {"amount": amount}

	func validate(_p_context: Dictionary) -> GF_OperationResult:
		if fail_validate:
			return GF_OperationResult.fail(GF_OperationResult.ERR_BAD_REQUEST, "validate 拒绝", "test")
		return GF_OperationResult.ok()

	func execute(_p_context: Dictionary) -> GF_OperationResult:
		return GF_OperationResult.ok()


class _NondeterministicCommand extends GF_ICommand:
	func command_key() -> String:
		return "test_nondet"

	func is_deterministic() -> bool:
		return false

	func execute(_p_context: Dictionary) -> GF_OperationResult:
		return GF_OperationResult.ok()
