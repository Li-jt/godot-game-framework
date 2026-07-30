# tests/unit/event/test_event_bus.gd
## GF_EventBus 单元测试。
## 注意：GDScript 闭包对 int/bool/String 等值类型按值捕获。
## 需要在闭包内修改的变量使用 Dictionary 或 Array 容器。
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


func test_multiple_events_independent() -> void:
	var state := {"a": false, "b": false}
	_bus.subscribe("event.a", func(_d = null): state["a"] = true)
	_bus.subscribe("event.b", func(_d = null): state["b"] = true)
	_bus.publish("event.a")
	assert_true(state["a"])
	assert_false(state["b"])


func test_publish_delivers_to_subscriber() -> void:
	var state := {"received": false, "data": null}
	_bus.subscribe("test.event", func(p_data):
		state["received"] = true
		state["data"] = p_data
	)
	var payload := {"msg": "hello"}
	_bus.publish("test.event", payload)
	assert_true(state["received"])
	assert_eq(state["data"], payload)


func test_publish_to_nonexistent_event_no_error() -> void:
	_bus.publish("nonexistent.event")
	assert_false(_bus.has_listeners("nonexistent.event"))


func test_unsubscribe_removes_listener() -> void:
	var state := {"count": 0}
	var cb := func(_d = null): state["count"] += 1
	_bus.subscribe("test.event", cb)
	_bus.unsubscribe("test.event", cb)
	_bus.publish("test.event")
	assert_eq(state["count"], 0)


func test_token_unsubscribe() -> void:
	var state := {"count": 0}
	var token := _bus.subscribe("test.event", func(_d = null): state["count"] += 1)
	token.unsubscribe()
	_bus.publish("test.event")
	assert_eq(state["count"], 0)


func test_unsubscribe_during_dispatch_does_not_break_loop() -> void:
	var calls: Array[String] = []
	var token_holder: Array = [null]
	var a_cb := func(_d = null): calls.append("A")
	var b_cb := func(_d = null):
		calls.append("B")
		var t: GF_EventToken = token_holder[0]
		if t != null:
			t.unsubscribe()
	var c_cb := func(_d = null): calls.append("C")
	_bus.subscribe("test.event", a_cb)
	_bus.subscribe("test.event", b_cb)
	token_holder[0] = _bus.subscribe("test.event", c_cb)
	_bus.publish("test.event")
	assert_has(calls, "A")
	assert_has(calls, "B")


func test_once_fires_only_first_time() -> void:
	var state := {"count": 0}
	_bus.subscribe_once("test.event", func(_d = null): state["count"] += 1)
	_bus.publish("test.event")
	assert_eq(state["count"], 1)
	_bus.publish("test.event")
	assert_eq(state["count"], 1)


func test_scope_dispose_all() -> void:
	var state := {"count": 0}
	_bus.subscribe("event.a", func(_d = null): state["count"] += 1, "ui")
	_bus.subscribe("event.b", func(_d = null): state["count"] += 1, "ui")
	_bus.subscribe("event.c", func(_d = null): state["count"] += 1, "gameplay")
	_bus.clear_scope("ui")
	_bus.publish("event.a")
	_bus.publish("event.b")
	assert_eq(state["count"], 0)
	_bus.publish("event.c")
	assert_eq(state["count"], 1)


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
