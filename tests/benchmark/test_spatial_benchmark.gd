# tests/benchmark/test_spatial_benchmark.gd
## 空间索引基准（手动运行，不纳入常规 unit 测试）：
## godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/benchmark/ -glog=1 -gexit
##
## 输出各结构在 1000/5000 实体下的重建、范围查、最近邻耗时（微秒），
## 只做结果正确性断言，不做耗时硬阈值（避免环境抖动 flaky）。
extends GutTest

const QUERY_ROUNDS := 100

var _point := Vector2(100.0, -50.0)
var _rect := Rect2(-500.0, -500.0, 1000.0, 1000.0)


func test_benchmark_1000_entities() -> void:
	_benchmark(1000)


func test_benchmark_5000_entities() -> void:
	_benchmark(5000)


func _benchmark(p_count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var entries: Dictionary = {}
	for i in range(p_count):
		entries[i + 1] = Rect2(
			rng.randf_range(-5000.0, 5000.0), rng.randf_range(-5000.0, 5000.0),
			rng.randf_range(1.0, 20.0), rng.randf_range(1.0, 20.0))

	var impls: Array = [
		["GF_KDTreeSpatialIndex", GF_KDTreeSpatialIndex.new()],
		["GF_RStarSpatialIndex", GF_RStarSpatialIndex.new()],
	]
	for impl in impls:
		var index: GF_ISpatialIndex = impl[1]

		var t0 := Time.get_ticks_usec()
		index.rebuild(entries)
		var rebuild_us := Time.get_ticks_usec() - t0

		t0 = Time.get_ticks_usec()
		var hit_count := 0
		for i in range(QUERY_ROUNDS):
			hit_count = index.query_rect(_rect).size()
		var rect_us := float(Time.get_ticks_usec() - t0) / QUERY_ROUNDS

		t0 = Time.get_ticks_usec()
		var nearest_count := 0
		for i in range(QUERY_ROUNDS):
			nearest_count = index.query_nearest(_point, 10).size()
		var nearest_us := float(Time.get_ticks_usec() - t0) / QUERY_ROUNDS

		gut.p("[spatial][%s][%d] rebuild=%dus query_rect=%.1fus(%d hits) query_nearest(10)=%.1fus(%d results)" % [impl[0], p_count, rebuild_us, rect_us, hit_count, nearest_us, nearest_count])
		assert_eq(index.count(), p_count)
		assert_true(hit_count > 0, "基准矩形内应有命中")
		assert_eq(nearest_count, 10)
