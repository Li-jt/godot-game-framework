# tests/unit/ecs/test_ecs_query.gd
extends GutTest

var _world: EcsWorld
var _fixture: EcsTestFixture


func before_each() -> void:
	_fixture = EcsTestFixture.new()
	_fixture.setup()
	_world = _fixture.world


func after_each() -> void:
	_fixture.teardown()
	_fixture = null


func test_with_component_filters_only_matching() -> void:
	var query := EcsQuery.new()
	query.with_component(EcsTestFixture.COMP_VELOCITY)
	var plan := query.build()
	var result: EcsQueryResult = plan.execute(_world)
	assert_eq(result.count(), 2)


func test_without_component_excludes() -> void:
	var query := EcsQuery.new()
	query.with_component(EcsTestFixture.COMP_POSITION)
	query.without_component(EcsTestFixture.COMP_VELOCITY)
	var plan := query.build()
	var result: EcsQueryResult = plan.execute(_world)
	assert_eq(result.count(), 2)


func test_multiple_with_all_must_have() -> void:
	var query := EcsQuery.new()
	query.with_component(EcsTestFixture.COMP_POSITION)
	query.with_component(EcsTestFixture.COMP_HEALTH)
	var plan := query.build()
	var result: EcsQueryResult = plan.execute(_world)
	assert_eq(result.count(), 1)


func test_chained_with_and_without() -> void:
	var query := EcsQuery.new()
	query.with_component(EcsTestFixture.COMP_POSITION)
	query.without_component(EcsTestFixture.COMP_VELOCITY)
	query.without_component(EcsTestFixture.COMP_HEALTH)
	var plan := query.build()
	var result: EcsQueryResult = plan.execute(_world)
	assert_eq(result.count(), 1)


func test_empty_query_matches_all() -> void:
	var query := EcsQuery.new()
	var plan := query.build()
	var result: EcsQueryResult = plan.execute(_world)
	assert_eq(result.count(), _world.entity_count())


func test_query_returns_empty_when_no_match() -> void:
	var query := EcsQuery.new()
	query.with_component(&"NonexistentComponent")
	var plan := query.build()
	var result: EcsQueryResult = plan.execute(_world)
	assert_eq(result.count(), 0)


func test_query_result_contains_entity_and_components() -> void:
	var query := EcsQuery.new()
	query.with_component(EcsTestFixture.COMP_POSITION)
	var plan := query.build()
	var result: EcsQueryResult = plan.execute(_world)

	var row := result.get_row(0)
	assert_not_null(row)
	assert_true(row.entity > 0)
	var comp = row.get_component(EcsTestFixture.COMP_POSITION)
	assert_not_null(comp)
	assert_true(comp.has("x"))
	assert_true(comp.has("y"))
