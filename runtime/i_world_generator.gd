# runtime/i_world_generator.gd
## GF_IWorldGenerator — 确定性世界生成器协议（性能路线图 §3.4）。
## 使用方实现；SEED_PATCH 存档（GF_SeedPatchSaveStrategy）重放编排的生成入口：
## 回档 = 重置世界 → 按种子生成 → 应用改动记录（generator_hook 接线本接口）。
##
## 决定论约束：同 (seed, region) 必须产生完全相同的结果（跨平台、跨版本）——
## 禁止读时钟/随机源，随机改为「种子派生」。生成编排（何时生成哪个区域、
## 返回值如何落入实体创建管线）属于使用方语义，框架不定义。
class_name GF_IWorldGenerator
extends RefCounted


## 生成指定区域的实体描述数组。
## 返回纯数据描述（格式由使用方与自身生成管线约定），
## 实体创建走使用方管线 + 框架 spawn 路径。
func generate(_p_seed: int, _p_region: Rect2i) -> Array[Dictionary]:
	push_error("子类必须重写 generate()")
	return []
