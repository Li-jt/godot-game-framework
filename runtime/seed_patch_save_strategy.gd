# runtime/seed_patch_save_strategy.gd
## GF_SeedPatchSaveStrategy — 种子 + 改动记录策略（性能路线图 §3.2 SEED_PATCH 模式）。
## 适合确定性程序化世界：世界由种子生成，存档只记玩家改动。
## 回档 = 重置世界 → 注入种子 → 调用使用方生成器 → 按序应用改动记录
## → 恢复其余 saveable。
##
## 框架职责边界（不改动使用方的生成器逻辑）：
## - 框架只做重放编排（replay()），生成器/改动应用是使用方注入的 hook；
## - 改动记录格式由使用方定义（§3.3 命令日志落地后提供默认实现）。
class_name GF_SeedPatchSaveStrategy
extends GF_SaveStrategy

## 世界种子（确定性生成入口）
var seed: int = 0
## 改动记录（格式由使用方定义，框架不解释内容）
var patch_records: Array = []
## 重放 hook（使用方注入）：
## - reset_world_hook: () -> void，重置世界到初始态
## - generator_hook: (seed: int) -> void，按种子生成世界
## - patch_applier_hook: (records: Array) -> void，按序应用改动记录
var reset_world_hook: Callable = Callable()
var generator_hook: Callable = Callable()
var patch_applier_hook: Callable = Callable()


func get_mode_name() -> String:
	return "seed_patch"


func set_seed(p_seed: int) -> void:
	seed = p_seed


func set_patch_records(p_records: Array) -> void:
	patch_records = p_records


func build_payload(p_data: Dictionary) -> Dictionary:
	return {
		"seed": seed,
		"patch_records": patch_records.duplicate(true),
		"base_data": p_data,
	}


## 恢复：还原 seed/patch 供 replay 使用，base_data 走常规 saveable 分发。
func restore_payload(p_data: Dictionary) -> Dictionary:
	seed = int(p_data.get("seed", 0))
	patch_records = p_data.get("patch_records", [])
	return p_data.get("base_data", {})


## 重放编排：重置 → 生成 → 应用改动。
## 由 GF_SaveService.load_and_restore() 在 seed_patch 模式下自动调用，
## 之后才分发 base_data 到其余 saveable。
func replay() -> void:
	if reset_world_hook.is_valid():
		reset_world_hook.call()
	if generator_hook.is_valid():
		generator_hook.call(seed)
	if patch_applier_hook.is_valid():
		patch_applier_hook.call(patch_records)
