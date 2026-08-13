## GF_WorldRoot — 世界场景根节点基类（Framework 层）。
## 所有游戏世界场景的根节点继承此类。
## [br]
## _bootstrap 获取支持两种路径：
##   1. GF_SceneFactory 动态加载世界时显式注入（优先）
##   2. 编辑器直接挂载时向上遍历场景树查找 GF_AppBootstrap（回退）
## [br]
## _on_world_setup() 通过 GF_AppBootstrap.bootstrap_ready 信号触发，
## 保证在所有服务注册并配置完成后执行。若 _ready() 时 is_ready 已为 true
## （Bootstrap 先于本节点就绪的场景），则直接执行。
##
## 使用方式：
##   [codeblock]
##   class_name MyWorldRoot
##   extends GF_WorldRoot
##
##   func _on_world_setup() -> void:
##       var log := _bootstrap.service(GF_LogService) as GF_LogService
##       log.info("World", "我的世界初始化")
##   [/codeblock]
class_name GF_WorldRoot
extends Node2D

## GF_AppBootstrap 引用。由 GF_SceneFactory 注入或 _enter_tree() 时自动解析。
var _bootstrap: GF_AppBootstrap = null

## 已解析的服务缓存。GF_EcsNode 等子树节点首次解析后写入此处，
## 后续节点直接读取缓存，避免重复调用 bootstrap.service()。
var _service_cache: Dictionary = {}


func _enter_tree() -> void:
	if _bootstrap == null:
		_resolve_bootstrap()


func _ready() -> void:
	if _bootstrap == null:
		push_warning("[GF_WorldRoot] %s 无法找到 GF_AppBootstrap，_on_world_setup() 跳过。" % name)
		return

	if _bootstrap.is_ready:
		# Bootstrap 已就绪（例如 SceneFactory 动态加载场景，此时 _ready() 晚于 Bootstrap）
		_on_world_setup()
	else:
		# 编辑器直接挂载：Bootstrap._ready() 尚未执行，等信号
		_bootstrap.bootstrap_ready.connect(_on_bootstrap_ready, CONNECT_ONE_SHOT)


func _on_bootstrap_ready() -> void:
	_on_world_setup()


## 世界初始化入口。子类重写此方法。
func _on_world_setup() -> void:
	pass


## 世界退出时调用。子类在此清理订阅、注销 tick、释放资源。
func _on_world_exit() -> void:
	pass


## 向上遍历场景树，找到 GF_AppBootstrap。
func _resolve_bootstrap() -> void:
	var node: Node = self
	while node != null:
		if node is GF_AppBootstrap:
			_bootstrap = node as GF_AppBootstrap
			return
		node = node.get_parent()
