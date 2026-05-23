## EcsSystem — ECS 系统基类。
## 所有 ECS 系统必须继承此类，提供生命周期钩子。
## on_tick 中只写 EcsCommandBuffer，不直接修改 world storage。
class_name EcsSystem
extends RefCounted


## 系统初始化回调，在调度器注册后、首次 tick 前调用。
func on_init(p_world: EcsWorld) -> void:
	pass


## 每帧逻辑回调。p_ecb 为本组命令缓冲，写入会在组末统一 apply。
func on_tick(p_world: EcsWorld, p_ecb: EcsCommandBuffer, p_delta: float) -> void:
	pass


## 系统关闭回调，调度器停止时调用。
func on_shutdown() -> void:
	pass
