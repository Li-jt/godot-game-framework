# 诊断工具使用指南

## 概述

godot-game-framework 提供多种运行时诊断工具，帮助你在开发和调试阶段快速定位问题。

---

## DebugService 运行时统计

### 启用调试面板

```json
{
    "debug": {
        "enable_debug_panel": true,
        "show_prediction_state": false
    }
}
```

启用后，框架自动创建调试面板，显示 FPS、帧时间等统计信息。

### 查看 FPS 和帧时间

```gdscript
var fps: float = debug.fps
var frame_time: float = debug.frame_time_ms

# 在自定义 HUD 中显示
func _update_hud() -> void:
    fps_label.text = "FPS: %d" % int(debug.fps)
    frame_label.text = "Frame: %.1f ms" % debug.frame_time_ms
```

### 注册自定义调试面板

```gdscript
# 注册自定义调试面板
debug.register_panel("ECS Stats", func() -> Node:
    var panel := Control.new()
    # ... 创建调试控件 ...
    return panel
)

# 获取已注册的面板列表
var panels := debug.get_panel_names()
for name in panels:
    print("调试面板: %s" % name)
```

---

## command_history 追踪命令

DebugService 的命令追踪功能记录最近的命令执行历史，帮助回溯问题。

### 启用命令追踪

```json
{
    "debug": {
        "show_prediction_state": true
    }
}
```

### 查看命令历史

```gdscript
# command_history 是一个 Array[Dictionary]
# 每个元素包含: command_type, timestamp, result, context

for entry in debug._command_history:
    print("[%s] %s → %s" % [
        entry.get("timestamp", ""),
        entry.get("command_type", ""),
        entry.get("result", ""),
    ])
```

### 在调试面板中添加命令历史视图

```gdscript
func _create_command_history_panel() -> Node:
    var panel := VBoxContainer.new()
    var title := Label.new()
    title.text = "Command History"
    panel.add_child(title)

    var list := ItemList.new()
    for entry in debug._command_history:
        var text := "[%s] %s" % [entry.get("command_type", ""), entry.get("result", "")]
        list.add_item(text)
    panel.add_child(list)

    return panel

debug.register_panel("Commands", _create_command_history_panel)
```

---

## LogService MemoryLogSink 运行时日志

MemoryLogSink 在内存中保留最近的日志记录，方便开发时查看。

### 启用 MemoryLogSink

```json
{
    "logging": {
        "level": "DEBUG",
        "enable_memory_sink": true
    }
}
```

### 查看内存日志

```gdscript
# GF_MemoryLogSink 保留最近 N 条日志记录
# 通过 GF_LogService 访问

# 在自定义调试面板中显示
func _create_log_panel(p_log: GF_LogService) -> Node:
    var panel := VBoxContainer.new()
    var title := Label.new()
    title.text = "Runtime Log"
    panel.add_child(title)

    var scroll := ScrollContainer.new()
    var log_text := RichTextLabel.new()
    log_text.bbcode_enabled = true
    log_text.fit_content = true

    # 获取日志记录并格式化
    # (具体 API 取决于 GF_LogService 的实现)

    scroll.add_child(log_text)
    panel.add_child(scroll)
    return panel
```

### 日志级别过滤

```gdscript
# 在运行时动态调整日志级别
# 调试时开启 VERBOSE，发现问题后切换回 INFO
# 具体 API 取决于 GF_LogService 的配置接口
```

---

## ECS RuntimeBridge 检查 ECS 状态

`GF_EcsRuntimeBridge` 提供运行时查看 ECS 内部状态的能力。

### 查看实体数量

```gdscript
var bridge: GF_EcsRuntimeBridge = ecs_world.get_runtime_bridge()
if bridge != null:
    print("实体总数: %d" % bridge.entity_count())
```

### 查看实体组件

```gdscript
# 检查特定实体的组件列表
var entity := 42
var component_types := world.get_entity_component_types(entity)
for type_name in component_types:
    var data = world.get_component(entity, type_name)
    print("  %s: %s" % [type_name, str(data)])
```

### 查看存储统计

```gdscript
# 查看各组件类型的存储使用情况
var registry: GF_EcsComponentTypeRegistry = world._get_registry()
for type_name in registry.all_types():
    var tid: int = registry.type_id_of(type_name)
    var count := world.component_count(tid)
    print("组件类型 %s: %d 个实体" % [type_name, count])
```

---

## 线程服务统计

### 查看线程池状态

```gdscript
var stats := threading.get_stats()
print("=== 线程服务统计 ===")
print("已提交: %d" % stats["submitted"])
print("已完成: %d" % stats["completed"])
print("已失败: %d" % stats["failed"])
print("已取消: %d" % stats["cancelled"])
print("已超时: %d" % stats["timed_out"])
print("平均耗时: %.1f ms" % stats["avg_duration_ms"])
print("队列峰值: %d" % stats["queue_peak"])
print("运行峰值: %d" % stats["running_peak"])
```

### 查看最近任务

```gdscript
var recent := threading.get_recent_history(10)
for s in recent:
    var duration := s.duration_ms()
    var status_color := "[color=green]" if s.state == GF_ThreadJobState.Value.COMPLETED else "[color=red]"
    print("%s%s[/color] %s: %d ms" % [status_color, s.status_text(), s.name, duration])
```

---

## Godot 内置调试工具集成

### Godot 编辑器调试器

在编辑器中运行项目时，Godot 提供以下调试工具：

- **Debugger 面板**：查看场景树、脚本远程调试
- **Profiler**：CPU/GPU 帧分析
- **Monitor**：内存、网络、物理统计

框架与这些工具兼容，所有服务操作都可以在 Godot 调试器中跟踪。

### 命令行无头模式调试

```bash
# 无头运行 + 详细日志
godot --headless --verbose -s main.gd

# 查看日志输出
godot --headless --path . -s main.gd 2>&1 | grep -E "ERROR|WARNING"
```

### 脚本断点调试

在 GDScript 中使用 `breakpoint` 关键字：

```gdscript
func debug_entity(p_entity: int) -> void:
    if p_entity == 42:  # 可疑的实体 ID
        breakpoint  # 在此处暂停执行
    # ... 正常逻辑
```

---

## 自定义诊断命令

### 在调试面板中添加诊断按钮

```gdscript
func _register_debug_actions(p_debug: GF_DebugService) -> void:
    # 注册一个"打印 ECS 状态"的调试面板
    p_debug.register_panel("ECS Inspector", func() -> Node:
        var panel := VBoxContainer.new()

        var btn_dump := Button.new()
        btn_dump.text = "Dump All Entities"
        btn_dump.pressed.connect(func():
            _dump_all_entities()
        )
        panel.add_child(btn_dump)

        var btn_stats := Button.new()
        btn_stats.text = "Memory Stats"
        btn_stats.pressed.connect(func():
            _print_memory_stats()
        )
        panel.add_child(btn_stats)

        return panel
    )


func _dump_all_entities() -> void:
    var world: GF_EcsWorld = services.ecs_world
    var entities := world.all_entities()
    _log.info("Debug", "=== ECS 实体转储 (%d) ===" % entities.size())
    for entity in entities:
        _log.info("Debug", "  实体 %d:" % entity)
        for type_name in world.get_entity_component_types(entity):
            var data = world.get_component(entity, type_name)
            _log.info("Debug", "    %s: %s" % [type_name, str(data)])


func _print_memory_stats() -> void:
    var stats := Performance.get_monitor(Performance.OBJECT_COUNT)
    var memory := Performance.get_monitor(Performance.MEMORY_STATIC)
    _log.info("Debug", "对象总数: %d, 静态内存: %.1f MB" % [stats, memory / 1048576.0])
```

---

## 诊断工作流

### 问题排查路径

```
发现问题
  │
  ├─ 查看日志输出 → LogService (MemoryLogSink)
  │
  ├─ 查看 FPS/帧时间 → DebugService
  │
  ├─ 查看 ECS 状态 → RuntimeBridge / ECS Inspector
  │     ├─ 实体数量是否异常？
  │     ├─ 组件数据是否正确？
  │     └─ 系统执行顺序是否正确？
  │
  ├─ 查看输入状态 → InputService
  │     ├─ 当前哪些动作被按下？
  │     └─ 输入上下文栈状态？
  │
  ├─ 查看 UI 状态 → UIService
  │     ├─ 当前打开了哪些面板？
  │     └─ 面板输入阻挡状态？
  │
  ├─ 查看线程状态 → ThreadingService.get_stats()
  │
  └─ 查看 EventBus 状态
        └─ 监听者数量是否异常？
```

### 常见诊断命令速查

```gdscript
# ECS
world.all_entities().size()              # 实体总数
world.has_entity(id)                     # 实体是否存在
world.get_version()                      # 当前世界版本

# 输入
input.get_all_action_ids()               # 所有注册的动作
input.is_pressed("action_id")            # 动作是否按下

# 存档
save_service.list_slots()                # 所有存档槽位

# 线程
threading.get_stats()                    # 统计快照
threading.get_recent_history(20)         # 最近任务

# 事件
event_bus.listener_count("event_name")   # 某事件监听者数
event_bus.token_count()                  # 总订阅数

# 服务注册
registry.count()                         # 已注册服务数
registry.has("key")                      # 指定服务是否存在

# 日志
log.info("Debug", "消息")                # 输出日志
log.error("Debug", "错误消息")           # 输出错误
```
