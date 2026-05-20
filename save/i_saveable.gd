## ISaveable — 可存档模块基类（Framework 层）。
## 任何需要持久化的模块继承此类，重写 save_key() / on_save() / on_load()。
## 构造时自动注册到 SaveService，无需手动调用 register_saveable()。
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


func _init() -> void:
	_auto_register.call_deferred()


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


func _auto_register() -> void:
	var svc := _get_save_service()
	if svc != null:
		svc.register_saveable(self)


func _get_save_service() -> SaveService:
	var registry := ServiceRegistry.get_instance()
	if registry == null:
		return null
	return registry.get_save_service()
