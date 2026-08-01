# 配置

框架**无需外部配置文件**即可运行。所有配置通过代码完成。

## 服务配置

每个 Service 自带合理默认值，在 `_assemble()` 中按需覆盖：

```gdscript
func _assemble() -> void:
    var threading := GF_ThreadingService.new()
    threading.max_jobs = 8
    register(threading)
```

或者在 `_on_ready()` 中调用 Service 的 configure 方法：

```gdscript
func _on_ready() -> void:
    var log := service(GF_LogService) as GF_LogService
    log.configure("Info", true, "user://my_logs")
```

## 自定义服务实现

要替换框架默认实现，在 `register()` 之前注册你的替代品：

```gdscript
func _assemble() -> void:
    register(MyCloudSaveProvider.new())  # 替换默认的 LocalSaveProvider
    register(GF_SaveService.new())       # SaveService 检测到已有 Provider，不重复创建
```

## 多环境配置

如果需要不同环境用不同配置（如 dev/staging/prod 的 API 地址），在你的 Bootstrap 子类中自行处理：

```gdscript
func _assemble() -> void:
    var env := OS.get_environment("GAME_ENV") if not OS.get_environment("GAME_ENV").is_empty() else "dev"
    match env:
        "prod":
            # 注册生产环境的服务配置
            pass
        _:
            # 默认开发环境
            pass
```

框架不绑定任何配置文件格式（JSON / .env / .cfg），由你决定。
