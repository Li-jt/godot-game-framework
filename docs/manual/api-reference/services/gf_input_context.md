# GF_InputContext / GF_InputPolicy

> 适用版本: 0.3.0 | 继承: GF_InputContext → RefCounted, GF_InputPolicy → RefCounted

## 概述

`GF_InputContext` 是输入上下文，压入 `GF_InputService` 的上下文栈后限制当前可用的动作集合。它是**动作级过滤**的核心机制：通过白名单或黑名单控制哪些动作在当前上下文中生效。

`GF_InputPolicy` 是统一的动作级过滤判定层，合并三方面信息：**Context 上下文栈 + UI Panel 输入阻挡 + allowlist**。由 `GF_InputService` 内部创建和管理，游戏层通常不直接使用。核心原则是**按 action 级别判定**，不按 event 级别。

**核心规则**：

- `allowed_actions` **为空**：所有已注册动作放行（默认 gameplay 模式）
- `allowed_actions` **非空**：只有列表中的动作生效（白名单模式）
- `blocked_action_ids`：仅在 `allowed_actions` 为空时生效（黑名单模式）。含 `"*"` 等效于 `block_all_game_actions = true`
- `block_all_game_actions`：设为 `true` 则禁止所有游戏动作，优先级高于 `allowed_actions`

**判定优先级**（`is_action_blocked()` 内部顺序）：

1. Context allow 命中 -- 永不阻挡
2. Context block 命中 -- 阻挡
3. UI ALWAYS 面板命中 action -- 阻挡
4. 空间事件 + POINTER_ONLY 面板命中区域 + action 在 blocked 列表 -- 阻挡

## GF_InputContext

纯数据对象，无公共方法。所有行为由 `GF_InputPolicy` 读取属性后执行。

### 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| `name` | `String` | `""` | 上下文名称，用于调试标识 |
| `priority` | `int` | `0` | 优先级，数字越大越优先 |
| `allowed_actions` | `Array[String]` | `[]` | 允许的动作 ID 白名单。空数组 = 放行所有已注册动作 |
| `blocked_action_ids` | `Array[String]` | `[]` | 被屏蔽的动作 ID 黑名单。仅当 `allowed_actions` 为空时生效。含 `"*"` 等效于 `block_all_game_actions = true` |
| `block_all_game_actions` | `bool` | `false` | 设为 `true` 则禁止所有游戏动作，优先级高于 `allowed_actions` |

### 使用示例

```gdscript
# 暂停菜单：只允许 UI 动作
var pause_ctx := GF_InputContext.new()
pause_ctx.name = "pause_menu"
pause_ctx.priority = 200
pause_ctx.allowed_actions = ["ui_accept", "ui_cancel", "ui_navigate"]
input_service.push_context(pause_ctx)

# 文本输入：完全禁止游戏动作（黑名单模式）
var text_ctx := GF_InputContext.new()
text_ctx.name = "text_input"
text_ctx.priority = 300
text_ctx.blocked_action_ids = ["*"]  # 禁止所有

# 文本输入：完全禁止游戏动作（全局阻挡模式）
var text_ctx2 := GF_InputContext.new()
text_ctx2.name = "text_input"
text_ctx2.priority = 300
text_ctx2.block_all_game_actions = true

# 关闭上下文，恢复 gameplay
input_service.pop_context()
```

## GF_InputPolicy

`GF_InputPolicy` 由 `GF_InputService` 内部创建和管理，游戏层通常不直接使用。需要调试时可通过 `get_block_reason()` 查看阻挡原因。内部维护上下文栈 `_context_stack` 和 `GF_UIService` 引用，通过私有方法 `_context_allows()`、`_context_blocks()`、`_ui_always_blocks()`、`_ui_pointer_blocks()` 逐层判定。

### set_ui_service(p_ui) -> void

注入 `GF_UIService` 引用，用于查询活跃面板的输入阻挡配置。

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_ui` | `GF_UIService` | UI 服务实例 |

### get_context_stack() -> Array[GF_InputContext]

获取当前上下文栈引用。由 `GF_InputService.push_context()` / `pop_context()` 操作。

**返回值：** `Array[GF_InputContext]`，上下文栈引用。

### is_action_blocked(p_action_id: String, _p_event: InputEvent, p_pointer_pos: Vector2) -> bool

判定指定动作是否被阻挡。按以下顺序逐层判定，任一层命中即返回：

1. Context allow 命中（上下文中 `allowed_actions` 包含该 action）-- 返回 `false`（永不阻挡）
2. Context block 命中（`block_all_game_actions` 为 `true` 或 `blocked_action_ids` 包含该 action）-- 返回 `true`
3. UI ALWAYS 面板命中（有 `input_block_mode = ALWAYS` 的面板且其 `blocked_action_ids` 包含该 action）-- 返回 `true`
4. 空间事件 + POINTER_ONLY 面板命中区域（指针在面板的阻挡区域内，且 `blocked_action_ids` 包含该 action）-- 返回 `true`

**拖拽例外：** 当 `GF_UIService.is_dragging()` 为 `true` 时，UI 面板的子步骤 3 和 4 不触发阻挡。

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_action_id` | `String` | 动作 ID |
| `_p_event` | `InputEvent` | 原始 Godot 事件（当前未使用，预留） |
| `p_pointer_pos` | `Vector2` | 指针位置。非空间事件传入 `Vector2.INF` |

**返回值：** `bool`，被阻挡返回 `true`，放行返回 `false`。

### is_action_blocked_raw(p_action_id: String, p_is_spatial: bool, p_pointer_pos: Vector2) -> bool

同 `is_action_blocked()`，但不接收 `InputEvent` 对象，直接接收布尔标志。用于不需要原始事件的场景（如输入重放、模拟输入）。

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_action_id` | `String` | 动作 ID |
| `p_is_spatial` | `bool` | 是否为空间事件（需要检查鼠标位置） |
| `p_pointer_pos` | `Vector2` | 指针位置 |

**返回值：** `bool`，被阻挡返回 `true`。

### get_block_reason(p_action_id: String, p_is_spatial: bool, p_pointer_pos: Vector2) -> String

获取动作被阻挡的原因，用于调试。判定逻辑与 `is_action_blocked_raw()` 相同，但返回人类可读的字符串而不是布尔值。

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_action_id` | `String` | 动作 ID |
| `p_is_spatial` | `bool` | 是否为空间事件 |
| `p_pointer_pos` | `Vector2` | 指针位置 |

**返回值：** `String`，阻挡原因：

| 返回值 | 含义 |
|--------|------|
| `"context_allow"` | 上下文白名单放行（不阻挡） |
| `"context_block"` | 上下文黑名单/全局阻挡 |
| `"ui_always"` | UI 面板 `ALWAYS` 模式阻挡 |
| `"ui_pointer"` | UI 面板 `POINTER_ONLY` 模式阻挡 |
| `""` | 未被阻挡（空字符串） |

## See Also

- [GF_InputService](./gf_input_service.md) -- 输入服务，管理上下文栈和策略判定
- [GF_UIPanelDef](./gf_ui_panel_def.md) -- 面板定义，定义 `input_block_mode` 和 `blocked_action_ids`
- [GF_UIService](./gf_ui_service.md) -- UI 服务，面板输入阻挡依赖其状态
