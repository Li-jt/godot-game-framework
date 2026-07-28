## UIDragHandler
## 拖拽源接口。游戏层继承此类实现拖拽行为。
## 框架在拖拽生命周期的各个阶段调用对应方法。
##
## 调用顺序：
##   on_begin_drag → on_drag（每帧）→ on_drop（如有接收者）→ on_end_drag（必有）
class_name UIDragHandler
extends RefCounted

## 开始拖拽。游戏层在此：
## 1. 设置 event.drag_data（告诉潜在的接收者我在拖什么）
## 2. 调用 event.show_ghost_xxx() 创建拖拽视觉
func on_begin_drag(_event: UIDragEvent) -> void:
	pass


## 每帧移动中。游戏层在此更新视觉位置、世界预览等。
## event.position 和 event.delta 已由框架更新。
func on_drag(_event: UIDragEvent) -> void:
	pass


## 有接收者接受时调用（在 on_end_drag 之前）。
## 返回 true=接受放置, false=拒绝。
## 默认为 true，游戏层按需覆写。
func on_drop(_event: UIDragEvent) -> bool:
	return true


## 拖拽结束（无论如何都调用）。
## 调用顺序：on_drop（如有）→ on_end_drag（必有）。
## game层在此销毁视觉、清理临时状态。
## event.drop_receiver 非 null 表示有面板接受了放置。
func on_end_drag(_event: UIDragEvent) -> void:
	pass
