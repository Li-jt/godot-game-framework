# 配置文件

框架通过 `config/app_config.json` 管理应用级配置。框架自带默认配置（`default_app_config.json`），此文件仅在需要覆盖默认值时创建，只写你要改的字段即可。

## 完整示例

```json
{
  "app": {
    "name": "我的游戏",
    "version": "0.1.0",
    "environment": "development"
  },
  "runtime": {
    "mode": "local",
    "enable_prediction": false
  },
  "save": {
    "provider": "local",
    "auto_save_interval_seconds": 300,
    "max_save_slots": 10
  },
  "logging": {
    "level": "info",
    "enable_file_logging": true,
    "log_file_path": "user://logs/game.log"
  },
  "network": {
    "use_mock_api": true,
    "base_url": "http://localhost:3000",
    "timeout_seconds": 30
  },
  "debug": {
    "enable_debug_panel": true,
    "enable_performance_stats": true
  },
  "paths": {
    "content_root": "res://content",
    "defs_root": "res://config/defs"
  }
}
```

## 字段详解

### `app` — 应用元信息

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `name` | `String` | `""` | 游戏名称，启动时打印到日志横幅 |
| `version` | `String` | `"0.0.0"` | 语义化版本号 |
| `environment` | `String` | `"development"` | 运行环境。可选值：`"development"`、`"staging"`、`"production"` |

### `runtime` — 运行时模式

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `mode` | `String` | `"local"` | 运行模式。可选值：`"local"`（单机）、`"remote"`（联机客户端）、`"hybrid"`（混合模式）。`"remote"` 和 `"hybrid"` 为预留 |
| `enable_prediction` | `bool` | `false` | 是否启用客户端预测（仅 `"remote"` 模式下有意义） |

### `save` — 存档配置

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `provider` | `String` | `"local"` | 存档提供者。可选值：`"local"`（本地文件）、`"memory"`（内存、测试用） |
| `auto_save_interval_seconds` | `int` | `300` | 自动存档间隔（秒）。设为 `0` 禁用自动存档 |
| `max_save_slots` | `int` | `10` | 最大存档槽位数 |

### `logging` — 日志配置

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `level` | `String` | `"info"` | 日志级别。可选值：`"debug"`、`"info"`、`"warn"`、`"error"`。`"debug"` 级别输出所有日志，`"error"` 级别只输出错误 |
| `enable_file_logging` | `bool` | `false` | 是否同时写入日志文件 |
| `log_file_path` | `String` | `""` | 日志文件路径。支持 `user://` 和 `res://` 前缀 |

### `network` — 网络配置

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `use_mock_api` | `bool` | `true` | 是否使用 Mock API（开发阶段）。设为 `true` 时不发真实网络请求 |
| `base_url` | `String` | `""` | API 服务器地址 |
| `timeout_seconds` | `int` | `30` | 网络请求超时时间（秒） |

### `debug` — 调试配置

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `enable_debug_panel` | `bool` | `false` | 是否启用调试面板（FPS 显示、ECS 检查器等） |
| `enable_performance_stats` | `bool` | `false` | 是否启用性能统计收集 |

### `paths` — 路径配置

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `content_root` | `String` | `"res://content"` | 资产根目录 |
| `defs_root` | `String` | `"res://config/defs"` | 游戏内容定义 JSON 文件的根目录 |

## 环境变量覆盖

框架支持通过环境变量覆盖 `app_config.json` 中的部分配置。环境变量优先级高于配置文件。

| 环境变量 | 覆盖字段 | 示例 |
|---|---|---|
| `GF_RUNTIME_MODE` | `runtime.mode` | `export GF_RUNTIME_MODE=local` |
| `GF_ENV` | `app.environment` | `export GF_ENV=production` |
| `GF_LOG_LEVEL` | `logging.level` | `export GF_LOG_LEVEL=debug` |
| `GF_SAVE_PROVIDER` | `save.provider` | `export GF_SAVE_PROVIDER=memory` |
| `GF_API_BASE_URL` | `network.base_url` | `export GF_API_BASE_URL=https://api.example.com` |
| `GF_DEBUG_PANEL` | `debug.enable_debug_panel` | `export GF_DEBUG_PANEL=1` |

环境变量在 Godot 编辑器启动时设置。也可以在运行参数中设置：

```bash
GF_LOG_LEVEL=debug godot --path . scenes/main.tscn
```

## 配置校验规则

`GF_AppConfigLoader` 在加载配置时执行以下校验：

1. **`app.name` 不能为空**：空字符串会导致校验失败，启动中止。
2. **`app.environment` 必须是有效值**：只接受 `"development"`、`"staging"`、`"production"`。
3. **`runtime.mode` 必须是有效值**：只接受 `"local"`、`"remote"`、`"hybrid"`。
4. **`logging.level` 必须是有效值**：只接受 `"debug"`、`"info"`、`"warn"`、`"error"`。
5. **默认值填充**：缺少的字段会被自动填充为默认值，不会报错。

## 运行时读取配置

配置在启动时由 `GF_AppBootstrap` 加载，并通过 `GF_GameServices.config` 暴露给游戏代码：

```gdscript
# 在 _on_post_boot 或其他服务方法中
func _on_post_boot(context: GF_GameServices) -> GF_OperationResult:
    var config: GF_AppConfig = context.config

    # 读取应用配置
    var game_name: String = config.app.name
    var env: String = config.app.environment

    # 运行时判断
    if config.runtime.mode == "local":
        context.log.info("Game", "以本地模式运行")

    # 日志级别
    if config.logging.level == "debug":
        context.log.debug("Game", "调试信息已启用")

    # 调试面板
    if config.debug.enable_debug_panel:
        _setup_debug_tools(context)

    return GF_OperationResult.ok()
```

## 多环境配置

你可以为不同环境准备不同的配置文件：

```text
config/
├── app_config.json              # 开发环境（默认）
├── app_config.staging.json      # 预发布环境
└── app_config.production.json   # 生产环境
```

然后在 `_create_app_config()` 中根据构建参数选择：

```gdscript
# my_game_bootstrap.gd
func _create_app_config() -> GF_AppConfig:
    var env := OS.get_environment("GF_ENV")
    var config_path := "res://config/app_config.json"
    if not env.is_empty() and env != "development":
        config_path = "res://config/app_config.%s.json" % env
    var result := GF_AppConfigLoader.new().load_config_file(config_path)
    return result.data if result.is_ok() else GF_AppConfig.new()
```

---

**下一步**: [模块生命周期](../core-concepts/module-lifecycle.md) — 理解如何管理服务的初始化与销毁，或返回[框架概览](overview.md)。
