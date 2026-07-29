## GF_EcsCommandBufferPool — 命令缓冲对象池。
## 复用 GF_EcsCommandBuffer 实例，降低 GC 压力。
class_name GF_EcsCommandBufferPool
extends RefCounted

var _pool: Array[GF_EcsCommandBuffer] = []


## 从池中获取一个已清空的缓冲。
func acquire() -> GF_EcsCommandBuffer:
	if _pool.is_empty():
		return GF_EcsCommandBuffer.new()
	var buf: GF_EcsCommandBuffer = _pool.pop_back() as GF_EcsCommandBuffer
	buf.clear()
	return buf


## 将使用完毕的缓冲归还池中。
func release(p_buffer: GF_EcsCommandBuffer) -> void:
	if p_buffer != null:
		_pool.append(p_buffer)


## 当前池中可用缓冲数量。
func available() -> int:
	return _pool.size()
