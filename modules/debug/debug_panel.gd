# modules/debug/debug_panel.gd
## GF_DebugPanel — 调试面板壳。
## 复用 UI 模块面板系统（GF_UIPanel），提供子系统统计的默认渲染。
## 视觉由使用方自定义（框架壳不带游戏美术）：使用方可直接使用本类，
## 或继承后重写 refresh_stats() 用自建控件渲染。
##
## 装配（使用方）：
## [codeblock]
## var def := GF_UIPanelDef.new()
## def.panel_class = GF_DebugPanel
## ui_service.register_panel("debug_stats", def)
## [/codeblock]
class_name GF_DebugPanel
extends GF_UIPanel

## 统计文本标签（默认渲染目标）。使用方可在场景中自建并注入。
var _stats_label: Label = null
## 调试服务引用（_on_open 时通过 _bootstrap 注入）
var _debug: GF_DebugService = null


func _on_open(_p_data: Dictionary) -> void:
	_debug = _bootstrap.service(GF_DebugService) as GF_DebugService
	if _stats_label == null:
		_stats_label = Label.new()
		add_child(_stats_label)
	refresh_stats()


## 从 GF_DebugService 拉取所有子系统统计，生成默认文本。
## 使用方可重写以接入自建渲染控件。
func refresh_stats() -> void:
	if _debug == null or _stats_label == null:
		return
	var lines: Array[String] = []
	for name in _debug.get_subsystem_names():
		var stats := _debug.subsystem_stats(name)
		lines.append("%s  avg %.3fms  max %.3fms  peak@%d" % [
			name,
			stats.get("avg_ms", 0.0),
			stats.get("max_ms", 0.0),
			stats.get("peak_frame", -1),
		])
	_stats_label.text = "\n".join(lines)
