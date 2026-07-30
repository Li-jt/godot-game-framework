# tests/unit/engine/test_node_pool.gd
## GF_NodePool 测试。GF_NodePool 是 RefCounted，不能调用 .free()。
extends GutTest


func test_node_pool_basic_creation() -> void:
	var pool := GF_NodePool.new()
	assert_not_null(pool)
