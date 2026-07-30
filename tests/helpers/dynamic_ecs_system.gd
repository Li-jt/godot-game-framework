# tests/helpers/dynamic_ecs_system.gd
## 动态 EcsSystem 测试替身。通过 _tick_fn / _shutdown_fn 注入行为。
extends GF_EcsSystem

var _tick_fn: Callable
var _shutdown_fn: Callable
var was_ticked: bool = false
var was_shutdown: bool = false


func on_tick(p_world: GF_EcsWorld, p_ecb: GF_EcsCommandBuffer, p_delta: float) -> void:
	was_ticked = true
	if _tick_fn.is_valid():
		_tick_fn.call(p_world, p_ecb, p_delta)


func on_shutdown() -> void:
	was_shutdown = true
	if _shutdown_fn.is_valid():
		_shutdown_fn.call()
