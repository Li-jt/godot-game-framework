# tests/benchmark/test_ecs_native_boundary_benchmark.gd
## 原生后端边界调用开销基准（手动运行，不纳入常规 unit 测试）：
## godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/benchmark/ -glog=1 -gexit
##
## 三档：无参 no-op / 单 int / Variant(Dictionary)，输出 μs/次。
## 只做功能断言（echo 回显正确），不做耗时硬阈值（避免环境抖动 flaky）。
## 依赖 GDExtension 已编译加载（gdextension/README.md）。
extends GutTest

const ITERATIONS := 100000


func test_boundary_call_cost() -> void:
	var probe := GF_EcsProbe.new()
	var acc: int = 0

	# 功能断言：三档边界方法回显正确
	assert_eq(probe.ping(), true)
	assert_eq(probe.echo_int(42), 42)
	var dict := {"value": 1.5, "name": "test"}
	assert_eq(probe.echo_variant(dict), dict)

	# 预热
	for i in 1000:
		probe.ping()

	# 无参 no-op
	var t0 := Time.get_ticks_usec()
	for i in ITERATIONS:
		probe.ping()
	var t1 := Time.get_ticks_usec()
	var us_ping: float = float(t1 - t0) / ITERATIONS

	# 单 int 参数
	t0 = Time.get_ticks_usec()
	for i in ITERATIONS:
		acc += probe.echo_int(42)
	t1 = Time.get_ticks_usec()
	var us_int: float = float(t1 - t0) / ITERATIONS

	# Variant(Dictionary) 参数
	t0 = Time.get_ticks_usec()
	for i in ITERATIONS:
		probe.echo_variant(dict)
	t1 = Time.get_ticks_usec()
	var us_dict: float = float(t1 - t0) / ITERATIONS

	# 对照：GDScript 本地方法调用基线
	var dummy := _Dummy.new()
	t0 = Time.get_ticks_usec()
	for i in ITERATIONS:
		acc += dummy.noop(42)
	t1 = Time.get_ticks_usec()
	var us_gdscript: float = float(t1 - t0) / ITERATIONS

	print("[BENCH-BOUNDARY] 边界调用开销（μs/次，%d 次均值）:" % ITERATIONS)
	print("  GDScript 本地调用（对照基线）: %.4f μs" % us_gdscript)
	print("  ping() 无参:                    %.4f μs" % us_ping)
	print("  echo_int(42):                   %.4f μs" % us_int)
	print("  echo_variant(dict):             %.4f μs" % us_dict)
	print("  (acc=%d 防止优化消除)" % acc)


class _Dummy:
	func noop(p_value: int) -> int:
		return p_value
