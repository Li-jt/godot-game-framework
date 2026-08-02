## GF_DefaultBootstrap
## 框架自带的默认启动引导。注册 UI 模块，启动后即可看到 UI 节点树。
## 实际项目应创建自己的 AppBootstrap 子类并覆盖 _assemble() 和 _on_ready()。
@tool
class_name GF_DefaultBootstrap
extends GF_AppBootstrap


func _assemble() -> void:
	# 注册 UI 模块（自动创建 CanvasLayer → UIRoot → 6 层 UI 节点树）
	register(GF_SceneFactory.new())
	register(GF_InputService.new())
	register(GF_UIService.new())


func _on_ready() -> void:
	var log := service(GF_LogService) as GF_LogService
	log.info("Framework", "Godot Game Framework 就绪！")
	log.info("Framework", "  UI 节点树已自动创建（运行时可查看 Remote 场景树）")
	log.info("Framework", "")
	log.info("Framework", "接下来你可以：")
	log.info("Framework", "  1. 创建自己的 AppBootstrap 子类覆盖 _assemble()")
	log.info("Framework", "  2. 在 _assemble() 中 register() 需要的服务")
	log.info("Framework", "  3. 在 _on_ready() 中注册面板定义并打开")
