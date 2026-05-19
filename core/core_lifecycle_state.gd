## CoreLifecycleState
## 模块生命周期状态枚举。
## 所有 Framework 服务模块必须统一遵守此状态机，不允许各模块自定义状态。
##
## 状态流转规则：
##   UNINITIALIZED -> INITIALIZING -> INITIALIZED   （init_module 完成）
##   INITIALIZED   -> CONFIGURING  -> READY           （configure / finalize_configuration 完成）
##   INITIALIZED   -> CONFIGURING  -> FAILED           （configure 失败）
##   任意状态      -> DISPOSED                          （释放，不可逆）
class_name CoreLifecycleState
extends RefCounted

enum State {
	UNINITIALIZED,  # 未初始化
	INITIALIZING,   # 初始化中
	INITIALIZED,    # 初始化完成，等待配置
	CONFIGURING,    # 配置中
	READY,          # 已就绪
	FAILED,         # 失败
	DISPOSED        # 已释放
}
