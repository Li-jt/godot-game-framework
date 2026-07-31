# 性能优化指南

## 概述

本文档提供 godot-game-framework 各模块的性能优化建议和最佳实践。框架本身已做了基础优化，游戏层遵循以下指南可以进一步提升性能。

---

## ECS 查询优化

### 使用合适的存储类型

框架提供两种 ECS 存储实现：

| 存储类型 | 适用场景 | 查询性能 |
|---------|---------|---------|
| `GF_EcsSparseSetStorage` | 组件稀疏分布（不是每个实体都有） | O(n) 遍历实体 |
| `GF_EcsArchetypeStorage` | 组件组合固定、高频查询 | O(1) 按 Archetype 查询 |

**推荐：** 对于高频查询的组件组合（如每个可移动实体都有 Position + Movement），使用 Archetype 存储。

```gdscript
# 使用 Archetype 存储提升批量查询性能
var storage := GF_EcsArchetypeStorage.new()
world.set_storage(&"Position", storage)
```

### 减少 optional_component 查询

带 `optional_component` 的查询需要额外的存在性检查，比 `with_component` 慢。

```gdscript
# ❌ 避免：大量 optional 条件
var query := GF_EcsQuery.new()
query.with_component(&"Position")
query.with_component(&"Movement")
query.optional_component(&"Health")
query.optional_component(&"Combat")
query.optional_component(&"Inventory")
query.optional_component(&"AI")

# ✅ 推荐：拆分为多个 focused query
var movement_query := GF_EcsQuery.new()
movement_query.with_component(&"Position")
movement_query.with_component(&"Movement")

var combat_query := GF_EcsQuery.new()
combat_query.with_component(&"Position")
combat_query.with_component(&"Health")
combat_query.with_component(&"Combat")
```

### 缓存 Query 对象

不要在每帧中创建新的 Query 对象，在 System 初始化时创建并缓存。

```gdscript
# ❌ 错误：每帧创建 Query
func on_tick(p_world, p_ecb, p_delta):
    var query := GF_EcsQuery.new()
    query.with_component(&"Position")
    for row in query.execute(p_world):
        # ...

# ✅ 正确：缓存 Query
var _query: GF_EcsQuery = null

func _on_init() -> GF_OperationResult:
    _query = GF_EcsQuery.new()
    _query.with_component(&"Position")
    _query.with_component(&"Movement")
    return GF_OperationResult.ok()

func on_tick(p_world, p_ecb, p_delta):
    for row in _query.execute(p_world):
        # ...
```

---

## Scheduler TickGroup 选择

GF_Scheduler 按 TickGroup 分组管理回调的执行顺序。选择合适的组可以减少不必要的每帧开销。

| TickGroup | 执行频率 | 适用场景 |
|-----------|---------|---------|
| PRE_FRAME | 每帧 | 输入采集、状态重置 |
| FRAME | 每帧 | 主游戏逻辑（默认） |
| POST_FRAME | 每帧 | 渲染前更新、相机跟随 |
| PHYSICS | 物理帧 | 物理计算、碰撞检测 |
| LATE | 每帧 | 视觉效果、动画 |
| INTERVAL_100MS | 每 100ms | 不紧急的定时检查 |
| INTERVAL_500MS | 每 500ms | AI 决策、存档检查、统计数据 |
| INTERVAL_1S | 每秒 | 自动存档、日志刷新 |
| INTERVAL_5S | 每 5 秒 | 资源清理、慢速检查 |

```gdscript
# 高频操作放在 FRAME 组
scheduler.register_frame_callback(_update_movement, "movement")

# 低频操作放在 INTERVAL 组
scheduler.register_interval_callback(_check_achievements, 500, "achievement_check")
scheduler.register_interval_callback(_auto_save_tick, 5000, "auto_save")
```

---

## 对象池使用

### NodePool

对于频繁创建/销毁的 Node（子弹、粒子效果），使用 `GF_NodePool` 避免 GC 抖动。

```gdscript
var _bullet_pool: GF_NodePool = null

func _on_init() -> GF_OperationResult:
    _bullet_pool = GF_NodePool.new()
    _bullet_pool.configure(bullet_scene, 20, _world_root)
    return GF_OperationResult.ok()

func fire_bullet(p_pos: Vector2, p_dir: Vector2) -> void:
    var bullet: Node2D = _bullet_pool.acquire()
    bullet.global_position = p_pos
    bullet.direction = p_dir
    bullet.visible = true

func _on_bullet_expired(p_bullet: Node2D) -> void:
    p_bullet.visible = false
    _bullet_pool.release(p_bullet)
```

### ObjectPool

对于 RefCounted 对象（ECS 组件、数据容器），使用 `GF_ObjectPool`。

```gdscript
var _component_pool: GF_ObjectPool = null

func _on_init() -> GF_OperationResult:
    _component_pool = GF_ObjectPool.new()
    _component_pool.configure(func(): return PositionComponent.new(), 100)
    return GF_OperationResult.ok()
```

### 何时使用对象池

| 策略 | 适用场景 |
|------|---------|
| 对象池 | 高频创建/销毁（每秒 >10 次） |
| 直接创建 | 低频创建、短暂使用、内存不紧张 |
| 缓存复用 | 单例、全局服务、配置数据 |

---

## 音频 SFX 池化

高频音效（脚步声、射击声、UI 点击）应使用 AudioStreamPlayer 池。

```gdscript
# GF_AudioService 内部管理 SFX 池
# 游戏层只需调用 play_cue
audio.play_cue("sfx/footstep")

# 避免在高频循环中创建新播放器
# ❌ 每帧创建 AudioStreamPlayer
# ✅ 框架自动管理池化
```

---

## 日志级别生产环境设置

生产环境应关闭 DEBUG 和 VERBOSE 日志，减少字符串格式化和输出开销。

```json
{
    "logging": {
        "level": "INFO",
        "enable_console": true,
        "enable_file": false,
        "enable_memory_sink": false
    }
}
```

| 级别 | 用途 | 建议环境 |
|------|------|---------|
| VERBOSE | 逐帧细节 | 开发调试 |
| DEBUG | 调试信息 | 开发测试 |
| INFO | 关键流程节点 | 所有环境 |
| WARNING | 潜在问题 | 所有环境 |
| ERROR | 错误和异常 | 所有环境 |

```gdscript
# 按级别输出日志
_log.verbose("Movement", "pos=(%f, %f) vel=(%f, %f)" % [x,y,vx,vy])  # 仅开发
_log.debug("AI", "决策结果: %s" % decision)                              # 仅开发
_log.info("Game", "开始新游戏")                                          # 始终输出
_log.warning("Save", "存档版本较旧，将执行迁移")                         # 始终输出
_log.error("Network", "连接超时: %d ms" % elapsed)                       # 始终输出
```

---

## 线程任务适度使用

### 使用线程的场景

| 适合线程 | 不适合线程 |
|---------|-----------|
| 路径搜索（A*） | ECS World 写入 |
| 地图生成（噪声算法） | Node 操作 |
| 数据序列化 | UI 更新 |
| 加密/解密 | 资源加载 |
| 大批量数学计算 | 简单数学运算（<1ms） |

### 线程池配置

```json
{
    "threading": {
        "enabled": true,
        "max_active_jobs": 4,
        "max_dispatch_per_tick": 2,
        "default_timeout_ms": 30000,
        "slow_job_warn_ms": 350,
        "history_limit": 256
    }
}
```

- `max_active_jobs`：一般设为 CPU 核心数减 1。
- `max_dispatch_per_tick`：每帧最多启动 2 个新任务，避免一帧内过多。
- `slow_job_warn_ms`：超过此阈值的任务会输出警告。

---

## UI 面板缓存策略

面板的 `close_strategy` 决定关闭后的行为，合理选择减少实例化开销。

| 策略 | 行为 | 适用场景 |
|------|------|---------|
| `HIDE_ON_CLOSE` | close 时 hide，下次打开复用实例 | 频繁开关的面板（背包、设置、商店） |
| `DESTROY_ON_CLOSE` | close 时 queue_free | 一次性面板（确认框、提示弹窗） |
| `PERSISTENT` | 普通 close 拒绝 | HUD、用户信息、小地图 |

```gdscript
# 面板定义中设置
{
    "panel_name": "Inventory",
    "close_strategy": "HIDE_ON_CLOSE",  # 缓存复用，避免重复实例化
    "preload": true  # 首次需要时创建，之后 hide/show
}
```

---

## 内存管理

### 避免泄漏的 checklist

- [ ] `_on_dispose()` 中取消所有 EventBus 订阅（`clear_scope`）
- [ ] `_on_dispose()` 中注销 Scheduler 回调
- [ ] `_on_dispose()` 中注销 ISaveable
- [ ] 面板关闭后不持有强引用（使用 WeakRef）
- [ ] 对象池在服务释放时清空
- [ ] 子线程任务按标签取消（`cancel_by_tag`）
- [ ] ECB 使用后不持有引用（apply 后重建）

### 大资源管理

- 使用 `GF_ResourceService` 的 LRU 缓存管理加载的资源
- 场景切换时清理上一场景的独有资源
- 音频、贴图等大资源使用异步加载

```gdscript
# 场景切换时清理旧资源
func on_world_switch(p_old_root: Node, p_new_root: Node) -> void:
    # 注销旧世界的 saveable
    save_service.on_world_switch(p_old_root, p_new_root, "world.")

    # 释放旧世界专用资源
    resource.clear_tag("world_specific")
```

---

## 性能检查清单

在发布前检查以下项：

- [ ] ECS 查询已缓存（不每帧创建 Query 对象）
- [ ] 低频逻辑使用 INTERVAL TickGroup
- [ ] 高频创建/销毁的对象使用对象池
- [ ] 生产环境日志级别设为 INFO 或以上
- [ ] 线程任务设置合理超时
- [ ] UI 面板策略正确（频繁开关用 HIDE_ON_CLOSE）
- [ ] 子线程任务不访问 Node/World/UI
- [ ] 组件实现了 serialize/deserialize
- [ ] 大资源有 LRU 回收机制
- [ ] 场景切换时有资源清理
