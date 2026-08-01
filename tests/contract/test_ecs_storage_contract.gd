# tests/contract/test_ecs_storage_contract.gd
## 契约测试：GF_IEcsStorage 接口。
## 通过参数化同时测试 SparseSet 和 Archetype 两种存储后端。
## 任何新增的 GF_IEcsStorage 实现必须通过此套测试。
extends GutTest

var _storage: GF_IEcsStorage = null


func before_each() -> void:
	# 默认使用 SparseSet（向后兼容），参数化测试中会被覆盖
	if _storage == null:
		_storage = GF_EcsSparseSetStorage.new()


func after_each() -> void:
	_storage = null
	GF_EcsArchetypeStorage._manager = null


# ============================================================
# 参数化：同时测试两种后端
# ============================================================

func _make_sparse_set() -> GF_IEcsStorage:
	return GF_EcsSparseSetStorage.new()


func _make_archetype() -> GF_IEcsStorage:
	var cls = load("res://ecs/storage/ecs_archetype_storage.gd")
	return cls.new(1)


var _backends := [
	{name = "SparseSet", factory = _make_sparse_set},
	{name = "Archetype", factory = _make_archetype},
]


func _set_storage(p_backend: Dictionary) -> void:
	_storage = p_backend["factory"].call()


func test_backend_name_is_correct(p_backend: Dictionary = use_parameters(_backends)) -> void:
	_set_storage(p_backend)
	assert_eq(_storage.get_backend_name(), p_backend["name"])


func test_insert_and_get_data(p_backend: Dictionary = use_parameters(_backends)) -> void:
	_set_storage(p_backend)
	_storage.insert(1, {"x": 10})
	assert_eq(_storage.get_data(1), {"x": 10})


func test_contains_after_insert(p_backend: Dictionary = use_parameters(_backends)) -> void:
	_set_storage(p_backend)
	_storage.insert(1, {"x": 10})
	assert_true(_storage.contains(1))


func test_contains_false_for_missing(p_backend: Dictionary = use_parameters(_backends)) -> void:
	_set_storage(p_backend)
	assert_false(_storage.contains(99999))


func test_get_data_null_for_missing(p_backend: Dictionary = use_parameters(_backends)) -> void:
	_set_storage(p_backend)
	assert_null(_storage.get_data(99999))


func test_insert_overwrites(p_backend: Dictionary = use_parameters(_backends)) -> void:
	_set_storage(p_backend)
	_storage.insert(1, {"v": 1})
	_storage.insert(1, {"v": 2})
	assert_eq(_storage.get_data(1), {"v": 2})


func test_erase_removes(p_backend: Dictionary = use_parameters(_backends)) -> void:
	_set_storage(p_backend)
	_storage.insert(1, {})
	_storage.erase(1)
	assert_false(_storage.contains(1))


func test_clear_removes_all(p_backend: Dictionary = use_parameters(_backends)) -> void:
	_set_storage(p_backend)
	_storage.insert(1, {})
	_storage.insert(2, {})
	_storage.clear()
	assert_eq(_storage.count(), 0)


func test_count_accurate(p_backend: Dictionary = use_parameters(_backends)) -> void:
	_set_storage(p_backend)
	assert_eq(_storage.count(), 0)
	_storage.insert(1, {})
	assert_eq(_storage.count(), 1)
	_storage.insert(2, {})
	assert_eq(_storage.count(), 2)
