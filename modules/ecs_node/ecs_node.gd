## GF_EcsNode — ECS 感知节点基类。
## 挂在 GF_WorldRoot 场景树下自动获取 GF_EcsWorld 引用，无需手动查找 Bootstrap。
##
## 和 Unity 的 MonoBehaviour 提供 transform、gameObject 一样，
## GF_EcsNode 为框架下的游戏节点提供 _world 和 _entity，消除样板代码。
##
## 缓存机制：
##   第一个 GF_EcsNode 向上找到 GF_WorldRoot，解析 GF_EcsWorld 并缓存到
##   [code]WorldRoot._service_cache[/code]。后续所有同子树下的 EcsNode 直接
##   从缓存读取，跳过重复的 [code]bootstrap.service()[/code] 调用。
##   这等价于 Unity [code]GetComponentInParent<T>()[/code] 的 C++ 底层缓存行为。
##
## 使用方式：
##   [codeblock]
##   class_name GameCamera
##   extends GF_EcsNode
##
##   func setup(p_entity: int) -> void:
##       bind_entity(p_entity)
##
##   func _process(_delta: float) -> void:
##       if not has_entity():
##           return
##       var pos = _world.get_component(_entity, &"Position")
##       if pos:
##           global_position = pos.value
##   [/codeblock]
##
## 注意：
##   - 子类重写 _ready() 时必须调用 super._ready()，否则 _world 不会被解析。
##   - _resolve_world() 在 _ready() 中自动调用一次。
class_name GF_EcsNode
extends Node2D

const CACHE_KEY := &"GF_EcsWorld"


## 当前绑定的 ECS 实体 ID。未绑定时为 -1。
var _entity: int = -1

## GF_EcsWorld 引用。由 _resolve_world() 在 _ready() 中自动获取。
## 如果 GF_EcsWorld 未注册到 Bootstrap，则为 null。
var _world: GF_EcsWorld = null


func _ready() -> void:
	_resolve_world()


## 向上遍历找到 GF_WorldRoot，从缓存获取或首次解析 GF_EcsWorld。
## 首次解析后缓存到 WorldRoot._service_cache，后续同子树节点直接命中缓存。
func _resolve_world() -> void:
	var root: GF_WorldRoot = _find_world_root()
	if root == null:
		push_warning("[GF_EcsNode] %s 不在 GF_WorldRoot 子树下，_world 为 null。" % name)
		return

	# 检查缓存
	if root._service_cache.has(CACHE_KEY):
		_world = root._service_cache[CACHE_KEY] as GF_EcsWorld
		return

	# 首次解析：通过 Bootstrap 获取并缓存到 WorldRoot
	if root._bootstrap == null:
		push_warning("[GF_EcsNode] GF_WorldRoot._bootstrap 为 null，请确保 GF_SceneHost 已注入。")
		return

	_world = root._bootstrap.service(GF_EcsWorld) as GF_EcsWorld
	if _world == null:
		push_warning("[GF_EcsNode] GF_EcsWorld 未注册到 Bootstrap。请在 _assemble() 中 register(GF_EcsWorld.new())。")
		return

	root._service_cache[CACHE_KEY] = _world


## 向上遍历场景树，返回第一个 GF_WorldRoot 祖先。找不到返回 null。
## 树遍历是 O(depth) 的 get_parent() 调用，在 Godot 底层为 C++ 指针追逐，代价可忽略。
func _find_world_root() -> GF_WorldRoot:
	var node: Node = self
	while node != null:
		if node is GF_WorldRoot:
			return node as GF_WorldRoot
		node = node.get_parent()
	return null


## 绑定当前节点到指定 ECS 实体。
## 绑定后，子类可通过 _entity 和 _world 直接操作该实体的组件。
func bind_entity(p_entity: int) -> void:
	_entity = p_entity


## 解除实体绑定。
func unbind_entity() -> void:
	_entity = -1


## 是否有绑定的实体。
func has_entity() -> bool:
	return _entity >= 0
