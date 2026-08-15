# tests/helpers/ecs_test_fixture.gd
## ECS 测试 fixture — 创建预设的 World 状态，减少 Arranging 代码。
class_name GF_EcsTestFixture
extends RefCounted

# GDScript const 不支持 class_name 引用初始化（非编译期常量），用 static var
static var COMP_POSITION: GDScript = FakeCompPosition
static var COMP_VELOCITY: GDScript = FakeCompVelocity
static var COMP_HEALTH: GDScript = FakeCompHealth
static var COMP_NAME: GDScript = FakeCompName

var world: GF_EcsWorld = null
var entity_fast: int = 0      ## entity with Position + Velocity
var entity_slow: int = 0      ## entity with Position + Velocity
var entity_static: int = 0    ## entity with Position only
var entity_dead: int = 0      ## entity with Position + Health (health=0)


func setup() -> void:
	world = GF_EcsWorld.new()
	entity_fast = world.spawn()
	world.add_component(entity_fast, COMP_POSITION, {"x": 0, "y": 0})
	world.add_component(entity_fast, COMP_VELOCITY, {"vx": 10, "vy": 0})

	entity_slow = world.spawn()
	world.add_component(entity_slow, COMP_POSITION, {"x": 100, "y": 0})
	world.add_component(entity_slow, COMP_VELOCITY, {"vx": 1, "vy": 0})

	entity_static = world.spawn()
	world.add_component(entity_static, COMP_POSITION, {"x": 50, "y": 50})

	entity_dead = world.spawn()
	world.add_component(entity_dead, COMP_POSITION, {"x": 200, "y": 200})
	world.add_component(entity_dead, COMP_HEALTH, {"current": 0, "max": 100})


func teardown() -> void:
	if world != null:
		world.reset()
		world = null


## 断言辅助
func assert_entity_count(p_expected: int) -> bool:
	return world.entity_count() == p_expected


func assert_has_component(p_entity: int, p_type: GDScript) -> bool:
	return world.has_component(p_entity, p_type)
