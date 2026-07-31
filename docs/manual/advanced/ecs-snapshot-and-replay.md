# ECS 快照与回放

## 概述

ECS 快照系统允许你捕获某个时刻的完整 ECS 世界状态（所有实体、组件、组件类型注册信息），并可序列化为 Dictionary 用于存储或网络传输。主要用途包括：

- **存档**：将 ECS 世界序列化到存档文件中
- **回放**：录制关键帧快照，事后逐帧回放游戏过程
- **调试**：保存问题发生时的世界状态以供离线分析
- **回滚预测**：Hybrid 模式下，客户端预测失败后回滚到服务端确认的状态

## 核心类

| 类 | 职责 |
|---|------|
| `GF_EcsWorldSnapshot` | 可序列化快照数据容器 |
| `GF_EcsSnapshotBuilder` | 从 ECS World 构建快照 |
| `GF_EcsSnapshotApplier` | 将快照恢复到 ECS World |
| `GF_EcsComponentFactory` | 从序列化数据重建组件实例 |
| `GF_EcsSaveAdapter` | 将 ECS 系统接入 GF_SaveService 的适配器 |

## SnapshotBuilder 构建快照

`GF_EcsSnapshotBuilder.build(world)` 遍历指定世界中的所有实体和组件，调用组件的 `serialize()` 方法（如果存在），构建一个完整的 `GF_EcsWorldSnapshot`。

```gdscript
var builder := GF_EcsSnapshotBuilder.new()
var snapshot: GF_EcsWorldSnapshot = builder.build(ecs_world)

# 快照包含：
# - version: 世界版本号
# - timestamp: 快照创建时间戳
# - component_registry: 组件类型注册表
# - entities: 全部实体及其组件数据
```

### 组件序列化要求

要被快照包含的组件需要实现 `serialize()` 方法：

```gdscript
class_name PositionComponent
extends GF_EcsComponentBase

var x: float = 0.0
var y: float = 0.0

func serialize() -> Dictionary:
    return {"x": x, "y": y}

func deserialize(p_data: Dictionary) -> void:
    x = p_data.get("x", 0.0)
    y = p_data.get("y", 0.0)
```

如果组件没有 `serialize()` 方法，`SnapshotBuilder` 会尝试降级序列化基础类型（Dictionary、Array 等）。

## SnapshotApplier 应用快照

`GF_EcsSnapshotApplier.apply(world, snapshot, factory)` 将快照恢复到指定世界：

1. 先清空当前世界（`world.reset()`）
2. 恢复组件类型注册表
3. 逐实体重建，通过 `GF_EcsComponentFactory` 重建组件实例

```gdscript
var applier := GF_EcsSnapshotApplier.new()
var factory := _create_component_factory()
var result := applier.apply(ecs_world, snapshot, factory)
if result.is_fail():
    _log.error("Snapshot", "快照恢复失败: %s" % result.error.message)
```

### 组件工厂

`GF_EcsComponentFactory` 负责从序列化数据创建组件实例：

```gdscript
var factory := GF_EcsComponentFactory.new()
factory.register(&"Position", func(data: Dictionary) -> GF_EcsComponentBase:
    var comp := PositionComponent.new()
    comp.deserialize(data)
    return comp
)
factory.register(&"Health", func(data: Dictionary) -> GF_EcsComponentBase:
    var comp := HealthComponent.new()
    comp.deserialize(data)
    return comp
)
```

## 增量快照 vs 全量快照

### 全量快照

保存当前世界的完整状态。适合存档和关键帧录制。

```gdscript
# 全量快照：保存整个世界
func save_full_snapshot() -> GF_EcsWorldSnapshot:
    return GF_EcsSnapshotBuilder.new().build(_world)
```

### 增量快照

只记录从上一帧以来的变化（spawn/despawn/组件变更）。适合回放和网络同步。

原理：利用 ECS World 的版本号和 CommandBuffer 记录，只序列化变更的实体和组件。

```gdscript
# 增量快照：只记录变化
func build_delta(p_world: GF_EcsWorld, p_prev_version: int) -> Dictionary:
    var delta := {
        "from_version": p_prev_version,
        "to_version": p_world.get_version(),
        "spawned": [],     # 新创建的实体
        "despawned": [],   # 销毁的实体
        "changed": {},     # {entity: {type_name: data}}
    }
    # ... 通过 ECS 的变更日志构建 delta ...
    return delta
```

## 完整示例：回放系统

```gdscript
# replay_system.gd
class_name ReplaySystem
extends RefCounted

enum State { IDLE, RECORDING, PLAYING }

var _state: State = State.IDLE
var _world: GF_EcsWorld = null
var _builder: GF_EcsSnapshotBuilder = null
var _applier: GF_EcsSnapshotApplier = null
var _factory: GF_EcsComponentFactory = null
var _frames: Array[GF_EcsWorldSnapshot] = []
var _playback_index: int = 0
var _playback_timer: float = 0.0
var _playback_interval: float = 1.0 / 30.0  # 30 FPS 回放


func configure(p_world: GF_EcsWorld) -> void:
    _world = p_world
    _builder = GF_EcsSnapshotBuilder.new()
    _applier = GF_EcsSnapshotApplier.new()
    _factory = _create_factory()


## 开始录制
func start_recording() -> void:
    _frames.clear()
    _state = State.RECORDING


## 每帧录制（在 ECS tick 之后调用）
func record_frame() -> void:
    if _state != State.RECORDING:
        return
    var snapshot := _builder.build(_world)
    _frames.append(snapshot)


## 停止录制
func stop_recording() -> GF_EcsWorldSnapshot:
    _state = State.IDLE
    if _frames.is_empty():
        return null
    return _frames.back()


## 开始回放
func start_playback(p_interval: float = 1.0 / 30.0) -> void:
    if _frames.is_empty():
        return
    _playback_index = 0
    _playback_timer = 0.0
    _playback_interval = p_interval
    _state = State.PLAYING
    # 加载第一帧
    _applier.apply(_world, _frames[0], _factory)


## 每帧更新回放（由 Scheduler 驱动）
func update_playback(p_delta: float) -> void:
    if _state != State.PLAYING:
        return
    _playback_timer += p_delta
    while _playback_timer >= _playback_interval and _playback_index < _frames.size():
        _playback_timer -= _playback_interval
        _playback_index += 1
        if _playback_index < _frames.size():
            _applier.apply(_world, _frames[_playback_index], _factory)
    if _playback_index >= _frames.size() - 1:
        _state = State.IDLE


func get_frame_count() -> int:
    return _frames.size()


func get_current_frame() -> int:
    return _playback_index


func _create_factory() -> GF_EcsComponentFactory:
    var factory := GF_EcsComponentFactory.new()
    # 注册所有需要重建的组件类型
    factory.register(&"Position", func(data):
        var comp := PositionComponent.new()
        comp.x = data.get("x", 0.0)
        comp.y = data.get("y", 0.0)
        return comp
    )
    factory.register(&"Health", func(data):
        var comp := HealthComponent.new()
        comp.current = data.get("current", 0)
        comp.maximum = data.get("maximum", 0)
        return comp
    )
    return factory
```

```gdscript
# 使用示例：在 Game 层驱动回放
func _on_post_boot(p_context: GF_GameServices) -> GF_OperationResult:
    _replay = ReplaySystem.new()
    _replay.configure(p_context.ecs_world)
    return GF_OperationResult.ok()


# 开始录制
func _on_start_recording() -> void:
    _replay.start_recording()
    # 每帧录制在 ECS tick 之后
    scheduler.register_frame_callback(_on_record_frame, "replay_record")


func _on_record_frame(_delta: float) -> void:
    _replay.record_frame()


# 回放
func _on_start_playback() -> void:
    scheduler.unregister_callback("replay_record")
    _replay.start_playback()
    scheduler.register_frame_callback(_replay.update_playback, "replay_playback")
```

## 预测回滚（RuntimeBridge）

`GF_EcsRuntimeBridge` 提供了 Hybrid 模式下预测回滚的基础设施。当客户端预测与服务器确认不一致时，框架执行以下步骤：

1. **保存预测前快照** — 在应用预测输入前保存世界状态
2. **执行预测** — 应用预测输入，推进世界状态
3. **收到服务器确认** — 比较预测结果与服务端确认
4. **如果不一致** — 回滚到快照，重新应用正确的输入

```gdscript
# 概念示例（框架内部实现，游戏层不直接调用）
# bridge.save_snapshot()     → 保存预测前状态
# bridge.rollback()          → 回滚到上一个快照
# bridge.reapply(inputs)     → 重新应用正确的输入序列
```

> **注意**：Remote/Hybrid 模式当前为预留实现。预测回滚的完整功能将在未来版本中提供。

## 存档集成

`GF_EcsSaveAdapter` 将 ECS 快照系统接入 GF_SaveService，使 ECS 数据与游戏其他存档数据统一管理：

```gdscript
# GF_EcsSaveAdapter 内部实现
func save_key() -> String:
    return "world.ecs"

func on_save() -> Dictionary:
    var snapshot := GF_EcsSnapshotBuilder.new().build(_world)
    return snapshot.to_dict()

func on_load(p_data: Dictionary) -> void:
    var snapshot := GF_EcsWorldSnapshot.new()
    snapshot.from_dict(p_data)
    GF_EcsSnapshotApplier.new().apply(_world, snapshot, _factory)
```

## 最佳实践

1. **大世界使用增量快照。** 全量快照的性能开销随实体数量线性增长。
2. **组件实现 serialize/deserialize。** 确保所有需要持久化的组件都有这两个方法。
3. **注册组件工厂。** 快照恢复需要工厂来重建组件实例。
4. **录制频率控制。** 回放系统不需要每帧都录入，可以按固定间隔（如每 3 帧）。
5. **快照数据压缩。** 大量快照帧会占用内存，考虑只存储关键帧 + 增量。
