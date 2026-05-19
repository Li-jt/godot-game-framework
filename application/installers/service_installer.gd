## ServiceInstaller（抽象基类）
## 服务安装器。负责一组相关服务的创建、配置和注册。
## 每个子类实现 install()，返回安装结果。
class_name ServiceInstaller
extends RefCounted

## 安装服务组。p_deps 为上游安装器产出的依赖 Dictionary。
## 返回 OperationResult，data 为 {service_variable_name: service_instance}。
func install(p_deps: Dictionary) -> OperationResult:
	return OperationResult.fail(OperationResult.ERR_INTERNAL, "未实现", "ServiceInstaller")
