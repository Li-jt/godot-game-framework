# tests/benchmark/test_ecs_native_query_benchmark.gd
## 原生后端 1 万实体查询基准（手动运行，不纳入常规 unit 测试）：
## godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/benchmark/ -glog=1 -gexit
##
## 四档形态：GDScript execute()（row 分配）/ execute_entities()（零分配游标）
## / 原生游标 + 逐实体回调 / 原生纯 C++ 求和。
## 只做结果一致性断言（四档 sum 相等），不做耗时硬阈值。
## 依赖 GDExtension 已编译加载（gdextension/README.md）。
extends GutTest

const ENTITY_COUNT := 10000
const TYPE_POS := 1


func test_query_cost_comparison() -> void:
	# ---------------- GDScript 世界 ----------------
	var world := GF_EcsWorld.new()
	for i in ENTITY_COUNT:
		var e := world.spawn()
		world.add_component(e, _Pos, _Pos.new_value(1.5))
	var query := GF_EcsQuery.new().with_component(_Pos).build()

	# 形态 1：execute()（row 分配）
	var t0 := Time.get_ticks_usec()
	var s1 := 0.0
	for row in query.execute(world)._rows:
		s1 += row._components[_Pos].value
	var t1 := Time.get_ticks_usec()
	var us_execute := t1 - t0

	# 形态 2：execute_entities() + get_component（零分配游标）
	t0 = Time.get_ticks_usec()
	var s2 := 0.0
	for e in query.execute_entities(world):
		s2 += world.get_component(e, _Pos).value
	t1 = Time.get_ticks_usec()
	var us_entities := t1 - t0

	# ---------------- 原生世界 ----------------
	var nw := GF_EcsNativeWorld.new()
	var payload := {"value": 1.5}
	for i in ENTITY_COUNT:
		var e := nw.spawn()
		nw.add_component(e, TYPE_POS, payload)

	# 形态 4：纯 C++ 求和（天花板）
	t0 = Time.get_ticks_usec()
	var s4 := nw.sum_value_field(TYPE_POS)
	t1 = Time.get_ticks_usec()
	var us_native := t1 - t0

	# 形态 3：原生游标 + 逐实体回调 GDScript（真实形态）
	var gd_sum_box := [0.0]
	var cb := func(e: int) -> void:
		gd_sum_box[0] += nw.get_component(e, TYPE_POS)["value"]
	t0 = Time.get_ticks_usec()
	nw.for_each(TYPE_POS, cb)
	t1 = Time.get_ticks_usec()
	var us_callback := t1 - t0

	# 结果一致性断言：四档 sum 必须相等（1.5 × 10000）
	assert_almost_eq(s1, 15000.0, 0.01, "GDScript execute() sum")
	assert_almost_eq(s2, 15000.0, 0.01, "GDScript execute_entities() sum")
	assert_almost_eq(s4, 15000.0, 0.01, "Native 纯 C++ sum")
	assert_almost_eq(gd_sum_box[0], 15000.0, 0.01, "Native 回调 sum")

	print("[BENCH-QUERY] %d 实体 × 1 组件，全量遍历 + 字段求和:" % ENTITY_COUNT)
	print("  GDScript execute()（row 分配）:        %5d μs" % us_execute)
	print("  GDScript execute_entities() + get:    %5d μs" % us_entities)
	print("  Native for_each + GDScript 回调:      %5d μs  → %.1fx vs execute" % [us_callback, float(us_execute) / maxf(us_callback, 1)])
	print("  Native 纯 C++ 求和（天花板）:          %5d μs  → %.1fx vs execute" % [us_native, float(us_execute) / maxf(us_native, 1)])


class _Pos:
	var value: float

	static func new_value(p_value: float) -> _Pos:
		var p := _Pos.new()
		p.value = p_value
		return p
