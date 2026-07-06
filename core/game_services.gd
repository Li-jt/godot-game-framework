## GameServices（Framework 层）
## Game 层可用的服务聚合对象，仅用于显式依赖注入。
## 由 Application 层在启动装配完成后构造，并传入 GameBootstrap。
##
## 设计目标：
## - 替代 Game 层直接访问 ServiceRegistry
## - 让 Game 子系统依赖在类型层面显式可见
## - 保持 Game 对 Application 装配细节零感知
class_name GameServices
extends RefCounted

## Game 层可读取的最终运行配置
var config: AppConfig = null
## 统一日志服务
var log: LogService = null
## 场景宿主（世界 / UI / 弹窗挂载点）
var scene_host: SceneHost = null
## 输入服务（Game 语义动作查询）
var input: InputService = null
## UI 服务（面板打开/关闭/缓存）
var ui: UIService = null
## 音频服务（高层播放入口）
var audio: AudioService = null
## 资源服务（高层资源访问入口）
var resource: ResourceService = null
## 事件总线（跨模块事件通知）
var event_bus: EventBus = null
## 存档服务（保存/读取/槽位管理）
var save_service: SaveService = null
## 配置服务（ItemDef / BuildingDef 等游戏内容定义查询）
var config_service: ConfigService = null
## 调试服务（运行时统计 / 面板注册 / 命令追踪）
var debug: DebugService = null
## 本地化服务（多语言文本）
var loc: LocalizationService = null
## 应用流程服务（MainMenu/InGame 等流程切换）
var app_flow: AppFlow = null
## Tick 调度器（Game 层注册逐帧回调）
var scheduler: Scheduler = null
## 运行时模式服务（Local/Remote/Hybrid 命令与存档策略入口）
var runtime: RuntimeService = null
## 线程任务服务（后台计算任务提交与主线程回收）
var threading: Variant = null
## ECS 世界（实体管理与组件存储）
var ecs_world: EcsWorld = null
## ECS 调度器（系统分组与 tick 驱动）
var ecs_scheduler: EcsScheduler = null


# ============================================================
# 窄上下文工厂（子系统按需取用，避免拿到不该拿的服务）
# ============================================================

func create_gameplay_context() -> GameplayContext:
	var c := GameplayContext.new()
	c.log = log; c.event_bus = event_bus; c.app_flow = app_flow
	c.scene_host = scene_host; c.input = input; c.config = config
	return c

func create_ui_context() -> UiContext:
	var c := UiContext.new()
	c.log = log; c.ui = ui; c.input = input
	c.event_bus = event_bus; c.scene_host = scene_host; c.loc = loc
	c.save_service = save_service; c.config_service = config_service
	c.config = config; c.app_flow = app_flow; c.debug = debug; c.audio = audio
	return c

func create_save_context() -> SaveContext:
	var c := SaveContext.new()
	c.log = log; c.save_service = save_service
	c.config_service = config_service; c.config = config
	return c
