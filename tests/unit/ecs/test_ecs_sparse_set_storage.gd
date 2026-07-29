# tests/unit/ecs/test_ecs_sparse_set_storage.gd
## GF_EcsSparseSetStorage 单元测试。
## SparseSet 存储后端：insert、erase、contains、count、clear。
extends GutTest

var _storage: GF_EcsSparseSetStorage


func before_each() -> void:
	_storage = GF_EcsSparseSetStorage.new()


func after_each() -> void:
	_storage = null


func test_insert_stores() -> void:
	_storage.insert(1, {"x": 10, "y": 20})
	assert_eq(_storage.get_data(1), {"x": 10, "y": 20})


func test_insert_overwrites() -> void:
	_storage.insert(1, {"x": 10})
	_storage.insert(1, {"x": 999})
	assert_eq(_storage.get_data(1), {"x": 999})


func test_get_data_null_for_missing() -> void:
	assert_null(_storage.get_data(99999))


func test_contains_true_for_present() -> void:
	_storage.insert(1, {})
	assert_true(_storage.contains(1))


func test_contains_false_for_missing() -> void:
	assert_false(_storage.contains(99999))


func test_erase_removes() -> void:
	_storage.insert(1, {})
	_storage.erase(1)
	assert_false(_storage.contains(1))


func test_erase_nonexistent_no_error() -> void:
	_storage.erase(99999)  # 不应崩溃


func test_clear_removes_all() -> void:
	_storage.insert(1, {})
	_storage.insert(2, {})
	_storage.insert(3, {})
	_storage.clear()
	assert_eq(_storage.count(), 0)


func test_count_accurate() -> void:
	assert_eq(_storage.count(), 0)
	_storage.insert(1, {})
	assert_eq(_storage.count(), 1)
	_storage.insert(2, {})
	assert_eq(_storage.count(), 2)
	_storage.erase(1)
	assert_eq(_storage.count(), 1)
