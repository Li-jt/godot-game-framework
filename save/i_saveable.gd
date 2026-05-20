## ISaveable — 可存档模块接口（Framework 层）。
## 任何需要持久化的 Game 层模块实现此接口，并注册到 SaveService。
## 框架层自动遍历所有 ISaveable 完成保存/读取，Game 层无需编排。
##
## 使用方式：
##   [codeblock]
##   class_name MapData
##   extends RefCounted
##   implements ISaveable
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
