# tests/unit/ecs/test_ecs_archetype_storage.gd
## GF_EcsArchetypeStorage 单元测试。
## 覆盖 Archetype 特有逻辑：实体迁移、多类型共存、清理等。
extends GutTest

var _manager_ref = null


func _new_storage(p_type_id: int) -> GF_EcsArchetypeStorage:
	return GF_EcsArchetypeStorage.new(p_type_id)


func before_each() -> void:
	# 每次测试前重置共享的 _ArchetypeManager
	GF_EcsArchetypeStorage._manager = null


# ============================================================
# 基础 CRUD（契约测试）
# ============================================================

func test_insert_and_get_data() -> void:
	var s = _new_storage(1)
	s.insert(100, {"x": 10, "y": 20})
	assert_eq(s.get_data(100), {"x": 10, "y": 20})
	assert_eq(s.get_backend_name(), "Archetype")


func test_contains_after_insert() -> void:
	var s = _new_storage(1)
	s.insert(100, "data")
	assert_true(s.contains(100))


func test_contains_false_for_missing() -> void:
	var s = _new_storage(1)
	assert_false(s.contains(999))


func test_get_data_null_for_missing() -> void:
	var s = _new_storage(1)
	assert_null(s.get_data(999))


func test_insert_overwrites() -> void:
	var s = _new_storage(1)
	s.insert(100, "first")
	s.insert(100, "second")
	assert_eq(s.get_data(100), "second")
	assert_eq(s.count(), 1)


func test_erase_removes() -> void:
	var s = _new_storage(1)
	s.insert(100, "data")
	s.erase(100)
	assert_false(s.contains(100))
	assert_null(s.get_data(100))
	assert_eq(s.count(), 0)


func test_erase_nonexistent_no_error() -> void:
	var s = _new_storage(1)
	s.erase(999)


func test_clear_removes_all() -> void:
	var s = _new_storage(1)
	s.insert(100, "a")
	s.insert(200, "b")
	s.clear()
	assert_eq(s.count(), 0)
	assert_false(s.contains(100))


func test_count_accurate() -> void:
	var s = _new_storage(1)
	assert_eq(s.count(), 0)
	s.insert(1, "a"); s.insert(2, "b"); s.insert(3, "c")
	assert_eq(s.count(), 3)
	s.erase(2)
	assert_eq(s.count(), 2)


func test_entities_returns_all() -> void:
	var s = _new_storage(1)
	s.insert(10, "a"); s.insert(20, "b"); s.insert(30, "c")
	assert_eq(s.entities().size(), 3)


# ============================================================
# 多类型 Archetype 迁移测试
# ============================================================

func test_multiple_types_on_same_entity() -> void:
	var s1 = _new_storage(1)
	var s2 = _new_storage(2)

	s1.insert(100, {"x": 0.0, "y": 0.0})
	s2.insert(100, {"vx": 1.0, "vy": 0.0})

	assert_true(s1.contains(100))
	assert_true(s2.contains(100))
	assert_eq(s1.get_data(100), {"x": 0.0, "y": 0.0})
	assert_eq(s2.get_data(100), {"vx": 1.0, "vy": 0.0})


func test_adding_type_migrates_entity() -> void:
	var s1 = _new_storage(1)
	s1.insert(100, {"x": 0.0, "y": 0.0})

	var s2 = _new_storage(2)
	s2.insert(100, {"vx": 1.0, "vy": 0.0})

	assert_true(s1.contains(100))
	assert_true(s2.contains(100))
	assert_eq(s1.get_data(100), {"x": 0.0, "y": 0.0})
	assert_eq(s2.get_data(100), {"vx": 1.0, "vy": 0.0})


func test_removing_type_migrates_entity() -> void:
	var s1 = _new_storage(1)
	var s2 = _new_storage(2)

	s1.insert(100, {"x": 0.0, "y": 0.0})
	s2.insert(100, {"vx": 1.0, "vy": 0.0})

	s2.erase(100)

	assert_true(s1.contains(100))
	assert_false(s2.contains(100))
	assert_eq(s1.get_data(100), {"x": 0.0, "y": 0.0})


func test_erase_last_type_removes_entity() -> void:
	var s1 = _new_storage(1)
	s1.insert(100, {"x": 0.0})
	s1.erase(100)

	assert_false(s1.contains(100))
	assert_eq(s1.count(), 0)


func test_many_entities_many_types() -> void:
	var s_a = _new_storage(1)
	var s_b = _new_storage(2)
	var s_c = _new_storage(3)

	for i in 100:
		s_a.insert(i, {"a": i})
		if i % 2 == 0:
			s_b.insert(i, {"b": i * 2})
		if i % 3 == 0:
			s_c.insert(i, {"c": i * 3})

	assert_eq(s_a.count(), 100)
	assert_eq(s_b.count(), 50)
	assert_eq(s_c.count(), 34)

	for i in 100:
		assert_true(s_a.contains(i))
		assert_eq(s_a.get_data(i), {"a": i})
		if i % 2 == 0:
			assert_true(s_b.contains(i))
			assert_eq(s_b.get_data(i), {"b": i * 2})
		if i % 3 == 0:
			assert_true(s_c.contains(i))
			assert_eq(s_c.get_data(i), {"c": i * 3})


func test_clear_one_type_keeps_others() -> void:
	var s1 = _new_storage(1)
	var s2 = _new_storage(2)

	s1.insert(100, "pos"); s1.insert(200, "pos")
	s2.insert(100, "vel"); s2.insert(200, "vel")

	s2.clear()

	assert_eq(s2.count(), 0)
	assert_true(s1.contains(100))
	assert_true(s1.contains(200))
	assert_eq(s1.get_data(100), "pos")


# ============================================================
# 边界条件
# ============================================================

func test_insert_same_data_multiple_entities() -> void:
	var s = _new_storage(1)
	for i in 1000:
		s.insert(i, i * 10)
	assert_eq(s.count(), 1000)
	for i in 1000:
		assert_eq(s.get_data(i), i * 10)


func test_erase_all_entities_one_by_one() -> void:
	var s = _new_storage(1)
	for i in 50:
		s.insert(i, i)
	for i in 50:
		s.erase(i)
	assert_eq(s.count(), 0)


func test_empty_entities_returns_empty_array() -> void:
	var s = _new_storage(1)
	assert_eq(s.entities().size(), 0)


func test_get_backend_name() -> void:
	var s = _new_storage(1)
	assert_eq(s.get_backend_name(), "Archetype")
