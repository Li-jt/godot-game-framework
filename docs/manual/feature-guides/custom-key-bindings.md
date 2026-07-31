# 自定义按键绑定

## 场景描述

玩家希望能重新绑定按键——将"跳跃"从空格键改成 W 键，或为同一动作设置备用按键。框架的 `GF_InputRebindService` 提供了一套完整的改键工作流：开始监听、处理输入事件、保存/加载配置、重置默认值。

本章覆盖：开始和取消改键、处理按键事件、保存和加载绑定、冲突策略、完整的键位设置面板示例。

---

## 最小示例

```gdscript
# 开始监听"jump"动作的 primary 槽位
if input_service.begin_rebind("jump", GF_InputBinding.Slot.PRIMARY):
    print("请按下新按键...")

# 在 _input 中转发事件（由 GF_InputRouter 自动完成）
# 框架内部会调用 input_service.handle_event_for_rebind(event)
# 当玩家按下有效按键后，rebind 自动完成

# 保存到文件
input_service.save_bindings("user://keybindings.tres")

# 加载
input_service.load_bindings("user://keybindings.tres")

# 重置单个动作为默认
input_service.reset_action_to_default("jump")
```

---

## 逐步解释

### 第一步：开始改键监听

```gdscript
var success := input_service.begin_rebind("jump", GF_InputBinding.Slot.PRIMARY)
if not success:
    _log.warning("Input", "该动作不可重绑定或不存在")
```

`begin_rebind(action_id, slot)` 返回 `bool`：
- 返回 `true`：已进入监听状态，等待玩家按键
- 返回 `false`：动作不存在，或该动作的 `rebindable = false`

`slot` 取值：
- `GF_InputBinding.Slot.PRIMARY`（0）：主按键槽位
- `GF_InputBinding.Slot.SECONDARY`（1）：备用按键槽位

每个动作最多两个绑定槽位（primary + secondary），`apply_binding` 会先移除同 slot 的旧绑定再添加新的。

### 第二步：处理按键事件

框架的 `GF_InputRouter._input` 方法中已自动集成了改键检测：

```gdscript
# GF_InputRouter 的内部逻辑（框架已实现，无需手动调用）：
func _input(p_event: InputEvent) -> void:
    if _resolver != null:
        # 优先检查是否在改键等待中
        _resolver._rebind.handle_event_for_rebind(p_event)
        # 再处理正常输入
        _resolver.feed_event(p_event)
```

`handle_event_for_rebind` 的处理流程：
1. 检查是否在等待中（`_waiting == true`）
2. 过滤事件类型：只接受 `InputEventKey`、`InputEventMouseButton`、`InputEventJoypadButton`
3. 排除滚轮事件（`MOUSE_BUTTON_WHEEL_UP/DOWN` 不作为重绑定目标）
4. 通过 `can_bind_event_to_action` 校验设备约束
5. 根据事件类型自动判断 `Mode`（键盘按键 → `HELD`，鼠标/手柄按钮 → `IMPULSE`）
6. 调用 `apply_binding` 写入绑定
7. 设置 `_waiting = false` 并发射 `rebind_changed` 信号

### 第三步：设备约束校验

`can_bind_event_to_action` 会根据动作的 `device_constraint` 校验事件是否合法：

| DeviceConstraint | 接受的输入源 |
|-----------------|-------------|
| `ANY` | 全部接受 |
| `KEYBOARD_ONLY` | 仅 `InputEventKey` |
| `MOUSE_ONLY` | 仅鼠标按钮/滚轮 |
| `KEYBOARD_MOUSE` | 键盘或鼠标 |
| `GAMEPAD_ONLY` | 仅手柄按钮 |

```gdscript
# 定义时设置设备约束，防止玩家将游戏手柄按键绑定到仅键盘的动作
var move := GF_InputActionDef.new("move", GF_InputActionDef.ActionType.AXIS_2D)
    .set_device_constraint(GF_InputActionDef.DeviceConstraint.KEYBOARD_MOUSE)
    .set_rebindable(true)
```

### 第四步：取消改键

```gdscript
input_service.cancel_rebind()
```

玩家按 ESC 或关闭设置面板时应取消改键，让系统回到正常输入模式。`cancel_rebind` 仅设置 `_waiting = false`，不会修改动作的绑定。

检查是否在等待中：
```gdscript
if input_service.is_waiting_rebind():
    show_rebind_prompt()
```

### 第五步：保存和加载绑定配置

```gdscript
# 保存当前所有动作的绑定到 .tres 文件（Resource 格式）
var saved := input_service.save_bindings("user://input_bindings_v1.tres")
if saved:
    _log.info("Input", "按键配置已保存")

# 启动时加载
var loaded := input_service.load_bindings("user://input_bindings_v1.tres")
if loaded:
    _log.info("Input", "按键配置已加载")
else:
    _log.info("Input", "未找到按键配置，使用默认绑定")
```

保存格式为 Godot `Resource`（.tres），内部使用 `GF_InputBindingConfig` 类，序列化所有动作的 primary/secondary 绑定。

### 第六步：重置为默认

```gdscript
var reset := input_service.reset_action_to_default("jump")
if reset:
    _log.info("Input", "jump 已重置为默认绑定")
```

`reset_action_to_default` 会：
1. 清空当前所有绑定
2. 从 `default_bindings` 深拷贝恢复到 `bindings`
3. 发射 `rebind_changed` 信号（`slot = -1` 表示重置）

### 第七步：ConflictPolicy 冲突策略

`GF_InputRebindService` 有三个冲突策略枚举（当前版本中 `apply_binding` 默认使用 `REPLACE` 行为——移除同 slot 旧绑定）：

| 策略 | 行为 |
|------|------|
| `ALLOW` | 允许同一按键绑定到多个动作 |
| `WARN` | 检测到冲突时返回警告但不阻止 |
| `REPLACE` | 检测到冲突时从旧动作中移除该绑定（当前默认行为） |

可通过直接访问 `_rebind` 对象设置：
```gdscript
# 获取 rebind 服务引用（需要框架暴露，或通过 _policy 间接访问）
```

---

## 完整示例：键位设置面板

```gdscript
# ---- keybindings_panel.gd ----
class_name KeybindingsPanel
extends GF_UIPanel

const ACTION_CATEGORIES := {
    "移动": ["move_right", "move_left", "move_up", "move_down", "sprint"],
    "战斗": ["shoot", "reload", "melee"],
    "UI": ["ui_accept", "ui_cancel"],
}

var _pending_action: String = ""
var _pending_slot: int = -1
var _rebind_buttons: Dictionary = {}  # String "action_id|slot" → Button


func _on_open(_p_data: Dictionary) -> void:
    _build_ui()


func _build_ui() -> void:
    var input := ctx.input as GF_InputService
    var container := $ScrollContainer/VBoxContainer

    for category in ACTION_CATEGORIES.keys():
        var cat_label := Label.new()
        cat_label.text = category
        container.add_child(cat_label)

        for action_id in ACTION_CATEGORIES[category]:
            var row := HBoxContainer.new()
            var name_label := Label.new()
            var def := input.get_action_def(action_id)
            name_label.text = def.display_name if def != null else action_id
            row.add_child(name_label)

            # Primary 按钮
            var primary_btn := _create_rebind_button(action_id, GF_InputBinding.Slot.PRIMARY)
            row.add_child(primary_btn)

            # Secondary 按钮
            var secondary_btn := _create_rebind_button(action_id, GF_InputBinding.Slot.SECONDARY)
            row.add_child(secondary_btn)

            # 重置按钮
            var reset_btn := Button.new()
            reset_btn.text = "重置"
            reset_btn.pressed.connect(_on_reset_pressed.bind(action_id))
            row.add_child(reset_btn)

            container.add_child(row)


func _create_rebind_button(p_action_id: String, p_slot: int) -> Button:
    var btn := Button.new()
    var key := "%s|%d" % [p_action_id, p_slot]
    _rebind_buttons[key] = btn
    _update_button_text(p_action_id, p_slot, btn)
    btn.pressed.connect(_on_rebind_pressed.bind(p_action_id, p_slot))
    return btn


func _update_button_text(p_action_id: String, p_slot: int, p_btn: Button) -> void:
    var input := ctx.input as GF_InputService
    var def := input.get_action_def(action_id)
    if def == null:
        p_btn.text = "—"
        return
    for binding in def.bindings:
        if binding.slot == p_slot:
            p_btn.text = _binding_display_name(binding)
            return
    p_btn.text = "未绑定"


func _binding_display_name(p_binding: GF_InputBinding) -> String:
    match p_binding.source:
        GF_InputBinding.Source.KEYBOARD:
            return OS.get_keycode_string(p_binding.code)
        GF_InputBinding.Source.MOUSE_BUTTON:
            return "鼠标 %d" % p_binding.code
        GF_InputBinding.Source.GAMEPAD_BUTTON:
            return "手柄 %d" % p_binding.code
    return "未知"


func _on_rebind_pressed(p_action_id: String, p_slot: int) -> void:
    var input := ctx.input as GF_InputService
    _pending_action = p_action_id
    _pending_slot = p_slot

    var success := input.begin_rebind(p_action_id, p_slot)
    if not success:
        ctx.log.warning("Input", "无法开始改键: %s" % p_action_id)
        return

    # 将按钮文字改为"等待按键..."
    var key := "%s|%d" % [p_action_id, p_slot]
    if _rebind_buttons.has(key):
        _rebind_buttons[key].text = "..."


func _on_reset_pressed(p_action_id: String) -> void:
    var input := ctx.input as GF_InputService
    input.reset_action_to_default(p_action_id)
    _refresh_all_buttons()


func _refresh_all_buttons() -> void:
    for key in _rebind_buttons.keys():
        var parts := key.split("|")
        var action_id := parts[0]
        var slot := int(parts[1])
        _update_button_text(action_id, slot, _rebind_buttons[key])


# ---- 在 GF_InputRouter 中需要连接 rebind_changed 信号来刷新 UI ----

func _on_open(_p_data: Dictionary) -> void:
    _build_ui()
    # 监听改键完成
    var input := ctx.input as GF_InputService
    # 通过 rebind service 信号刷新（需要框架支持）
    # 替代方案：在 _process 中轮询 is_waiting_rebind 变化
    _pending_action = ""


func _process(_delta: float) -> void:
    var input := ctx.input as GF_InputService
    if _pending_action != "" and not input.is_waiting_rebind():
        # 改键已完成（或取消）
        _pending_action = ""
        _pending_slot = -1
        _refresh_all_buttons()


# ---- 保存配置（在设置面板关闭时） ----

func _on_close() -> void:
    var input := ctx.input as GF_InputService
    input.save_bindings("user://input_bindings_v1.tres")
    ctx.log.info("Input", "按键配置已保存")


# ---- 启动时加载配置 ----

# 在 GameBootstrap 中：
func _load_input_bindings(input_service: GF_InputService) -> void:
    input_service.load_bindings("user://input_bindings_v1.tres")
```

---

## 常见变体

### 变体 1：改键时显示提示覆盖层

```gdscript
func _on_rebind_pressed(p_action_id: String, p_slot: int) -> void:
    # 显示全屏半透明覆盖，提示"请按下新按键...ESC 取消"
    $RebindOverlay.show()
    $RebindOverlay/Label.text = "为 [%s] 设置新按键...按 ESC 取消" % p_action_id
    input_service.begin_rebind(p_action_id, p_slot)
```

### 变体 2：读取并展示当前绑定名称

```gdscript
func get_binding_display(p_action_id: String, p_slot: int) -> String:
    var def := input_service.get_action_def(p_action_id)
    if def == null: return "—"
    for b in def.bindings:
        if b.slot == p_slot:
            return _format_binding(b)
    return "未绑定"

func _format_binding(b: GF_InputBinding) -> String:
    match b.source:
        GF_InputBinding.Source.KEYBOARD: return OS.get_keycode_string(b.code)
        GF_InputBinding.Source.MOUSE_BUTTON:
            match b.code:
                MOUSE_BUTTON_LEFT: return "左键"
                MOUSE_BUTTON_RIGHT: return "右键"
                MOUSE_BUTTON_MIDDLE: return "中键"
                _: return "鼠标%d" % b.code
        GF_InputBinding.Source.GAMEPAD_BUTTON:
            match b.code:
                JOY_BUTTON_A: return "A"
                JOY_BUTTON_B: return "B"
                _: return "手柄%d" % b.code
    return "?"
```

### 变体 3：检测并提示冲突

```gdscript
func find_conflicts(p_action_id: String, p_new_binding: GF_InputBinding) -> Array[String]:
    var conflicts: Array[String] = []
    for other_id in input_service.get_all_action_ids():
        if other_id == p_action_id: continue
        var def := input_service.get_action_def(other_id)
        for b in def.bindings:
            if b.source == p_new_binding.source and b.code == p_new_binding.code:
                conflicts.append(other_id)
    return conflicts
```

---

## 错误码

| 方法 | 返回值 | 失败情况 |
|------|--------|---------|
| `begin_rebind` | `bool` | `false` = 动作不存在或 `rebindable = false` |
| `cancel_rebind` | `void` | 总是成功 |
| `is_waiting_rebind` | `bool` | 永远有效 |
| `handle_event_for_rebind` | `bool` | `false` = 事件未被消费（不在等待中或事件类型不支持） |
| `save_bindings` | `bool` | `false` = ResourceSaver.save 失败 |
| `load_bindings` | `bool` | `false` = 文件不存在或格式错误（ResourceLoader.load 返回 null） |
| `reset_action_to_default` | `bool` | `false` = 动作不存在 |

---

## See Also

- [处理玩家输入](./handle-player-input.md) -- 动作定义和绑定配置
- [创建和管理 UI 面板](./create-ui-panels.md) -- 设置面板的创建和管理
- [实现游戏存档](./save-game-progress.md) -- 将按键配置作为存档的一部分保存
