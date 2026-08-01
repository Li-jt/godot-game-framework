## GF_DefaultBootstrap
## 框架自带的默认启动引导。项目创建后即可运行，输出框架就绪信息。
## 实际项目应创建自己的 AppBootstrap 子类并覆盖 _on_post_boot()。
@tool
class_name GF_DefaultBootstrap
extends GF_AppBootstrap


func _on_post_boot(context: GF_GameServices) -> GF_OperationResult:
	context.log.info("Framework", "Godot Game Framework 就绪！")
	context.log.info("Framework", "  运行模式: %s" % context.runtime.get_mode_name())
	context.log.info("Framework", "")
	context.log.info("Framework", "接下来你可以：")
	context.log.info("Framework", "  1. 创建自己的 AppBootstrap 子类覆盖 _on_post_boot()")
	context.log.info("Framework", "  2. 在 _on_post_boot() 中注册 ECS 系统和游戏服务")
	context.log.info("Framework", "  3. 创建 WorldRoot 子类定义游戏世界")
	return GF_OperationResult.ok()
