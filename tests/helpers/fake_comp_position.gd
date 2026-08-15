# tests/helpers/fake_comp_position.gd
## 测试辅助：纯类型键组件（无字段，仅作 ECS 组件类型标识）。
## 与 Dictionary 数据搭配使用——类引用是类型键，数据本体是 Dictionary。
class_name FakeCompPosition
extends RefCounted
