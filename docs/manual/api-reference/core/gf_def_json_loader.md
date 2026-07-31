# GF_DefJsonLoader

> 适用版本: 0.3.0 | 继承: GF_DefJsonLoader -> RefCounted

## 概述

通用的 JSON 定义文件加载工具。支持多个文件合并加载，后加载的覆盖同名字段。供 UI/Audio/Input 等模块从 JSON 加载定义数据。

所有方法均为静态方法，无需实例化。

## 静态方法

### load_file(p_fs: GF_FileSystemService, p_path: String) -> Dictionary

加载一个 JSON 定义文件。加载失败返回空字典。

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_fs` | `GF_FileSystemService` | 文件系统服务 |
| `p_path` | `String` | JSON 文件路径 |

**返回值:** 解析后的 Dictionary。文件不存在或解析失败时返回 `{}`。

### load_and_merge(p_fs: GF_FileSystemService, p_paths: Array[String]) -> Dictionary

加载多个 JSON 文件并深度合并。`p_paths` 中靠后的文件覆盖靠前的同名字段。嵌套的 Dictionary 也会深度合并。

| 参数 | 类型 | 描述 |
|------|------|------|
| `p_fs` | `GF_FileSystemService` | 文件系统服务 |
| `p_paths` | `Array[String]` | JSON 文件路径列表 |

**返回值:** 合并后的 Dictionary。

## 使用示例

```gdscript
# 加载单个文件
var data := GF_DefJsonLoader.load_file(file_system, "res://config/ui_panels.json")

# 加载多个文件并合并（base 定义 + mod 覆写）
var paths := [
    "res://config/base_settings.json",
    "res://mods/my_mod/settings.json",
]
var merged := GF_DefJsonLoader.load_and_merge(file_system, paths)
```

## 合并规则

深度合并仅对两个值都是 Dictionary 的键进行递归，其他类型直接覆盖：

```gdscript
# base.json:  {"ui": {"theme": "dark", "scale": 1.0}}
# mod.json:   {"ui": {"theme": "light"}}
# 合并结果:   {"ui": {"theme": "light", "scale": 1.0}}
```

## See Also

- [GF_DefIdRegistry](./gf_def_id_registry.md) -- ID 注册表
