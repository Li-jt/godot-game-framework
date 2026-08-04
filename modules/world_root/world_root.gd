## GF_WorldRoot — 世界场景根节点基类（Framework 层）。
## 所有游戏世界场景的根节点继承此类。
## GF_SceneHost 加载世界后自动注入 ctx，子类在 _on_world_setup() 中初始化。
##
## 使用方式：
##   [codeblock]
##   class_name MyWorldRoot
##   extends GF_WorldRoot
##
##   func _on_world_setup() -> void:
##       _bootstrap.service(GF_LogService).info("World", "我的世界初始化")
##       # 创建地图、单位等
##   [/codeblock]
class_name GF_WorldRoot
extends Node2D

## GF_AppBootstrap 引用。由 GF_SceneHost 在加载世界后自动注入。
var _bootstrap = null

## 已解析的服务缓存。GF_EcsNode 等子树节点首次解析后写入此处，
## 后续节点直接读取缓存，避免重复调用 bootstrap.service()。
## 由子树节点按需填充，WorldRoot 自身不主动初始化此字典。
var _service_cache: Dictionary = {}


## GF_SceneHost 注入 _bootstrap 后调用。子类重写此方法做初始化。
func _on_world_setup() -> void:
	pass


## 世界退出时调用。子类在此清理订阅、注销 tick、释放资源。
func _on_world_exit() -> void:
	pass
