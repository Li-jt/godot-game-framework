## GF_DefaultBootstrap
## 框架自带的默认启动引导。项目创建后即可运行，输出框架就绪信息。
## 实际项目应创建自己的 AppBootstrap 子类并覆盖 _assemble() 和 _on_ready()。
@tool
class_name GF_DefaultBootstrap
extends GF_AppBootstrap


func _assemble() -> void:
	# 默认不注册任何可选模块。用户在自己的 Bootstrap 中按需注册。
	pass


func _on_ready() -> void:
	var log := service(GF_LogService) as GF_LogService
	log.info("Framework", "Godot Game Framework 就绪！")
	log.info("Framework", "")
	log.info("Framework", "接下来你可以：")
	log.info("Framework", "  1. 创建自己的 AppBootstrap 子类覆盖 _assemble()")
	log.info("Framework", "  2. 在 _assemble() 中 register() 需要的服务")
	log.info("Framework", "  3. 在 _on_ready() 中注册 ECS 系统和游戏逻辑")
