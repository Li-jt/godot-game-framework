# runtime/full_save_strategy.gd
## GF_FullSaveStrategy — 全量快照策略（默认，向后兼容）。
## 数据原样写盘，无增量、无压缩。适合小型存档与兼容模式。
class_name GF_FullSaveStrategy
extends GF_SaveStrategy


func get_mode_name() -> String:
	return "full"
