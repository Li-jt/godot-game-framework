## WorldRoot — 世界场景根节点基类（Framework 层）。
## 所有游戏世界场景的根节点继承此类。
## SceneHost 加载世界后自动注入 ctx，子类在 _on_world_setup() 中初始化。
##
## 使用方式：
##   [codeblock]
##   class_name MyWorldRoot
##   extends WorldRoot
##
##   func _on_world_setup() -> void:
##       ctx.log.info("World", "我的世界初始化")
##       # 创建地图、单位等
##   [/codeblock]
class_name WorldRoot
extends Node2D

## GameServices 上下文。由 SceneHost 在加载世界后自动注入。
var ctx: GameServices = null


## SceneHost 注入 ctx 后调用。子类重写此方法做初始化。
func _on_world_setup() -> void:
	pass


## 世界退出时调用。子类在此清理订阅、注销 tick、释放资源。
func _on_world_exit() -> void:
	pass
