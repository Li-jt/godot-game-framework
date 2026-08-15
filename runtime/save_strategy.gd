# runtime/save_strategy.gd
## GF_SaveStrategy — 存档策略抽象基类（性能路线图 §3.2）。
## 三模式由子类实现，使用方在装配时通过 GF_SaveService.set_strategy() 声明：
## - FULL：全量快照（默认，向后兼容）
## - DELTA：基底快照 + 增量（模块级 diff，定期压缩）→ GF_DeltaSaveStrategy
## - SEED_PATCH：世界种子 + 改动记录，回档 = 重置 + 重放 → GF_SeedPatchSaveStrategy
##
## 策略职责（SaveService 编排，策略只做数据形态转换）：
## - build_payload：全量数据 → 待写盘 data
## - restore_payload：存档 data → 全量数据（供分发到各 GF_ISaveable）
## 版本迁移链三模式共用：load 时先 restore_payload 合成全量数据，
## 再走迁移链——迁移器只看到全量模块数据，不感知策略形态。
class_name GF_SaveStrategy
extends RefCounted

enum Mode { FULL, DELTA, SEED_PATCH }


## 策略模式名（写入存档 meta.save_mode；旧存档无此字段时按 full 处理）。
func get_mode_name() -> String:
	return "full"


## 返回当前策略推荐的 GF_SaveProvider 类型。GF_SaveService 据此选择 Provider。
func get_provider_type() -> String:
	return "Local"


## 构建存档 payload。默认 FULL：直接透传。
func build_payload(p_data: Dictionary) -> Dictionary:
	return p_data


## 恢复存档 payload。默认 FULL：直接透传。
func restore_payload(p_data: Dictionary) -> Dictionary:
	return p_data
