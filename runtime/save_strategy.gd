## GF_SaveStrategy
## 存档策略抽象基类。Local/Remote/Hybrid 各自实现。
class_name GF_SaveStrategy
extends RefCounted

## 返回当前策略推荐的 GF_SaveProvider 类型。GF_SaveService 据此选择 Provider。
func get_provider_type() -> String:
	return "Local"
