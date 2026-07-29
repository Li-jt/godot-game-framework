# tests/unit/event/test_event_bus.gd
## EventBus 单元测试。
extends GutTest

var _bus: EventBus


func before_each() -> void:
	_bus = EventBus.new()
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
	var a_called := false
	var b_called := false
	_bus.subscribe("event.a", func(_d = null): a_called = true)
	_bus.subscribe("event.b", func(_d = null): b_called = true)
	_bus.publish("event.a")
	assert_true(a_called)
	assert_false(b_called)


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
	assert_false(_bus.has_listeners("nonexistent.event"))


func test_unsubscribe_removes_listener() -> void:
	var count := 0
	var cb := func(_d = null): count += 1
	_bus.subscribe("test.event", cb)
	_bus.unsubscribe("test.event", cb)
	_bus.publish("test.event")
	assert_eq(count, 0)


func test_token_unsubscribe() -> void:
	var count := 0
	var token := _bus.subscribe("test.event", func(_d = null): count += 1)
	token.unsubscribe()
	_bus.publish("test.event")
	assert_eq(count, 0)


func test_unsubscribe_during_dispatch_does_not_break_loop() -> void:
	var calls: Array[String] = []
	var token_to_remove: EventToken
	var a_cb := func(_d = null): calls.append("A")
	var b_cb := func(_d = null):
		calls.append("B")
		token_to_remove.unsubscribe()
	var c_cb := func(_d = null): calls.append("C")
	_bus.subscribe("test.event", a_cb)
	_bus.subscribe("test.event", b_cb)
	token_to_remove = _bus.subscribe("test.event", c_cb)
	_bus.publish("test.event")
	assert_has(calls, "A")
	assert_has(calls, "B")


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
