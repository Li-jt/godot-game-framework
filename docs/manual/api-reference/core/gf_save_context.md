# GF_SaveContext

> 适用版本: 0.3.0 | 继承: GF_SaveContext -> RefCounted

## 概述

存档子系统可用的窄上下文。Save/Load 流程通过此对象获取服务，避免访问不相关服务。

由 `GF_GameServices.create_save_context()` 构造。

## 属性

| 属性 | 类型 | 描述 |
|------|------|------|
| `log` | `GF_LogService` | 日志服务 |
| `save_service` | `GF_SaveService` | 存档服务 |
| `config_service` | `GF_ConfigService` | 游戏配置定义服务 |
| `config` | `GF_AppConfig` | 应用运行配置 |

## 使用示例

```gdscript
# 在存档迁移器中使用上下文
class_name MySaveMigrator

var ctx: GF_SaveContext = null

func migrate(p_data: Dictionary) -> Dictionary:
    ctx.log.info("SaveMigrator", "从版本 %d 迁移" % p_data.get("version", 0))
    # ... 执行迁移逻辑
    return p_data
```

## See Also

- [GF_GameplayContext](./gf_gameplay_context.md) -- 玩法子系统窄上下文
- [GF_UiContext](./gf_ui_context.md) -- UI 子系统窄上下文
- [GF_GameServices](./gf_game_services.md) -- 服务聚合对象
