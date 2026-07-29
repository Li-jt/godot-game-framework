# tests/unit/event/test_event_bus.gd
## GF_EventBus 单元测试。
extends GutTest

var _bus: GF_EventBus


func before_each() -> void:
	_bus = GF_EventBus.new()
	_bus.module_name = "TestEventBus"
	_bus.init_module()


func after_each() -> void:
	_bus.dispose_module()
	_bus = null


func test_subscribe_returns_token() -> void:
	var token := _bus.subscribe("test.event", func(_d = null): pass)
	assert_not_null(token)
	assert_ne(token.id, "")


func test_multiple_subscribers_all_called() -> void:
	var calls: Array[String] = []
	_bus.subscribe("test.event", func(_d = null): calls.append("A"))
	_bus.subscribe("test.event", func(_d = null): calls.append("B"))
	_bus.subscribe("test.event", func(_d = null): calls.append("C"))
	_bus.publish("test.event")
	assert_eq(calls.size(), 3)


func test_publish_delivers_to_subscriber() -> void:
	var received := false
	var received_data = null
	_bus.subscribe("test.event", func(p_data):
		received = true
		received_data = p_data
	)
	var payload := {"msg": "hello"}
	_bus.publish("test.event", payload)
	assert_true(received)
	assert_eq(received_data, payload)


func test_publish_to_nonexistent_event_no_error() -> void:
	_bus.publish("nonexistent.event")


func test_unsubscribe_removes_listener() -> void:
	var count := 0
	var cb := func(_d = null): count += 1
	_bus.subscribe("test.event", cb)
	_bus.unsubscribe("test.event", cb)
	_bus.publish("test.event")
	assert_eq(count, 0)


func test_token_unsubscribe() -> void:
	var token := _bus.subscribe("test.event", func(_d = null): pass)
	token.unsubscribe()
	pass


func test_once_fires_only_first_time() -> void:
	var count := 0
	_bus.subscribe_once("test.event", func(_d = null): count += 1)
	_bus.publish("test.event")
	assert_eq(count, 1)
	_bus.publish("test.event")
	assert_eq(count, 1)


func test_scope_dispose_all() -> void:
	var count := 0
	_bus.subscribe("event.a", func(_d = null): count += 1, "ui")
	_bus.subscribe("event.b", func(_d = null): count += 1, "ui")
	_bus.subscribe("event.c", func(_d = null): count += 1, "gameplay")
	_bus.clear_scope("ui")
	_bus.publish("event.a")
	_bus.publish("event.b")
	assert_eq(count, 0)
	_bus.publish("event.c")
	assert_eq(count, 1)


func test_has_listeners_true_for_subscribed() -> void:
	_bus.subscribe("test.event", func(_d = null): pass)
	assert_true(_bus.has_listeners("test.event"))


func test_has_listeners_false_for_nonexistent() -> void:
	assert_false(_bus.has_listeners("nonexistent.event"))


func test_listener_count_accurate() -> void:
	_bus.subscribe("test.event", func(_d = null): pass)
	_bus.subscribe("test.event", func(_d = null): pass)
	assert_eq(_bus.listener_count("test.event"), 2)


func test_dispose_clears_all_listeners() -> void:
	_bus.subscribe("event.a", func(_d = null): pass)
	_bus.subscribe("event.b", func(_d = null): pass)
	assert_true(_bus.has_listeners("event.a"))
	_bus.dispose_module()
	assert_false(_bus.has_listeners("event.a"))
	assert_false(_bus.has_listeners("event.b"))


# EventDef
func test_publish_def_works() -> void:
	var received := false
	_bus.subscribe("test.typed", func(_d): received = true)
	var def = load("res://event/event_def.gd").new(&"test.typed")
	_bus.publish_def(def)
	assert_true(received)


func test_subscribe_def_works() -> void:
	var received := false
	var def = load("res://event/event_def.gd").new(&"test.typed")
	_bus.subscribe_def(def, func(_d): received = true)
	_bus.publish("test.typed")
	assert_true(received)


func test_has_listeners_def_works() -> void:
	var def = load("res://event/event_def.gd").new(&"item.changed")
	assert_false(_bus.has_listeners_def(def))
	_bus.subscribe("item.changed", func(_d): pass)
	assert_true(_bus.has_listeners_def(def))
