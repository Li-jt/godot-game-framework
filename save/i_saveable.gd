## ISaveable — 可存档模块基类（Framework 层）。
## 任何需要持久化的模块继承此类，重写 save_key() / on_save() / on_load()。
##
## 注意：不再自动注册。需通过 SaveService.collect_from() 或 register_saveable() 显式注册。
## 这确保了 Mod 的 Saveable 可以在正确的启动时机被收集。
##
## 使用方式：
##   [codeblock]
##   class_name MapData
##   extends ISaveable
##
##   func save_key() -> String: return "map"
##   func on_save() -> Dictionary: return {"width": width, "cells": ...}
##   func on_load(p_data: Dictionary) -> void: width = p_data["width"]; ...
##   [/codeblock]
class_name ISaveable
extends RefCounted


## 模块在存档中的唯一键名，如 "map"、"tasks"、"inventory"
func save_key() -> String:
	push_error("ISaveable.save_key() 必须由子类重写")
	return ""


## 序列化当前状态为字典。字段尽量用基础类型（int/float/String/Array/Dict）
func on_save() -> Dictionary:
	push_error("ISaveable.on_save() 必须由子类重写")
	return {}


## 从字典恢复状态。p_data 是 on_save() 产出的同构数据
func on_load(p_data: Dictionary) -> void:
	push_error("ISaveable.on_load() 必须由子类重写")


## 恢复优先级。数值越小越先恢复。默认 100。
## 例如：内容定义数据 10 → 建筑数据 50 → UI 状态 200 → Mod 数据 110+
## 子类可覆写以控制存档恢复顺序。
func restore_priority() -> int:
	return 100
