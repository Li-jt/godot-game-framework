# tests/unit/ecs/test_spatial_index_sync.gd
## GF_SpatialIndexSyncSystem 单元测试：
## spawn → insert、移动 → update、despawn → remove、重建模式、阈值退化。
extends GutTest

var _world: GF_EcsWorld


func before_each() -> void:
	_world = GF_EcsWorld.new()


func after_each() -> void:
	_world.reset()
	_world = null


func _make_sync(p_index: GF_ISpatialIndex) -> GF_SpatialIndexSyncSystem:
	var sync := GF_SpatialIndexSyncSystem.new()
	sync.index = p_index
	sync.marker = FakePositionComponent
	sync.bounds_extractor = func(c: FakePositionComponent) -> Rect2: return c.rect
	return sync


func _spawn_with_rect(p_rect: Rect2) -> int:
	var entity := _world.spawn()
	var comp := FakePositionComponent.new()
	comp.rect = p_rect
	_world.add_component(entity, FakePositionComponent, comp)
	return entity


# ============================================================
# diff 模式（R* 路径）
# ============================================================


func test_sync_inserts_new_entities() -> void:
	var index := GF_RStarSpatialIndex.new()
	var sync := _make_sync(index)
	sync.on_init(_world)

	var e1 := _spawn_with_rect(Rect2(0, 0, 10, 10))
	var e2 := _spawn_with_rect(Rect2(100, 100, 10, 10))
	sync.on_tick(_world, null, 0.0)

	assert_eq(index.count(), 2)
	assert_true(index.has_entity(e1))
	assert_true(index.has_entity(e2))
	assert_eq(index.query_rect(Rect2(-5, -5, 20, 20)), [e1])


func test_sync_updates_moved_entities() -> void:
	var index := GF_RStarSpatialIndex.new()
	var sync := _make_sync(index)
	sync.on_init(_world)

	var e1 := _spawn_with_rect(Rect2(0, 0, 10, 10))
	sync.on_tick(_world, null, 0.0)

	# 移动：直接修改组件实例数据
	var comp: FakePositionComponent = _world.get_component(e1, FakePositionComponent)
	comp.rect = Rect2(50, 50, 10, 10)
	sync.on_tick(_world, null, 0.0)

	assert_eq(index.count(), 1)
	assert_eq(index.query_rect(Rect2(-5, -5, 20, 20)), [])
	assert_eq(index.query_rect(Rect2(45, 45, 20, 20)), [e1])


func test_sync_detects_component_instance_replacement() -> void:
	# 游戏层用 set_component 换新组件实例也是常见路径，diff 应正确检测
	var index := GF_RStarSpatialIndex.new()
	var sync := _make_sync(index)
	sync.on_init(_world)

	var e1 := _spawn_with_rect(Rect2(0, 0, 10, 10))
	sync.on_tick(_world, null, 0.0)

	var new_comp := FakePositionComponent.new()
	new_comp.rect = Rect2(-80, 30, 5, 5)
	_world.set_component(e1, FakePositionComponent, new_comp)
	sync.on_tick(_world, null, 0.0)

	assert_eq(index.query_rect(Rect2(0, 0, 10, 10)), [])
	assert_eq(index.query_rect(Rect2(-85, 25, 15, 15)), [e1])


func test_sync_removes_despawned_entities() -> void:
	var index := GF_RStarSpatialIndex.new()
	var sync := _make_sync(index)
	sync.on_init(_world)

	var e1 := _spawn_with_rect(Rect2(0, 0, 10, 10))
	var e2 := _spawn_with_rect(Rect2(100, 100, 10, 10))
	sync.on_tick(_world, null, 0.0)

	# despawn 后下一轮同步自动清理——游戏层零清理代码
	_world.despawn(e1)
	sync.on_tick(_world, null, 0.0)

	assert_eq(index.count(), 1)
	assert_false(index.has_entity(e1))
	assert_true(index.has_entity(e2))


func test_sync_noop_when_nothing_changed() -> void:
	var index := GF_RStarSpatialIndex.new()
	var sync := _make_sync(index)
	sync.on_init(_world)

	var e1 := _spawn_with_rect(Rect2(0, 0, 10, 10))
	sync.on_tick(_world, null, 0.0)
	sync.on_tick(_world, null, 0.0)  # 无变化，不产生任何操作
	assert_eq(index.count(), 1)


func test_sync_incomplete_config_is_noop() -> void:
	var sync := GF_SpatialIndexSyncSystem.new()
	sync.index = GF_RStarSpatialIndex.new()
	# marker / bounds_extractor 未配置
	sync.on_init(_world)
	sync.on_tick(_world, null, 0.0)  # 不应崩溃
	assert_eq(sync.index.count(), 0)


# ============================================================
# 重建模式（KDTree 路径）与阈值退化
# ============================================================


func test_sync_rebuild_every_sync_mode() -> void:
	var index := GF_KDTreeSpatialIndex.new()
	var sync := _make_sync(index)
	sync.rebuild_every_sync = true
	sync.on_init(_world)

	var e1 := _spawn_with_rect(Rect2(0, 0, 10, 10))
	sync.on_tick(_world, null, 0.0)
	assert_eq(index.count(), 1)

	var e2 := _spawn_with_rect(Rect2(100, 100, 10, 10))
	sync.on_tick(_world, null, 0.0)
	assert_eq(index.count(), 2)
	assert_eq(index.query_rect(Rect2(95, 95, 15, 15)), [e2])

	_world.despawn(e1)
	sync.on_tick(_world, null, 0.0)
	assert_eq(index.count(), 1)
	assert_false(index.has_entity(e1))


func test_sync_threshold_zero_always_rebuilds() -> void:
	# rebuild_threshold = 0：任何变化都触发整体重建（退化路径下限）
	var index := GF_RStarSpatialIndex.new()
	var sync := _make_sync(index)
	sync.rebuild_threshold = 0.0
	sync.on_init(_world)

	var e1 := _spawn_with_rect(Rect2(0, 0, 10, 10))
	var e2 := _spawn_with_rect(Rect2(50, 50, 10, 10))
	sync.on_tick(_world, null, 0.0)
	assert_eq(index.count(), 2)

	var comp: FakePositionComponent = _world.get_component(e1, FakePositionComponent)
	comp.rect = Rect2(500, 500, 10, 10)
	sync.on_tick(_world, null, 0.0)

	assert_eq(index.count(), 2)
	assert_eq(index.query_rect(Rect2(495, 495, 20, 20)), [e1])
	assert_eq(index.query_rect(Rect2(-5, -5, 20, 20)), [])
