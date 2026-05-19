## DefValidator
## Def 校验器抽象基类。Game 层为每种 Def 类型（ItemDef、BuildingDef 等）创建子类。
## 注册到 ConfigService 后，validate_all() 时自动调用。
class_name DefValidator
extends RefCounted

## 此校验器对应的类型 key，如 "items"、"buildings"
var type_key: String = ""

## 校验该类型的所有定义。返回错误列表，空数组 = 全部通过。
func validate(p_defs: Dictionary) -> Array[String]:
	return []
