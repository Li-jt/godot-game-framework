# GF_ContentDefRegistry

> 适用版本: 0.3.0 | 继承: GF_ContentDefRegistry -> RefCounted

## 概述

内容定义注册表。通用模块注册与查询机制，不含任何具体业务语义。替代 GameDefService 单例，由 GF_EcsScheduler.configure() 注入为 ECS World 的 Resource，ECS 系统通过 `p_world.get_resource(GF_ContentDefRegistry).module("terrain")` 获取。

适用场景：注册 terrain、season、resource 等内容模块。支持 Mod 模块的动态注册和卸载。

## 公共方法

### register_module(p_name: StringName, p_module: Variant) -> void

注册一个内容模块。重复注册同名模块会产生 overwrite 警告。

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_name` | `StringName` | 模块名称（如 `"terrain"`、`"season"`） |
| `p_module` | `Variant` | 模块实例，通常是加载 JSON 数据后的数据持有对象 |

### module(p_name: StringName) -> Variant

获取已注册的模块。未注册时返回 `null`。

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_name` | `StringName` | 模块名称 |

**返回值:** 模块实例，不存在时返回 `null`。

### has_module(p_name: StringName) -> bool

检查模块是否已注册。

### module_names() -> Array[StringName]

获取所有已注册的模块名称列表。

### unregister_module(p_name: StringName) -> void

注销模块。Mod 卸载时使用。

### clear() -> void

清空所有已注册的模块。

## 使用示例

```gdscript
# GameBootstrap 中注册模块
var content_def := GF_ContentDefRegistry.new()
content_def.register_module(&"terrain", terrain_data)
content_def.register_module(&"season", season_data)
content_def.register_module(&"resource", resource_data)

# 注入到 ECS World
world.set_resource(GF_ContentDefRegistry, content_def)

# ECS 系统中查询
func on_tick(p_world: GF_EcsWorld, p_ecb: GF_EcsCommandBuffer, p_delta: float) -> void:
    var content_def := p_world.get_resource(GF_ContentDefRegistry) as GF_ContentDefRegistry
    var terrain := content_def.module(&"terrain") if content_def != null else null
    if terrain != null:
        var tile := terrain.get_tile(pos)
```

## See Also

- [GF_DefIdRegistry](./gf_def_id_registry.md) -- ID 注册表
- [GF_EcsWorld](../ecs/gf_ecs_world.md) -- ECS 世界
