## GF_EcsQuery — 查询条件构建器。
## 支持链式调用，通过 with/without/optional 组合过滤条件。
## 调用 build() 返回预编译的 GF_EcsQueryPlan。
class_name GF_EcsQuery
extends GF_IEcsQuery

var _with_types: Array = []
var _without_types: Array = []
var _optional_types: Array = []


## 要求实体必须拥有指定组件。p_type 为 class_name 引用（如 Position）。
func with_component(p_type: Variant) -> GF_EcsQuery:
	_with_types.append(p_type)
	return self


## 要求实体不得拥有指定组件。
func without_component(p_type: Variant) -> GF_EcsQuery:
	_without_types.append(p_type)
	return self


## 实体可选拥有此组件（不影响匹配，但结果中会附带数据）。
func optional_component(p_type: Variant) -> GF_EcsQuery:
	_optional_types.append(p_type)
	return self


## 构建预编译查询计划。
func build() -> GF_EcsQueryPlan:
	return GF_EcsQueryPlan.new(_with_types, _without_types, _optional_types)


## 重置查询条件。
func reset() -> void:
	_with_types.clear()
	_without_types.clear()
	_optional_types.clear()
