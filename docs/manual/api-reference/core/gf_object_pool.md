# GF_ObjectPool

> 适用版本: 0.3.0 | 继承: GF_ObjectPool -> RefCounted

## 概述

通用对象池。通过策略回调适配任意对象类型，框架内统一的池化机制。

适用场景：频繁创建/销毁的短生命周期对象（如 GF_EcsCommandBuffer），避免 GC 压力。

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `create_fn` | `Callable` | `Callable()` | 创建新实例的回调，签名 `() -> Variant`。未设置则池空时 `acquire()` 返回 `null` |
| `reset_fn` | `Callable` | `Callable()` | 取出时重置对象的回调，签名 `(Variant) -> void`。在返回给调用方之前调用 |
| `cleanup_fn` | `Callable` | `Callable()` | 归还时清理对象的回调，签名 `(Variant) -> void`。在放入池之前调用 |
| `validate_fn` | `Callable` | `Callable()` | 验证对象有效性的回调，签名 `(Variant) -> bool`。池中取出的对象若无效则丢弃 |

## 公共方法

### acquire() -> Variant

从池中获取一个对象。优先从池中取已有对象（并调用 `reset_fn`），池空时调用 `create_fn` 新建。返回 `null` 表示池空且 `create_fn` 未设置。

每次取出前会调用 `validate_fn` 验证对象有效性（若已设置），无效对象会被丢弃并尝试取下一个。

### release(p_obj: Variant) -> void

归还对象到池中。调用 `cleanup_fn` 清理后放入池。传入 `null` 时静默忽略。

### available() -> int

当前池中可用对象数量。

### clear(p_free_fn: Callable = Callable()) -> void

清空池。若 `p_free_fn` 已设置且有效，对每个对象调用 `p_free_fn.call(obj)` 进行释放（如 `queue_free()`）。

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_free_fn` | `Callable` | 可选的释放回调，签名 `(Variant) -> void` |

## 使用示例

```gdscript
# 创建 ECB 对象池
var ecb_pool := GF_ObjectPool.new()
ecb_pool.create_fn = func(): return GF_EcsCommandBuffer.new()
ecb_pool.reset_fn = func(buf): buf.clear()

# 获取
var ecb: GF_EcsCommandBuffer = ecb_pool.acquire()
# ... 使用 ecb ...
# 归还
ecb_pool.release(ecb)

# 完整清理（如场景关闭时）
ecb_pool.clear()
```

## See Also

- [GF_EcsCommandBuffer](../ecs/gf_ecs_command_buffer.md) -- ECS 命令缓冲（常用此池化）
