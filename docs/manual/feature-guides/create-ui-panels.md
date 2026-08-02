# 创建和管理 UI 面板

## 场景描述

游戏需要各种 UI 面板：主菜单、设置面板、背包、弹窗、HUD、加载画面。框架的 UI 系统根据面板的"类型"将其实例化到对应的 Canvas 层，并根据"生命周期策略"控制关闭行为。

本章覆盖：定义面板、6 层 Canvas、4 种生命周期策略、打开/关闭/显隐面板、面板缓存和预热、单例模式。

---

## 最小示例

```gdscript
# 1. 定义面板
var main_menu_def := GF_UIPanelDef.new()
main_menu_def.name = "main_menu"
main_menu_def.path = "res://content/ui/main_menu.tscn"
main_menu_def.kind = GF_UIPanelDef.KIND_SCREEN
main_menu_def.lifecycle = GF_UIPanelDef.Lifecycle.PERSISTENT

# 2. 注册
ui_service.register(main_menu_def)

# 3. 打开
var result := ui_service.open("main_menu")
if result.is_fail():
    _log.error("UI", "打开失败: %s" % result.error.message)

# 4. 关闭
ui_service.close("main_menu")
```

---

## 逐步解释

### 第一步：理解 6 层 Canvas

GF_UIService 在 configure() 中自动创建 6 个 UI 层，从底到顶：

```
UiCanvas (CanvasLayer — 独立于游戏摄像机，固定屏幕渲染)
└── UIRoot (Control)
    ├── HudLayer       — HUD（血条、小地图、快捷键栏），始终可见
    ├── ScreenLayer    — 全屏面板（主菜单、背包、商城、地图）
    ├── PopupLayer     — 弹窗（确认框、提示、模态对话框），覆盖 Screen
    ├── TooltipLayer   — 提示框（物品详情、技能说明），覆盖 Popup
    ├── SystemLayer    — 系统通知、拖拽 Ghost，最顶层
    └── DebugLayer     — 调试面板，覆盖所有层
```

面板打开时自动路由到对应的层，同层面板的 Z-order 由 `layer_order` 字段控制。

### 第二步：定义面板（GF_UIPanelDef）

```gdscript
var def := GF_UIPanelDef.new()
def.name = "inventory"                           # 唯一标识
def.path = "res://content/ui/inventory_panel.tscn"  # 场景文件路径
def.kind = GF_UIPanelDef.KIND_SCREEN             # 所属层
def.lifecycle = GF_UIPanelDef.Lifecycle.HIDE_ON_CLOSE  # 生命周期
def.singleton = true                             # 单例模式
def.layer_order = 10                             # 同层排序
```

#### Layer Kind（面板层类型）

| 常量 | 说明 | 典型用途 |
|------|------|---------|
| `KIND_HUD` | 始终可见的平视信息 | 血条、小地图、子弹数 |
| `KIND_SCREEN` | 全屏面板 | 主菜单、背包、商城、地图 |
| `KIND_POPUP` | 弹窗/模态框 | 确认框、输入框、提示 |
| `KIND_TOOLTIP` | 浮动提示 | 物品详情、技能说明 |
| `KIND_SYSTEM` | 系统层 | 拖拽 Ghost、系统通知 |
| `KIND_DEBUG` | 调试层 | 调试面板、性能统计 |

#### Lifecycle（生命周期策略）

| 策略 | 关闭行为 | 适用场景 |
|------|---------|---------|
| `DESTROY_ON_CLOSE` | `queue_free()` 销毁 | 确认框、一次性弹窗 |
| `HIDE_ON_CLOSE` | `hide()` 隐藏，缓存在内存（最多 5 个） | 背包、商城 |
| `PERSISTENT` | 普通 `close()` 被拒绝（ERR_FORBIDDEN），需 `force_close()` | HUD、用户信息 |
| `MANAGED_BY_FLOW` | 普通 `close()` 被拒绝，由 Flow 状态机管理 | Loading 画面、黑幕过渡 |

#### 其他关键字段

```gdscript
# 输入阻挡
def.input_block_mode = GF_UIPanelDef.InputBlockMode.ALWAYS
def.blocked_action_ids = ["*"]   # 阻挡全部游戏输入，"cancel" 始终放行

# ESC 关闭行为
def.close_on_escape = true       # ESC 键是否关闭此面板

# 预热
def.prewarm = true               # 注册后自动实例化并缓存
def.preview_data = {"preview": true}  # 预热时传递的初始数据

# 焦点导航
def.focus_mode = Control.FOCUS_ALL  # 面板的焦点模式
def.default_focus = ^"CloseButton"  # 打开后自动聚焦的控件路径
```

### 第三步：注册面板

```gdscript
# 单个注册
var result := ui_service.register(main_menu_def)
if result.is_fail():
    _log.error("UI", "注册失败: %s" % result.error.message)

# 批量注册
var defs: Array[GF_UIPanelDef] = [_build_main_menu(), _build_settings(), _build_hud()]
var result := ui_service.register_all(defs)
```

批量注册后会自动触发预热（`_prewarm_deferred`），对 `prewarm = true` 且生命周期为 `HIDE_ON_CLOSE` 或 `PERSISTENT` 的面板提前实例化并缓存。

### 第四步：打开面板

```gdscript
# 打开面板，传递数据
var result := ui_service.open("item_detail", {"item_id": "iron_sword", "rarity": "rare"})
if result.is_fail():
    _log.error("UI", "打开失败: %s" % result.error.message)
    return

var panel := result.data as GF_UIPanel
# panel 已经完成了 _on_open(data) 回调
```

打开流程（`GF_UIService.open`）：
1. 查找面板定义
2. 保存当前焦点（用于关闭时恢复）
3. 如果是单例且已打开 → `reopen(data)` 并提到栈顶
4. 如果在缓存中 → 从缓存取出，`reopen(data)`
5. 否则 → 通过 `GF_SceneFactory` 加载场景
6. 注入 `ctx`、`panel_name`、`_panel_def`、焦点配置
7. 调用 `panel.open(data)` → 内部先 `_on_open(data)` 再 `show()`
8. 重新计算输入阻挡

### 第五步：关闭面板

```gdscript
# 普通关闭（PERSISTENT / MANAGED_BY_FLOW 会被拒绝）
var result := ui_service.close("settings")

# 强制关闭（跳过生命周期限制）
var result := ui_service.force_close("loading")

# 关闭栈顶可关闭面板（ESC 键逻辑）
ui_service.close_top()
```

关闭流程：
1. 检查生命周期策略（PERSISTENT/MANAGED_BY_FLOW 拒绝普通 close）
2. 注销该面板的所有 DropTarget
3. 从活跃列表和打开顺序中移除
4. 恢复上一个焦点
5. 按照策略处理：HIDE_ON_CLOSE → 缓存；其他 → `panel.close()`（`_on_close()` + `hide()` + `queue_free()`）

### 第六步：显示/隐藏已打开的面板

```gdscript
# 隐藏（不销毁，不触发 _on_close）
ui_service.hide("hud")

# 显示
ui_service.show("hud")
```

### 第七步：批量操作

```gdscript
# 关闭所有非持久面板（场景切换时）
ui_service.close_all()

# 关闭游戏内面板，保留 HUD
ui_service.clear_gameplay_ui()

# 关闭全部（含 HUD）
ui_service.clear_all_ui()

# 关闭指定层的面板
ui_service.clear_layer(GF_UIPanelDef.KIND_POPUP)

# 返回主菜单时隐藏 HUD
ui_service.hide_hud()

# 进入游戏时显示 HUD
ui_service.show_hud()
```

### 第八步：编写面板脚本（继承 GF_UIPanel）

```gdscript
class_name MyInventoryPanel
extends GF_UIPanel

func _on_open(p_data: Dictionary) -> void:
    # 首次打开时调用。p_data 由 ui_service.open(name, data) 传入
    ctx.log.debug("Inventory", "面板打开")
    _load_inventory_items()

func _on_reopen(p_data: Dictionary) -> void:
    # 非首次打开（从缓存取出）时调用
    ctx.log.debug("Inventory", "面板重新打开")
    _refresh_items()

func _on_close() -> void:
    # 面板销毁前清理
    ctx.log.debug("Inventory", "面板关闭")
    _unsubscribe_events()

func _on_hide() -> void:
    # 面板被隐藏时（HIDE_ON_CLOSE 策略），暂停轮询等
    ctx.log.debug("Inventory", "面板隐藏")
```

关键点：`open()` 和 `reopen()` 都是先填数据再显示（`_on_open` → `show()`），避免空面板闪烁。

---

## 完整示例：主菜单 + 设置面板

```gdscript
# ---- 定义（在 Game 层引导脚本中） ----

func _register_panels(ui_service: GF_UIService) -> void:
    var main_menu := GF_UIPanelDef.new()
    main_menu.name = "main_menu"
    main_menu.path = "res://content/ui/main_menu.tscn"
    main_menu.kind = GF_UIPanelDef.KIND_SCREEN
    main_menu.lifecycle = GF_UIPanelDef.Lifecycle.PERSISTENT
    main_menu.close_on_escape = false

    var settings := GF_UIPanelDef.new()
    settings.name = "settings"
    settings.path = "res://content/ui/settings_panel.tscn"
    settings.kind = GF_UIPanelDef.KIND_POPUP
    settings.lifecycle = GF_UIPanelDef.Lifecycle.HIDE_ON_CLOSE
    settings.input_block_mode = GF_UIPanelDef.InputBlockMode.ALWAYS
    settings.blocked_action_ids = ["*"]
    settings.default_focus = ^"CloseButton"

    var confirm_dialog := GF_UIPanelDef.new()
    confirm_dialog.name = "confirm_dialog"
    confirm_dialog.path = "res://content/ui/confirm_dialog.tscn"
    confirm_dialog.kind = GF_UIPanelDef.KIND_POPUP
    confirm_dialog.lifecycle = GF_UIPanelDef.Lifecycle.DESTROY_ON_CLOSE
    confirm_dialog.input_block_mode = GF_UIPanelDef.InputBlockMode.ALWAYS
    confirm_dialog.blocked_action_ids = ["*"]

    var hud := GF_UIPanelDef.new()
    hud.name = "hud"
    hud.path = "res://content/ui/hud.tscn"
    hud.kind = GF_UIPanelDef.KIND_HUD
    hud.lifecycle = GF_UIPanelDef.Lifecycle.PERSISTENT
    hud.prewarm = true

    var loading := GF_UIPanelDef.new()
    loading.name = "loading"
    loading.path = "res://content/ui/loading_screen.tscn"
    loading.kind = GF_UIPanelDef.KIND_SYSTEM
    loading.lifecycle = GF_UIPanelDef.Lifecycle.MANAGED_BY_FLOW
    loading.close_on_escape = false

    ui_service.register_all([main_menu, settings, confirm_dialog, hud, loading])


# ---- main_menu_panel.gd ----
class_name MainMenuPanel
extends GF_UIPanel


func _on_open(_p_data: Dictionary) -> void:
    $NewGameButton.pressed.connect(_on_new_game)
    $SettingsButton.pressed.connect(_on_settings)
    $QuitButton.pressed.connect(_on_quit)


func _on_new_game() -> void:
    ctx.ui.close_all()
    ctx.flow.to_loading()


func _on_settings() -> void:
    ctx.ui.open("settings")


func _on_quit() -> void:
    get_tree().quit()


# ---- settings_panel.gd ----
class_name SettingsPanel
extends GF_UIPanel


func _on_open(_p_data: Dictionary) -> void:
    $CloseButton.pressed.connect(_on_close_pressed)
    _load_current_settings()


func _on_close_pressed() -> void:
    _save_settings()
    ctx.ui.close("settings")


func _load_current_settings() -> void:
    var config := ctx.config
    $MusicSlider.value = config.get_value("audio", "music_volume", 1.0)
    $SfxSlider.value = config.get_value("audio", "sfx_volume", 1.0)


func _save_settings() -> void:
    ctx.config.set_value("audio", "music_volume", $MusicSlider.value)
    ctx.config.set_value("audio", "sfx_volume", $SfxSlider.value)
    ctx.log.info("Settings", "设置已保存")


# ---- 确认对话框 ----
func _show_confirm(title: String, message: String, on_ok: Callable) -> void:
    var result := ui_service.open("confirm_dialog", {
        "title": title, "message": message, "on_ok": on_ok,
    })
    if result.is_fail():
        _log.error("UI", "确认框打开失败")
```

---

## 常见变体

### 变体 1：面板缓存（HIDE_ON_CLOSE）

```gdscript
var def := GF_UIPanelDef.new()
def.name = "shop"
def.lifecycle = GF_UIPanelDef.Lifecycle.HIDE_ON_CLOSE
# 关闭时 hide 而非 queue_free，再打开时调用 _on_reopen
# 缓存最多 5 个面板，超出时 LRU 淘汰
```

### 变体 2：预热（首次打开不卡顿）

```gdscript
var def := GF_UIPanelDef.new()
def.name = "inventory"
def.lifecycle = GF_UIPanelDef.Lifecycle.HIDE_ON_CLOSE
def.prewarm = true  # 注册后自动后台实例化并缓存
```

### 变体 3：面板内排序

```gdscript
def.layer_order = 50  # 同层内数字大的在上面
```

### 变体 4：非单例面板

```gdscript
def.singleton = false  # 允许同一面板同时打开多个实例
```

---

## 错误码

| 方法 | 可能的错误码 | 说明 |
|------|------------|------|
| `register(p_def)` | `ERR_BAD_REQUEST` | name 或 path 为空 |
| `open(p_name, p_data)` | `ERR_NOT_FOUND` | 面板未注册 |
| | `ERR_BAD_REQUEST` | 根节点不是 GF_UIPanel |
| `close(p_name)` | `ERR_NOT_FOUND` | 面板未注册 |
| | `ERR_FORBIDDEN` | PERSISTENT 或 MANAGED_BY_FLOW 面板 |
| `force_close(p_name)` | `ERR_NOT_FOUND` | 面板未注册 |
| `show(p_name)` | `ERR_NOT_FOUND` | 面板未打开 |
| `hide(p_name)` | `ERR_NOT_FOUND` | 面板未打开 |

---

## See Also

- [处理玩家输入](./handle-player-input.md) -- 面板的输入阻挡配置
- [实现拖拽交互](./drag-and-drop.md) -- 在面板中实现拖拽
- [场景切换](./scene-switching.md) -- UI 层结构
- [应用状态机](./app-state-flow.md) -- MANAGED_BY_FLOW 的流程管理
