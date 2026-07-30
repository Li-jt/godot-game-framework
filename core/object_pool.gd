## GF_ObjectPool — 通用对象池。
##
## 通过策略回调适配任意对象类型，框架内统一池化机制。
##
## 使用方式：
##   [codeblock]
##   var pool := GF_ObjectPool.new()
##   pool.create_fn = func(): return MyObject.new()
##   pool.reset_fn = func(obj): obj.reset()
##
##   var obj := pool.acquire()
##   pool.release(obj)
##   [/codeblock]
class_name GF_ObjectPool
extends RefCounted

## 创建新实例的回调。() → Variant。未设置则 acquire 在池空时返回 null。
var create_fn: Callable = Callable()

## 取出时重置对象的回调。(Variant) → void。在 return 给调用方之前调用。
var reset_fn: Callable = Callable()

## 归还时清理对象的回调。(Variant) → void。在放入池之前调用。
var cleanup_fn: Callable = Callable()

## 验证对象有效性的回调。(Variant) → bool。池中取出的对象若无效则丢弃。
var validate_fn: Callable = Callable()

var _pool: Array = []


## 从池中获取一个对象。池空时调用 create_fn 新建。
func acquire() -> Variant:
	while not _pool.is_empty():
		var obj = _pool.pop_back()
		if _validate(obj):
			_reset(obj)
			return obj
	if create_fn.is_valid():
		var obj = create_fn.call()
		_reset(obj)
		return obj
	return null


## 归还对象到池中。
func release(p_obj: Variant) -> void:
	if p_obj == null:
		return
	_cleanup(p_obj)
	_pool.append(p_obj)


## 当前池中可用对象数。
func available() -> int:
	return _pool.size()


## 清空池。p_free 为 true 时对每个对象调用 free_fn。
func clear(p_free_fn: Callable = Callable()) -> void:
	if p_free_fn.is_valid():
		for obj in _pool:
			if _validate(obj):
				p_free_fn.call(obj)
	_pool.clear()


func _validate(p_obj: Variant) -> bool:
	if validate_fn.is_valid():
		return validate_fn.call(p_obj)
	return p_obj != null


func _reset(p_obj: Variant) -> void:
	if reset_fn.is_valid():
		reset_fn.call(p_obj)


func _cleanup(p_obj: Variant) -> void:
	if cleanup_fn.is_valid():
		cleanup_fn.call(p_obj)
