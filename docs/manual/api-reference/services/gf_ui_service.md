# GF_UIService

> 适用版本: 0.3.0 | 继承: GF_UIService → GF_ModuleLifecycle → RefCounted

## 概述

UI 管理服务，框架中最核心的服务之一（与 GF_InputService 并列）。负责面板注册、打开/关闭生命周期控制、拖拽驱动、输入阻挡策略管理。在 `configure()` 中自动创建 UI 节点树（CanvasLayer → UIRoot → 6 层），不再依赖已删除的 GF_SceneHost。根据面板 kind 路由到对应 UI 层，根据 lifecycle 策略控制关闭行为。游戏层通过 GF_UiContext.ui 引用此服务。

**何时使用：** 注册面板定义、打开/关闭面板、查询面板状态、启动拖拽、注册放置目标。

**何时不使用：** 直接操作面板内容（按钮事件、数据刷新）—— 这些由 GF_UIPanel 子类的 `_on_open` / `_on_reopen` 回调处理。

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| MAX_CACHED | int (const) | 5 | HIDE_ON_CLOSE 面板的最大缓存数量。超出时按 LRU 策略挤出最早缓存的面板。 |
| state | GF_CoreLifecycleState.State | UNINITIALIZED | 继承自 GF_ModuleLifecycle，当前生命周期状态。 |
| module_name | String | "" | 继承自 GF_ModuleLifecycle，模块名称，用于日志和错误追踪。 |

## 公共方法

### configure() → GF_OperationResult

配置 UI 服务。自动创建 UI 节点树（CanvasLayer → UIRoot → 6 层）并挂到场景树，创建 GF_UIDragManager。通过 `_bootstrap` 获取依赖（GF_SceneFactory、GF_InputService、GF_LogService）。

**返回值:** 校验通过返回 `GF_OperationResult.ok()`。

**错误码:** | 错误码 | 触发条件 | |------|------| | ERR_BAD_REQUEST | GF_SceneFactory、GF_InputService 或 GF_LogService 依赖未满足。 |

**示例:** ```gdscript
# GF_UIService 通过 AppBootstrap 注册后自动完成 configure()
# 用户只需：register(GF_UIService.new())
```

---

### register(p_def: GF_UIPanelDef) → GF_OperationResult

注册单个面板定义。面板的 `name` 和 `path` 不能为空。

**参数:** | 参数 | 类型 | 描述 | |------|------|------| | p_def | GF_UIPanelDef | 面板定义对象，包含 name、path、kind、lifecycle 等配置。 |

**返回值:** 注册成功返回 `GF_OperationResult.ok()`。

**错误码:** | 错误码 | 触发条件 | |------|------| | ERR_BAD_REQUEST | p_def.name 为空或 p_def.path 为空。 |

**示例:** ```gdscript
var def := GF_UIPanelDef.new()
def.name = "inventory"
def.path = "res://src/ui/inventory_panel.tscn"
def.kind = GF_UIPanelDef.KIND_SCREEN
def.lifecycle = GF_UIPanelDef.Lifecycle.HIDE_ON_CLOSE
ui_service.register(def)
```

---

### register_all(p_defs: Array[GF_UIPanelDef]) → GF_OperationResult

批量注册面板定义。注册完成后自动执行预热（延迟一帧），为 prewarm=true 且支持缓存的面板预加载。

**参数:** | 参数 | 类型 | 描述 | |------|------|------| | p_defs | Array[GF_UIPanelDef] | 面板定义数组。 |

**返回值:** 全部注册成功返回 `GF_OperationResult.ok()`，途中任一失败则立即返回该错误。

**示例:** ```gdscript
var defs: Array[GF_UIPanelDef] = [hud_def, inventory_def, shop_def]
var result := ui_service.register_all(defs)
if result.is_fail():
    return result
```

---

### open(p_name: String, p_data: Dictionary = {}) → GF_OperationResult

打开指定面板。行为根据面板状态不同：

- **已打开 + singleton=true：** 调用现有面板的 `reopen(p_data)` 并提到栈顶。
- **缓存命中：** 从缓存取出，调用 `reopen(p_data)`，从 `_open_order` 重新追踪。
- **首次打开：** 通过 GF_SceneFactory 加载场景，实例化为 GF_UIPanel，注入 ctx 和面板定义，调用 `open(p_data)`。

**参数:** | 参数 | 类型 | 描述 | |------|------|------| | p_name | String | 面板名称（对应注册时的 GF_UIPanelDef.name）。 | | p_data | Dictionary | 传递给面板 `_on_open` 或 `_on_reopen` 的数据。默认空字典。 |

**返回值:** 成功返回 `GF_OperationResult.ok(panel)`（data 为打开的 GF_UIPanel 实例）。

**错误码:** | 错误码 | 触发条件 | |------|------| | ERR_NOT_FOUND | 面板未注册（p_name 在 _panel_defs 中不存在）。 | | ERR_BAD_REQUEST | 加载的场景根节点不是 GF_UIPanel。 | | 其他 | GF_SceneFactory.create() 传递的错误。 |

**示例:** ```gdscript
var result := ui_service.open("inventory", {"tab": "weapons"})
if result.is_fail():
    ctx.log.error("UI", "打开背包失败: %s" % result.error.message)
    return
var panel := result.data as GF_UIPanel
```

---

### close(p_name: String) → GF_OperationResult

关闭指定面板。PERSISTENT 或 MANAGED_BY_FLOW 生命周期面板会被拒绝，返回 ERR_FORBIDDEN。

**参数:** | 参数 | 类型 | 描述 | |------|------|------| | p_name | String | 要关闭的面板名称。 |

**返回值:** 成功返回 `GF_OperationResult.ok()`。

**错误码:** | 错误码 | 触发条件 | |------|------| | ERR_NOT_FOUND | 面板未注册。 | | ERR_FORBIDDEN | 面板 lifecycle 为 PERSISTENT 或 MANAGED_BY_FLOW（被拒绝关闭）。 |

**示例:** ```gdscript
var result := ui_service.close("inventory")
if result.error.code == GF_OperationResult.ERR_FORBIDDEN:
    ctx.log.warn("UI", "PERSISTENT 面板不允许普通 close")
```

---

### force_close(p_name: String) → GF_OperationResult

强制关闭面板，跳过生命周期策略限制。PERSISTENT 和 MANAGED_BY_FLOW 面板也可被关闭。

**参数:** | 参数 | 类型 | 描述 | |------|------|------| | p_name | String | 要关闭的面板名称。 |

**返回值:** 成功返回 `GF_OperationResult.ok()`。

**错误码:** | 错误码 | 触发条件 | |------|------| | ERR_NOT_FOUND | 面板未注册。 |

**示例:** ```gdscript
# 场景切换时强制关闭所有面板
ui_service.force_close("loading_screen")
```

---

### show(p_name: String) → GF_OperationResult

显示已打开（但被隐藏）的面板。面板必须处于活跃状态。

**参数:** | 参数 | 类型 | 描述 | |------|------|------| | p_name | String | 面板名称。 |

**返回值:** 成功返回 `GF_OperationResult.ok()`。

**错误码:** | 错误码 | 触发条件 | |------|------| | ERR_NOT_FOUND | 面板未在活跃面板列表中。 |

---

### hide(p_name: String) → GF_OperationResult

隐藏已打开的面板。面板仍保留在 `_active_panels` 中，可通过 `show()` 恢复。

**参数:** | 参数 | 类型 | 描述 | |------|------|------| | p_name | String | 面板名称。 |

**返回值:** 成功返回 `GF_OperationResult.ok()`。

**错误码:** | 错误码 | 触发条件 | |------|------| | ERR_NOT_FOUND | 面板未在活跃面板列表中。 |

---

### close_top() → GF_OperationResult

关闭栈顶可关闭面板（ESC 键逻辑）。从 `_open_order` 栈顶向下查找第一个满足以下条件的面板并关闭：

1. 不在 PERSISTENT 或 MANAGED_BY_FLOW 生命周期中
2. `close_on_escape` 不为 false

**特殊行为：** 如果当前正在拖拽，则取消拖拽而非关闭面板。

**返回值:** 成功返回 `GF_OperationResult.ok()`。

**示例:** ```gdscript
# 绑到 ESC 键
func _on_escape_pressed() -> void:
    ui_service.close_top()
```

---

### close_all()

关闭所有非 PERSISTENT 和非 MANAGED_BY_FLOW 的面板。常用于场景切换前清理 UI。

---

### clear_layer(p_kind: StringName)

关闭指定 UI 层中的所有面板。

**参数:** | 参数 | 类型 | 描述 | |------|------|------| | p_kind | StringName | UI 层类型，使用 GF_UIPanelDef.KIND_* 常量。 |

---

### clear_gameplay_ui()

关闭游戏内面板（SCREEN / POPUP / TOOLTIP），保留 HUD 和 SYSTEM 面板。用于返回主界面等场景。

---

### clear_all_ui()

关闭所有 UI 面板（包括 HUD）。比 `close_all()` 更彻底，连 PERSISTENT HUD 也一并关闭。使用 `force_close` 的内部逻辑。

---

### hide_hud()

隐藏所有当前活跃的 HUD 面板（调用 `hide()`，面板不销毁）。用于返回主菜单时隐藏游戏 HUD。

---

### show_hud()

显示所有 HUD 面板。先尝试打开 PERSISTENT 的 HUD 面板（如果尚未打开），然后对所有活跃的 HUD 调用 `show()`。用于进入游戏场景时显示 HUD。

---

### is_open(p_name: String) → bool

检查指定面板是否处于活跃（打开）状态。

---

### get_panel(p_name: String) → GF_UIPanel

获取活跃面板实例。面板未打开时返回 `null`。

---

### get_active_panels() → Array[GF_UIPanel]

返回所有活跃面板实例的数组。内部做了 `is_instance_valid` 校验，已被释放的面板不会包含在内。供 GF_InputPolicy 查询用。

---

### get_active_panel_names() → Array[String]

返回所有活跃面板的名称数组。

---

### begin_drag(p_handler: GF_UIDragHandler, p_screen_pos: Vector2, p_source: GF_UIPanel = null) → GF_OperationResult

开始拖拽。如果有旧拖拽未结束，先调用 `cancel_drag()` 取消旧的再开始新的。

**参数:** | 参数 | 类型 | 描述 | |------|------|------| | p_handler | GF_UIDragHandler | 游戏层实现的拖拽处理器子类。 | | p_screen_pos | Vector2 | 拖拽起始位置（屏幕坐标）。 | | p_source | GF_UIPanel | 拖拽源面板（可选）。面板关闭时框架自动清理其关联的拖拽。 |

**返回值:** 成功返回 `GF_OperationResult.ok()`。

**错误码:** | 错误码 | 触发条件 | |------|------| | ERR_INTERNAL | GF_UIDragManager 未初始化（configure 未调用）。 | | ERR_BAD_REQUEST | handler 为 null。 |

---

### cancel_drag()

取消当前拖拽。在拖拽仍未结束时调用：
1. 设置 `event.drop_receiver = null`
2. 调用 `handler.on_end_drag(event)`
3. 发送 `on_leave` 给最后悬停的目标
4. 调用 `drag_manager.clear_drag_state()` 清理状态

拖拽已结束时调用为 no-op。

---

### is_dragging() → bool

当前是否有活跃拖拽会话。

---

### get_drag_position() → Vector2

获取当前拖拽的屏幕坐标。无拖拽时返回 `Vector2.ZERO`。游戏层在 `on_drop` 中可调用此方法换算世界坐标。

---

### register_drop_target(p_target: GF_UIDropTarget) → GF_OperationResult

注册放置目标。游戏层面板在 `_on_open` 中调用，为面板内的区域注册为拖拽接收器。

**参数:** | 参数 | 类型 | 描述 | |------|------|------| | p_target | GF_UIDropTarget | 放置目标对象，必须设置 panel 属性。 |

**返回值:** 成功返回 `GF_OperationResult.ok()`。

**错误码:** | 错误码 | 触发条件 | |------|------| | ERR_BAD_REQUEST | p_target 为 null 或 p_target.panel 为 null。 |

---

### unregister_panel_targets(p_panel: GF_UIPanel)

注销属于指定面板的所有放置目标。框架在面板关闭时自动调用，游戏层通常无需手动调用。

---

### get_drag_manager() → GF_UIDragManager

获取 GF_UIDragManager Node 实例。供 GF_ServiceInstallerImpl 将管理器挂到场景树。游戏层通常无需调用。

---

### begin_simple_drag(p_data: Dictionary, p_icon: Texture2D, p_offset: Vector2 = Vector2(-24, -24), p_source: GF_UIPanel = null) → GF_UIDragHandler

L2 简化拖拽入口。提供数据和图标，框架内部创建 `_DefaultDragHandler` 处理全部拖拽生命周期。返回的 handler 可供游戏层连接信号。

**参数:** | 参数 | 类型 | 描述 | |------|------|------| | p_data | Dictionary | 拖拽携带的数据。放入 `event.drag_data`。 | | p_icon | Texture2D | 拖拽时显示的图标。 | | p_offset | Vector2 | 图标相对于鼠标的偏移，默认 (-24, -24)。 | | p_source | GF_UIPanel | 拖拽源面板（可选）。 |

**返回值:** 内部创建的 GF_UIDragHandler 实例，游戏层可连接其信号。拖拽结束时 handler 自动销毁（RefCounted）。

**示例:** ```gdscript
# 从背包拖出一个物品
func _on_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        ctx.ui.begin_simple_drag(
            {"item_id": "iron_sword", "count": 1},
            sword_icon,
            Vector2(-24, -24),
            panel
        )
```

---

### init_module() → GF_OperationResult

继承自 GF_ModuleLifecycle。执行模块初始化。

---

### dispose_module() → GF_OperationResult

继承自 GF_ModuleLifecycle。释放模块资源。

---

### is_ready() → bool

继承自 GF_ModuleLifecycle。模块是否已就绪。

---

### finalize_configuration() → GF_OperationResult

继承自 GF_ModuleLifecycle。标记配置完成，状态从 INITIALIZED 进入 READY。

---

### get_ui_layer(p_kind: StringName) → Control

根据 UI 面板类型获取对应的 UI 层 Control 节点。6 个 UI 层在 `configure()` 中自动创建。

**参数:** | 参数 | 类型 | 描述 | |------|------|------| | p_kind | StringName | UI 层类型，对应 `GF_UIPanelDef.KIND_*` 常量。 |

**路由规则:**

| p_kind 值 | 返回节点 |
|-----------|---------|
| `KIND_HUD` | HudLayer |
| `KIND_SCREEN` | ScreenLayer |
| `KIND_POPUP` | PopupLayer |
| `KIND_TOOLTIP` | TooltipLayer |
| `KIND_SYSTEM` | SystemLayer |
| `KIND_DEBUG` | DebugLayer |

---

### get_ui_root() → Control

获取 UI 根控件节点（UIRoot）。所有 6 个 UI 层的父节点。

---

### get_ui_canvas() → CanvasLayer

获取 UI 画布层（CanvasLayer）。此 CanvasLayer 独立于游戏相机，适合放置固定屏幕位置的 UI 元素。

## See Also

- [GF_UIPanel](gf_ui_panel.md) — 所有游戏 UI 面板的基类
- [GF_UIPanelDef](gf_ui_panel_def.md) — 面板定义
- [GF_UIDragManager / GF_UIDragHandler / GF_UIDragEvent](gf_ui_drag_system.md) — 拖拽系统的协议层
- [GF_UIDragSlot](gf_ui_drag_slot.md) — 可拖拽格子控件
- [GF_SceneFactory](../engine/gf_scene_factory.md) — 场景工厂
- GF_UiContext — UI 子系统上下文
- GF_InputService — 输入服务（与 UIService 协作处理输入阻挡）
