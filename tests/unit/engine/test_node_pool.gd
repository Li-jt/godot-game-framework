# tests/unit/engine/test_node_pool.gd
## NodePool 测试需要场景树，标记为集成级测试。
extends GutTest


func test_node_pool_basic_creation() -> void:
	# NodePool 需要场景树来 instantiate，验证基本创建
	var pool := NodePool.new()
	assert_not_null(pool)
	pool.free()
