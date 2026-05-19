## SaveStrategy
## 存档策略抽象基类。Local/Remote/Hybrid 各自实现。
class_name SaveStrategy
extends RefCounted

## 返回当前策略推荐的 SaveProvider 类型。SaveService 据此选择 Provider。
func get_provider_type() -> String:
	return "Local"
