# GF_UIPanel

> 适用版本: 0.3.0 | 继承: GF_UIPanel → Control → CanvasItem → Node → Object

## 概述

所有游戏 UI 面板的基类。Game 层的面板脚本继承此类，重写对应的生命周期回调。GF_UIService 管理面板的生命周期，子类只需关注业务逻辑。

**何时使用：** 创建任何游戏 UI 面板（背包、商店、对话、HUD、设置等）时继承此类。

**何时不使用：** 不需要 GF_UIService 管理的纯 UI 小部件（按钮、标签、图标等）无需继承此类。

## 属性

| 属性 | 类型 | 默认值 | 描述 |
|------|------|--------|------|
| panel_name | String | "" | 面板名称，由 GF_UIService 在 open 时设置。用于反向查找面板定义。 |
| ctx | GF_UiContext | null | UI 子系统上下文，由 GF_UIService 在面板实例化后自动注入。子类可直接使用 ctx.log、ctx.ui 等服务。 |
| _panel_def | GF_UIPanelDef | null | 面板定义引用（由 GF_UIService 注入）。GF_InputPolicy 直接读取以判断输入阻挡策略。 |
| _focus_mode | Control.FocusMode | FOCUS_ALL | 焦点模式，由 GF_UIService 在 open 时通过 set_focus_config 注入。 |
| _default_focus_path | NodePath | NodePath() | 默认焦点控件路径，由 GF_UIService 在 open 时注入。 |

## 公共方法

### set_focus_config(p_mode: Control.FocusMode, p_default_focus: NodePath)

注入焦点配置。由 GF_UIService 在面板打开时调用，子类不应手动调用。

**参数:** | 参数 | 类型 | 描述 | |------|------|------| | p_mode | Control.FocusMode | 焦点模式（FOCUS_ALL / FOCUS_CLICK / FOCUS_NONE）。 | | p_default_focus | NodePath | 默认聚焦的控件路径。空路径表示不自动聚焦。 |

---

### open(p_data: Dictionary = {})

由 GF_UIService 调用。先调用 `_on_open(p_data)` 填充数据，再调用 `_apply_focus_config()` 配置焦点，最后 `show()` 显示面板。子类不应重写此方法。

**参数:** | 参数 | 类型 | 描述 | |------|------|------| | p_data | Dictionary | 传递给 `_on_open` 的数据。 |

---

### reopen(p_data: Dictionary = {})

由 GF_UIService 调用（缓存命中或 singleton 重复打开时）。先调用 `_on_reopen(p_data)` 更新数据，再调用 `_apply_focus_config()` 配置焦点，最后 `show()` 显示面板。子类不应重写此方法。

**参数:** | 参数 | 类型 | 描述 | |------|------|------| | p_data | Dictionary | 传递给 `_on_reopen` 的数据。 |

---

### close()

由 GF_UIService 调用。执行 `_on_close()` → `hide()` → `queue_free()`。子类不应重写此方法。

---

### hide_panel()

由 GF_UIService 调用（HIDE_ON_CLOSE 缓存策略专用）。执行 `_on_hide()` → `hide()`。面板保留在内存中供后续复用。子类不应重写此方法。

---

### is_pointer_over_game_input_blocking_area(p_global_mouse_pos: Vector2) → bool

判断指定全局鼠标坐标是否位于会阻挡游戏输入的面板区域内。默认使用面板自身矩形（`get_global_rect()`）做命中检测。HUD 等非全屏面板可重写此方法返回更窄的阻挡区域。

**参数:** | 参数 | 类型 | 描述 | |------|------|------| | p_global_mouse_pos | Vector2 | 全局鼠标坐标。 |

---

### _on_factory_init(_p_data: Dictionary)

GF_SceneFactory 钩子：面板实例化后自动调用，在 `open()` 之前触发。p_data 为 `GF_SceneFactory.create()` 传入的 init_data。

**参数:** | 参数 | 类型 | 描述 | |------|------|------| | _p_data | Dictionary | SceneFactory 传递的初始化数据。 |

---

## 子类重写回调

以下方法为虚方法，由子类根据业务需求选择性重写。

### _on_open(_p_data: Dictionary)

面板首次打开时调用。在此填充 UI 控件数据、连接信号、注册回调。调用时机在 `show()` 之前，因此不会产生空面板闪烁。

**参数:** | 参数 | 类型 | 描述 | |------|------|------| | _p_data | Dictionary | `open()` 或 `GF_UIService.open()` 传入的数据。 |

**示例:** ```gdscript
func _on_open(p_data: Dictionary) -> void:
    var item_id := p_data.get("item_id", "")
    $TitleLabel.text = ctx.config_service.get_item_name(item_id)
    $Icon.texture = ctx.config_service.get_item_icon(item_id)
    ctx.log.info("ItemDetail", "打开物品详情: %s" % item_id)
```

---

### _on_reopen(_p_data: Dictionary)

面板再次打开时调用（仅在 cache 策略、非首次打开时触发）。与 `_on_open` 类似，但面板是复用而非重新实例化。需重置面板状态到初始值。

**参数:** | 参数 | 类型 | 描述 | |------|------|------| | _p_data | Dictionary | `reopen()` 传入的数据。 |

**示例:** ```gdscript
func _on_reopen(p_data: Dictionary) -> void:
    # 清除上一次打开的数据
    $ScrollContainer.scroll_vertical = 0
    $SearchBox.text = ""
    _refresh_list(p_data.get("category", ""))
```

---

### _on_close()

面板关闭/销毁时调用（所有策略下最终都会调用）。在此释放资源、断开信号、清理引用。DESTROY_ON_CLOSE 策略下，此方法调用后节点将被 `queue_free()`。

---

### _on_hide()

面板被隐藏时调用（仅在 HIDE_ON_CLOSE 缓存策略下触发）。在此暂停轮询、动画等持续活动。面板保留在内存中，不销毁。

---

## 生命周期

### DESTROY_ON_CLOSE 策略（默认）

```
实例化 → ctx 注入 → _on_factory_init(data) → open(data) → _on_open(data)
  → show()
    （面板活跃中……）
  → close() → _on_close() → hide() → queue_free()
```

### HIDE_ON_CLOSE / 缓存策略

```
首次实例化 → ctx 注入 → open(data) → _on_open(data) → show()
    （面板活跃中……）
  → hide_panel() → _on_hide() → hide()（进入缓存）
  → reopen(data) → _on_reopen(data) → show()（从缓存取出）
    （……可重复 reopen/hide）
  → 缓存满被挤出 → close() → _on_close() → queue_free()
```

## See Also

- [GF_UIService](gf_ui_service.md) — UI 管理服务
- [GF_UIPanelDef](gf_ui_panel_def.md) — 面板定义
- [GF_UIDragSlot](gf_ui_drag_slot.md) — 可拖拽格子控件（Panel 的子节点组件）
- GF_UiContext — UI 子系统上下文（通过 self.ctx 访问）
