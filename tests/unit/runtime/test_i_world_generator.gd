# tests/unit/runtime/test_i_world_generator.gd
## GF_IWorldGenerator 接口契约测试（性能路线图 §3.4）。
## 子类重写、同 seed 决定论、不同 seed 区分。
extends GutTest


func test_override_generate_returns_seed_data() -> void:
	var gen := _FakeGenerator.new()
	var result := gen.generate(42, Rect2i(0, 0, 16, 16))
	assert_eq(result.size(), 1)
	assert_eq(result[0].seed, 42)
	assert_eq(result[0].region, Rect2i(0, 0, 16, 16))


func test_same_seed_same_result() -> void:
	var gen := _FakeGenerator.new()
	var a := gen.generate(7, Rect2i(1, 2, 16, 16))
	var b := gen.generate(7, Rect2i(1, 2, 16, 16))
	assert_eq(a, b, "同 seed 同 region 结果必须完全一致（决定论约束）")


func test_different_seed_different_result() -> void:
	var gen := _FakeGenerator.new()
	var a := gen.generate(1, Rect2i(0, 0, 16, 16))
	var b := gen.generate(2, Rect2i(0, 0, 16, 16))
	assert_ne(a, b)


func test_is_world_generator_type() -> void:
	var gen := _FakeGenerator.new()
	assert_true(gen is GF_IWorldGenerator, "实现类应满足接口类型")


class _FakeGenerator extends GF_IWorldGenerator:
	func generate(p_seed: int, p_region: Rect2i) -> Array[Dictionary]:
		# 种子派生（测试替身）：无时钟/随机源，保证决定论
		return [{"seed": p_seed, "region": p_region}]
