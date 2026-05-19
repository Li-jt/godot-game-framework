## AppConfig
## 项目运行配置的总容器。
## 由 Environment 模块加载多个配置来源（JSON、.env、命令行）后合并生成。
## 运行时通过 AppConfigService 获取，不直接实例化。
class_name AppConfig
extends RefCounted

var app: AppSection = AppSection.new()
var runtime: RuntimeSection = RuntimeSection.new()
var network: NetworkSection = NetworkSection.new()
var save: SaveSection = SaveSection.new()
var resource: ResourceSection = ResourceSection.new()
var logging: LoggingSection = LoggingSection.new()
var debug: DebugSection = DebugSection.new()
var feature_flags: FeatureFlagsSection = FeatureFlagsSection.new()


# ============================================================
# 子配置类
# ============================================================

## 应用基础信息
class AppSection:
	extends RefCounted
	var name: String = ""
	var environment: String = "dev"
	var version: String = "0.1.0"


## 运行时模式配置
class RuntimeSection:
	extends RefCounted
	var mode: String = "Local"
	var enable_prediction: bool = false
	var enable_rollback: bool = false
	var enable_reconciliation: bool = false


## 网络配置
class NetworkSection:
	extends RefCounted
	var api_base_url: String = ""
	var ws_url: String = ""
	var request_timeout_ms: int = 8000
	var retry_count: int = 2
	var use_mock_api: bool = true


## 存档配置
class SaveSection:
	extends RefCounted
	var provider: String = "Local"
	var local_save_root: String = "./saves"
	var local_cache_root: String = "./cache"
	var auto_save_enabled: bool = false
	var auto_save_interval_seconds: int = 120
	var remote_save_endpoint: String = "/save/upload"


## 资源配置
class ResourceSection:
	extends RefCounted
	var mode: String = "Local"
	var base_path: String = "./content"
	var enable_cache: bool = true


## 日志配置
class LoggingSection:
	extends RefCounted
	var level: String = "Debug"
	var write_to_file: bool = true
	var log_root: String = "./logs"


## 调试配置
class DebugSection:
	extends RefCounted
	var enable_debug_panel: bool = false
	var show_prediction_state: bool = false
	var show_network_stats: bool = false


## 功能开关配置
class FeatureFlagsSection:
	extends RefCounted
	var enable_remote_authority: bool = false
	var enable_cloud_save: bool = false
	var enable_local_fallback: bool = true
	var enable_prediction: bool = false
	var enable_rollback: bool = false
	var enable_debug_panel: bool = true
	var enable_network_stats: bool = false
	var enable_auto_save: bool = false
	var enable_tutorial: bool = false
