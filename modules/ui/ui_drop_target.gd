## GF_UIDropTarget
## 放置目标。游戏层创建并注册给 GF_UIService。
## 包含命中区域、接收条件和回调。
class_name GF_UIDropTarget
extends RefCounted

## 所属面板。框架在 _hit_test_target 中用于 Z-order 排序。
## 面板关闭时框架自动清理其所有 GF_UIDropTarget。
var panel: GF_UIPanel = null

## 命中矩形 — 面板局部坐标。框架自动转为全局坐标做 hit_test。
var rect: Rect2 = Rect2()

## [可选] 业务判断：此拖拽数据是否被本区域接受。
## func(data: Dictionary) -> bool
## 为空则接受所有。返回 false 则跳过此 target，hit_test 继续找下一个。
var accept_filter: Callable

## [可选] 拖拽悬停到本区域时回调。func(data: Dictionary) -> void
var on_hover: Callable

## [可选] 拖拽离开本区域时回调。func() -> void
var on_leave: Callable

## [可选] 物品放到此区域时回调。
## func(data: Dictionary) -> bool
## 返回 true=接受, false=拒绝（物品弹回）。
var on_drop: Callable
