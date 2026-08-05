## GF_EcsNode — ECS 感知节点基类。
## 挂在 GF_WorldRoot 场景树下自动获取 GF_EcsWorld 引用，无需手动查找 Bootstrap。
##
## 和 Unity 的 MonoBehaviour 提供 transform、gameObject 一样，
## GF_EcsNode 为框架下的游戏节点提供 _world 和 _entity，消除样板代码。
##
## 初始化时序：
##   _ready() 中从 GF_WorldRoot 拿到 _bootstrap 引用。若 Bootstrap 已就绪
##   （is_ready == true），直接解析 _world 并调用 ready()；否则监听
##   bootstrap_ready 信号，待所有服务配置完成后再解析。保证 ECS 数据层和
##   节点表现层的初始化顺序一致，消除 call_deferred 的时序不确定性。
##
## 缓存机制：
##   第一个 GF_EcsNode 解析 GF_EcsWorld 后缓存到 WorldRoot._service_cache，
##   后续同子树节点直接命中缓存，跳过重复的 bootstrap.service() 调用。
##
## 使用方式：
##   [codeblock]
##   class_name GameCamera
##   extends GF_EcsNode
##
##   func ready() -> void:
##       bind_entity(_world.spawn({"Position": {...}}))
##
##   func _process(_delta: float) -> void:
##       if not has_entity():
##           return
##       var pos = _world.get_component(_entity, &"Position")
##       if pos:
##           global_position = pos.value
##   [/codeblock]
class_name GF_EcsNode
extends Node2D

const CACHE_KEY: GDScript = GF_EcsWorld


## 当前绑定的 ECS 实体 ID。未绑定时为 -1。
var _entity: int = -1

## GF_EcsWorld 引用。Bootstrap 就绪后自动解析。
var _world: GF_EcsWorld = null

## GF_AppBootstrap 引用。与 _world 同时解析，子类可通过此访问任意已注册服务。
var _bootstrap: GF_AppBootstrap = null


func _ready() -> void:
	var root: GF_WorldRoot = _find_world_root()
	if root == null:
		push_warning("[GF_EcsNode] %s 不在 GF_WorldRoot 子树下，无法获取 _world。" % name)
		return

	_bootstrap = root._bootstrap
	if _bootstrap == null:
		push_warning("[GF_EcsNode] GF_WorldRoot._bootstrap 为 null，_world 解析失败。")
		return

	if _bootstrap.is_ready:
		# Bootstrap 已就绪，直接解析
		_do_init()
	else:
		# 等 Bootstrap 初始化完成信号
		if not _bootstrap.bootstrap_ready.is_connected(_do_init):
			_bootstrap.bootstrap_ready.connect(_do_init, CONNECT_ONE_SHOT)


## Bootstrap 就绪后执行：解析 _world + 缓存 + 调用子类 ready()。
func _do_init() -> void:
	_resolve_world()
	ready()


## 从 WorldRoot._service_cache 获取或首次解析 GF_EcsWorld。
func _resolve_world() -> void:
	var root: GF_WorldRoot = _find_world_root()
	if root == null:
		return

	# 命中缓存
	if root._service_cache.has(CACHE_KEY):
		_world = root._service_cache[CACHE_KEY] as GF_EcsWorld
		return

	# 首次解析并缓存到 WorldRoot
	if _bootstrap == null:
		return

	_world = _bootstrap.service(GF_EcsWorld) as GF_EcsWorld
	if _world == null:
		push_warning("[GF_EcsNode] GF_EcsWorld 未注册。请在 _assemble() 中 register(GF_EcsWorld.new())。")
		return

	root._service_cache[CACHE_KEY] = _world


## 向上遍历场景树，返回第一个 GF_WorldRoot 祖先。
func _find_world_root() -> GF_WorldRoot:
	var node: Node = self
	while node != null:
		if node is GF_WorldRoot:
			return node as GF_WorldRoot
		node = node.get_parent()
	return null


## 子类重写此方法替代 _ready() 做业务初始化。
## 调用时机：_world 和 _bootstrap 均已解析完毕，所有服务就绪。
## 等价于 Zenject 的 IInitializable.Initialize()。
func ready() -> void:
	pass


## 绑定当前节点到指定 ECS 实体。
func bind_entity(p_entity: int) -> void:
	_entity = p_entity


## 解除实体绑定。
func unbind_entity() -> void:
	_entity = -1


## 是否有绑定的实体。
func has_entity() -> bool:
	return _entity >= 0
