# tests/contract/test_ecs_storage_contract.gd
## 契约测试：GF_IEcsStorage 接口。
## 任何 GF_IEcsStorage 实现（SparseSet 等）必须通过此套测试。
extends GutTest

# 将被不同存储实现替换
var _storage: GF_IEcsStorage


func before_each() -> void:
	_storage = GF_EcsSparseSetStorage.new()


func after_each() -> void:
	_storage = null


func test_insert_and_get_data() -> void:
	_storage.insert(1, {"x": 10})
	assert_eq(_storage.get_data(1), {"x": 10})


func test_contains_after_insert() -> void:
	_storage.insert(1, {"x": 10})
	assert_true(_storage.contains(1))


func test_contains_false_for_missing() -> void:
	assert_false(_storage.contains(99999))


func test_get_data_null_for_missing() -> void:
	assert_null(_storage.get_data(99999))


func test_insert_overwrites() -> void:
	_storage.insert(1, {"v": 1})
	_storage.insert(1, {"v": 2})
	assert_eq(_storage.get_data(1), {"v": 2})


func test_erase_removes() -> void:
	_storage.insert(1, {})
	_storage.erase(1)
	assert_false(_storage.contains(1))


func test_clear_removes_all() -> void:
	_storage.insert(1, {})
	_storage.insert(2, {})
	_storage.clear()
	assert_eq(_storage.count(), 0)


func test_count_accurate() -> void:
	assert_eq(_storage.count(), 0)
	_storage.insert(1, {})
	assert_eq(_storage.count(), 1)
	_storage.insert(2, {})
	assert_eq(_storage.count(), 2)
