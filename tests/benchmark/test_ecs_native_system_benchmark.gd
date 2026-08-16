# tests/benchmark/test_ecs_native_system_benchmark.gd
## 原生系统执行环境基准（§1.7 验收件，手动运行，不纳入常规 unit 测试）：
## godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/benchmark/ -glog=1 -gexit
##
## 对照：1 万实体 Position += Velocity * delta——
##   A. GDScript 系统形态（execute_entities + get/set_component）
##   B. 原生系统（MoveNativeSystem，C++ tick，经 GF_EcsNativeSystemHost）
## 断言两档推进结果一致；耗时倍数仅打印（验收线 ≥10x，不做硬阈值断言）。
## 依赖 GDExtension 已编译加载（gdextension/README.md）。
extends GutTest

const ENTITY_COUNT := 10000
const KEY_POS := 1
const KEY_VEL := 2
const DELTA := 0.5


func test_native_system_vs_gdscript() -> void:
	# ---------------- A. GDScript 档 ----------------
	var world := GF_EcsWorld.new()
	for i in ENTITY_COUNT:
		var e := world.spawn()
		world.add_component(e, _Pos, _Pos.new_value(1.0))
		world.add_component(e, _Vel, _Vel.new_value(2.0))

	var query := GF_EcsQuery.new().with_component(_Pos).with_component(_Vel).build()
	var t0 := Time.get_ticks_usec()
	for _tick in 10:
		for e in query.execute_entities(world):
			var pos: _Pos = world.get_component(e, _Pos)
			var vel: _Vel = world.get_component(e, _Vel)
			pos.x += vel.vx * DELTA
			world.set_component(e, _Pos, pos)
	var t1 := Time.get_ticks_usec()
	var us_gdscript := t1 - t0

	# 结果锚点：第一个实体的 x（1.0 + 2.0 * 0.5 * 10 = 11.0）
	var gd_anchor: float = 0.0
	for e in query.execute_entities(world):
		gd_anchor = world.get_component(e, _Pos).x
		break
	assert_almost_eq(gd_anchor, 11.0, 0.001, "GDScript 档推进 10 tick 后 x 应为 11.0")

	# ---------------- B. 原生档 ----------------
	var nw := GF_EcsNativeWorld.new()
	# 注意：每实体必须独立字典——Variant 边界是浅共享（引用计数），
	# 复用同一字典会让全部实体指向同一底层（框架与 GDScript 后端同语义）
	for i in ENTITY_COUNT:
		var e := nw.spawn()
		nw.add_component(e, KEY_POS, {"x": 1.0})
		nw.add_component(e, KEY_VEL, {"vx": 2.0, "vy": 0.0})

	var host := GF_EcsNativeSystemHost.new()
	assert_true(host.attach_world(nw), "host 关联原生世界")
	assert_true(host.register_system("MoveNativeSystem", PackedInt64Array([KEY_POS, KEY_VEL])),
		"按名注册示例原生系统（工厂宏已在 dylib 加载时执行）")

	t0 = Time.get_ticks_usec()
	for _tick in 10:
		host.tick_all(DELTA)
	t1 = Time.get_ticks_usec()
	var us_native := t1 - t0

	# 结果一致性：原生档第一个实体的 x 也应为 11.0
	var native_anchor: float = 0.0
	for e in nw.all_entities():
		native_anchor = nw.get_component(e, KEY_POS)["x"]
		break
	assert_almost_eq(native_anchor, 11.0, 0.001, "原生档推进 10 tick 后 x 应为 11.0")

	print("[BENCH-SYSTEM] %d 实体 × Position+=Velocity*%.1f × 10 tick:" % [ENTITY_COUNT, DELTA])
	print("  GDScript 系统形态（query+get/set）: %6d μs" % us_gdscript)
	print("  Native 系统（C++ tick，host 调度）: %6d μs  → %.1fx" % [us_native, float(us_gdscript) / maxf(us_native, 1)])


class _Pos:
	var x: float

	static func new_value(p_x: float) -> _Pos:
		var p := _Pos.new()
		p.x = p_x
		return p


class _Vel:
	var vx: float

	static func new_value(p_vx: float) -> _Vel:
		var v := _Vel.new()
		v.vx = p_vx
		return v
