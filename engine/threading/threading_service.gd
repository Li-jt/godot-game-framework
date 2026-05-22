## ThreadingService
## 框架级线程任务服务。提供任务队列、优先级调度、取消、超时、重试、统计与主线程回调。
## 业务层仅提交“纯数据计算任务”，不得在子线程直接操作场景树或 UI。
class_name ThreadingService
extends ModuleLifecycle


## 内部任务记录结构。仅在主线程读写。
class JobRecord:
	var job_id: int = 0
	var work: Callable = Callable()
	var options: ThreadJobOptions = null
	var token: ThreadJobToken = null
	var state: int = ThreadJobState.Value.QUEUED
	var attempts: int = 0
	var submitted_at_ms: int = 0
	var started_at_ms: int = -1
	var finished_at_ms: int = -1
	var next_dispatch_at_ms: int = 0
	var worker_task_id: int = -1
	var cancel_reason: String = ""
	var final_result: OperationResult = null


var _enabled: bool = true
var _max_active_jobs: int = 4
var _max_dispatch_per_tick: int = 2
var _default_timeout_ms: int = 30000
var _slow_job_warn_ms: int = 120
var _history_limit: int = 256

var _log: LogService = null
var _next_job_id: int = 1
var _jobs: Dictionary = {}               # job_id -> JobRecord
var _queue: Array[int] = []              # 等待调度的任务
var _active: Array[int] = []             # 正在运行的任务
var _orphan_task_ids: Array[int] = []    # 已终态但线程尚未退出的任务
var _terminal_order: Array[int] = []     # 终态任务顺序，用于清理

var _worker_result_mutex: Mutex = Mutex.new()
var _worker_results: Dictionary = {}      # job_id -> OperationResult

var _stats := {
	"submitted": 0,
	"completed": 0,
	"failed": 0,
	"cancelled": 0,
	"timed_out": 0,
	"retried": 0,
	"running_peak": 0,
	"queue_peak": 0,
	"avg_duration_ms": 0.0,
	"completed_with_duration": 0,
}


## 生命周期初始化。
func _on_init() -> OperationResult:
	return OperationResult.ok()


## 配置线程服务。
func configure(p_config: AppConfig.ThreadingSection, p_log: LogService) -> OperationResult:
	if p_config == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "threading_config 不能为 null", module_name)
	if p_log == null:
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "log 不能为 null", module_name)
	_enabled = p_config.enabled
	_max_active_jobs = maxi(1, p_config.max_active_jobs)
	_max_dispatch_per_tick = maxi(1, p_config.max_dispatch_per_tick)
	_default_timeout_ms = maxi(1, p_config.default_timeout_ms)
	_slow_job_warn_ms = maxi(1, p_config.slow_job_warn_ms)
	_history_limit = maxi(32, p_config.history_limit)
	_log = p_log
	return OperationResult.ok()


## 生命周期释放。
func _on_dispose() -> OperationResult:
	cancel_all("threading_service_disposed")
	_jobs.clear()
	_queue.clear()
	_active.clear()
	_orphan_task_ids.clear()
	_terminal_order.clear()
	_worker_result_mutex.lock()
	_worker_results.clear()
	_worker_result_mutex.unlock()
	return OperationResult.ok()


## 运行时就绪检查（供 ServiceRegistry.verify 调用）。
func is_runtime_ready() -> bool:
	return is_ready()


## 每帧泵送线程队列。建议由 Scheduler 在 FRAME 组持续调用。
func pump(_p_delta: float) -> void:
	if not is_ready():
		return
	_cleanup_orphan_tasks()
	_collect_completed_jobs()
	_handle_timeouts()
	_dispatch_jobs()


## 提交线程任务。任务签名：func(token: ThreadJobToken) -> Variant|OperationResult
func submit(p_work: Callable, p_options: ThreadJobOptions = null) -> OperationResult:
	if not is_ready():
		return OperationResult.fail(OperationResult.ERR_PRECONDITION, "ThreadingService 未 ready", module_name)
	if not p_work.is_valid():
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "任务 Callable 无效", module_name)

	var options := p_options if p_options != null else ThreadJobOptions.new()
	var job_id := _next_job_id
	_next_job_id += 1

	var record := JobRecord.new()
	record.job_id = job_id
	record.work = p_work
	record.options = options
	record.token = ThreadJobToken.new()
	record.state = ThreadJobState.Value.QUEUED
	record.submitted_at_ms = Time.get_ticks_msec()
	record.next_dispatch_at_ms = record.submitted_at_ms

	if record.options.name.is_empty():
		record.options.name = "job_%d" % job_id

	_jobs[job_id] = record
	_queue.append(job_id)
	_sort_queue()
	_stats["submitted"] += 1
	_stats["queue_peak"] = maxi(_stats["queue_peak"], _queue.size())

	# 禁用线程时走主线程同步执行，保证功能可用。
	if not _enabled:
		_execute_inline(record)

	var handle := ThreadJobHandle.new()
	handle.job_id = job_id
	handle.job_name = record.options.name
	handle.bind(self)
	return OperationResult.ok(handle)


## 取消指定任务。运行中任务为协作式取消：立即进入终态，后台线程稍后自行退出。
func cancel_job(p_job_id: int, p_reason: String = "cancelled_by_request") -> OperationResult:
	var record := _jobs.get(p_job_id, null) as JobRecord
	if record == null:
		return OperationResult.fail(OperationResult.ERR_NOT_FOUND, "任务不存在: %d" % p_job_id, module_name)
	if ThreadJobState.is_terminal(record.state):
		return OperationResult.ok()

	record.token.request_cancel(p_reason)
	record.cancel_reason = p_reason

	if record.state in [ThreadJobState.Value.QUEUED, ThreadJobState.Value.RETRY_WAIT]:
		_queue.erase(p_job_id)
		_finalize_job(record, ThreadJobState.Value.CANCELLED, _cancelled_result("任务在队列中被取消: %s" % p_reason))
		return OperationResult.ok()

	if record.state == ThreadJobState.Value.RUNNING:
		_active.erase(p_job_id)
		if record.worker_task_id >= 0:
			_orphan_task_ids.append(record.worker_task_id)
		_finalize_job(record, ThreadJobState.Value.CANCELLED, _cancelled_result("任务运行中被取消: %s" % p_reason))
		return OperationResult.ok()

	return OperationResult.ok()


## 按标签取消任务（包含排队和运行中任务）。
func cancel_by_tag(p_tag: String, p_reason: String = "cancelled_by_tag") -> int:
	if p_tag.is_empty():
		return 0
	var cancelled := 0
	for job_id in _jobs.keys():
		var record := _jobs[job_id] as JobRecord
		if record == null or record.options == null:
			continue
		if record.options.tag != p_tag:
			continue
		var result := cancel_job(job_id, p_reason)
		if result.is_ok():
			cancelled += 1
	return cancelled


## 取消所有未完成任务。
func cancel_all(p_reason: String = "cancelled_all") -> int:
	var cancelled := 0
	var ids: Array[int] = []
	for job_id in _jobs.keys():
		ids.append(int(job_id))
	for job_id in ids:
		var record := _jobs.get(job_id, null) as JobRecord
		if record == null:
			continue
		if ThreadJobState.is_terminal(record.state):
			continue
		var result := cancel_job(job_id, p_reason)
		if result.is_ok():
			cancelled += 1
	return cancelled


## 查询任务状态。
func get_job_state(p_job_id: int) -> int:
	var record := _jobs.get(p_job_id, null) as JobRecord
	if record == null:
		return ThreadJobState.Value.FAILED
	return record.state


## 查询任务摘要。
func get_job_summary(p_job_id: int) -> ThreadJobSummary:
	var record := _jobs.get(p_job_id, null) as JobRecord
	if record == null:
		return null
	return _build_summary(record)


## 查询运行统计快照。
func get_stats() -> Dictionary:
	return _stats.duplicate(true)


## 获取最新终态任务摘要列表（按完成时间倒序）。
func get_recent_history(p_limit: int = 20) -> Array[ThreadJobSummary]:
	var limit := maxi(1, p_limit)
	var result: Array[ThreadJobSummary] = []
	for i in range(_terminal_order.size() - 1, -1, -1):
		var job_id: int = _terminal_order[i]
		var record := _jobs.get(job_id, null) as JobRecord
		if record == null:
			continue
		result.append(_build_summary(record))
		if result.size() >= limit:
			break
	return result


## 内部：在禁用线程模式下同步执行任务。
func _execute_inline(p_record: JobRecord) -> void:
	p_record.state = ThreadJobState.Value.RUNNING
	p_record.attempts += 1
	p_record.started_at_ms = Time.get_ticks_msec()
	var result := _execute_work(p_record.work, p_record.token)
	_finalize_or_retry(p_record, result)


## 内部：收集已完成的后台任务。
func _collect_completed_jobs() -> void:
	var completed: Array[int] = []
	for job_id in _active:
		var record := _jobs.get(job_id, null) as JobRecord
		if record == null:
			completed.append(job_id)
			continue
		if record.worker_task_id < 0:
			completed.append(job_id)
			continue
		if WorkerThreadPool.is_task_completed(record.worker_task_id):
			WorkerThreadPool.wait_for_task_completion(record.worker_task_id)
			completed.append(job_id)

	for job_id in completed:
		_active.erase(job_id)
		var record := _jobs.get(job_id, null) as JobRecord
		if record == null:
			continue
		if ThreadJobState.is_terminal(record.state):
			continue
		var result := _consume_worker_result(job_id)
		if result == null:
			result = OperationResult.fail(OperationResult.ERR_INTERNAL, "任务未返回结果: %d" % job_id, module_name)
		_finalize_or_retry(record, result)


## 内部：处理运行中任务超时。
func _handle_timeouts() -> void:
	var now_ms := Time.get_ticks_msec()
	var timed_out_ids: Array[int] = []
	for job_id in _active:
		var record := _jobs.get(job_id, null) as JobRecord
		if record == null:
			continue
		if record.started_at_ms < 0:
			continue
		var timeout_ms := record.options.resolve_timeout_ms(_default_timeout_ms)
		if timeout_ms <= 0:
			continue
		if now_ms - record.started_at_ms < timeout_ms:
			continue
		timed_out_ids.append(job_id)

	for job_id in timed_out_ids:
		_active.erase(job_id)
		var record := _jobs.get(job_id, null) as JobRecord
		if record == null or ThreadJobState.is_terminal(record.state):
			continue
		record.token.request_cancel("timeout")
		record.cancel_reason = "timeout"
		if record.worker_task_id >= 0:
			_orphan_task_ids.append(record.worker_task_id)
		var result := OperationResult.fail(
			OperationResult.ERR_TIMEOUT,
			"任务超时（%d ms）: %s" % [record.options.resolve_timeout_ms(_default_timeout_ms), record.options.name],
			module_name
		)
		_finalize_job(record, ThreadJobState.Value.TIMEOUT, result)


## 内部：按优先级与预算分发任务到 WorkerThreadPool。
func _dispatch_jobs() -> void:
	if not _enabled:
		return
	var dispatched := 0
	var now_ms := Time.get_ticks_msec()
	while _active.size() < _max_active_jobs and dispatched < _max_dispatch_per_tick:
		var job_id := _pop_next_dispatchable_job(now_ms)
		if job_id < 0:
			break
		var record := _jobs.get(job_id, null) as JobRecord
		if record == null or ThreadJobState.is_terminal(record.state):
			continue
		record.state = ThreadJobState.Value.RUNNING
		record.attempts += 1
		record.started_at_ms = now_ms
		var high_priority := ThreadJobPriority.is_high_priority(record.options.priority)
		var task_desc := "ThreadJob#%d:%s" % [record.job_id, record.options.name]
		record.worker_task_id = WorkerThreadPool.add_task(
			Callable(self, "_worker_execute_job").bind(record.job_id, record.work, record.token),
			high_priority,
			task_desc
		)
		_active.append(record.job_id)
		dispatched += 1
	_stats["running_peak"] = maxi(_stats["running_peak"], _active.size())


## 内部：从队列中取出可分发任务（考虑重试等待窗口）。
func _pop_next_dispatchable_job(p_now_ms: int) -> int:
	for i in range(_queue.size()):
		var job_id := _queue[i]
		var record := _jobs.get(job_id, null) as JobRecord
		if record == null:
			_queue.remove_at(i)
			return -1
		if record.state == ThreadJobState.Value.CANCELLED:
			_queue.remove_at(i)
			return -1
		if record.next_dispatch_at_ms > p_now_ms:
			continue
		_queue.remove_at(i)
		return job_id
	return -1


## 内部：任务完成后根据结果执行重试或终态收口。
func _finalize_or_retry(p_record: JobRecord, p_result: OperationResult) -> void:
	if p_result != null and p_result.is_fail() and p_record.attempts <= p_record.options.max_retries:
		p_record.state = ThreadJobState.Value.RETRY_WAIT
		var wait_ms := maxi(1, p_record.options.retry_backoff_ms) * p_record.attempts
		p_record.next_dispatch_at_ms = Time.get_ticks_msec() + wait_ms
		_queue.append(p_record.job_id)
		_sort_queue()
		_stats["retried"] += 1
		return

	if p_result == null:
		p_result = OperationResult.fail(OperationResult.ERR_INTERNAL, "任务结果为空: %d" % p_record.job_id, module_name)
	var terminal_state := ThreadJobState.Value.COMPLETED if p_result.is_ok() else ThreadJobState.Value.FAILED
	_finalize_job(p_record, terminal_state, p_result)


## 内部：统一写入终态、更新统计并触发回调。
func _finalize_job(p_record: JobRecord, p_state: int, p_result: OperationResult) -> void:
	p_record.state = p_state
	p_record.finished_at_ms = Time.get_ticks_msec()
	p_record.final_result = p_result

	var summary := _build_summary(p_record)
	_terminal_order.append(p_record.job_id)

	match p_state:
		ThreadJobState.Value.COMPLETED:
			_stats["completed"] += 1
		ThreadJobState.Value.FAILED:
			_stats["failed"] += 1
		ThreadJobState.Value.CANCELLED:
			_stats["cancelled"] += 1
		ThreadJobState.Value.TIMEOUT:
			_stats["timed_out"] += 1

	var duration := summary.duration_ms()
	if duration >= 0:
		var count: int = _stats["completed_with_duration"]
		var avg: float = _stats["avg_duration_ms"]
		var new_count := count + 1
		_stats["completed_with_duration"] = new_count
		_stats["avg_duration_ms"] = ((avg * count) + duration) / float(new_count)
		if duration >= _slow_job_warn_ms and _log != null:
			_log.warning("Threading", "慢任务 %s 耗时 %d ms（state=%s）" % [summary.name, duration, summary.status_text()])

	_emit_callbacks(summary, p_record.options.callbacks)
	_prune_terminal_jobs()


## 内部：对终态任务触发主线程回调。
func _emit_callbacks(p_summary: ThreadJobSummary, p_callbacks: ThreadJobCallbacks) -> void:
	if p_callbacks == null:
		return
	match p_summary.state:
		ThreadJobState.Value.COMPLETED:
			_try_call(p_callbacks.on_completed, p_summary)
		ThreadJobState.Value.FAILED:
			_try_call(p_callbacks.on_failed, p_summary)
		ThreadJobState.Value.CANCELLED:
			_try_call(p_callbacks.on_cancelled, p_summary)
		ThreadJobState.Value.TIMEOUT:
			_try_call(p_callbacks.on_timeout, p_summary)
	_try_call(p_callbacks.on_finished, p_summary)


## 内部：安全调用回调，避免单个回调异常中断流程。
func _try_call(p_callable: Callable, p_summary: ThreadJobSummary) -> void:
	if not p_callable.is_valid():
		return
	p_callable.call(p_summary)


## 内部：按照配置上限清理历史终态任务，防止长时运行内存增长。
func _prune_terminal_jobs() -> void:
	while _terminal_order.size() > _history_limit:
		var oldest_job_id: int = _terminal_order[0]
		_terminal_order.remove_at(0)
		_jobs.erase(oldest_job_id)
		_queue.erase(oldest_job_id)
		_active.erase(oldest_job_id)


## 内部：按优先级与提交时间对队列排序。
func _sort_queue() -> void:
	_queue.sort_custom(func(a: int, b: int):
		var ra := _jobs.get(a, null) as JobRecord
		var rb := _jobs.get(b, null) as JobRecord
		if ra == null:
			return false
		if rb == null:
			return true
		if ra.options.priority != rb.options.priority:
			return ra.options.priority < rb.options.priority
		return ra.submitted_at_ms < rb.submitted_at_ms
	)


## 内部：回收已进入终态但后台线程尚未退出的任务。
func _cleanup_orphan_tasks() -> void:
	var completed_ids: Array[int] = []
	for task_id in _orphan_task_ids:
		if WorkerThreadPool.is_task_completed(task_id):
			WorkerThreadPool.wait_for_task_completion(task_id)
			completed_ids.append(task_id)
	for task_id in completed_ids:
		_orphan_task_ids.erase(task_id)


## 内部：工作线程执行入口。
func _worker_execute_job(p_job_id: int, p_work: Callable, p_token: ThreadJobToken) -> void:
	var result := _execute_work(p_work, p_token)
	_worker_result_mutex.lock()
	_worker_results[p_job_id] = result
	_worker_result_mutex.unlock()


## 内部：执行任务主体并标准化返回值。
func _execute_work(p_work: Callable, p_token: ThreadJobToken) -> OperationResult:
	if p_token != null and p_token.is_cancel_requested():
		return _cancelled_result("任务执行前已取消")
	if not p_work.is_valid():
		return OperationResult.fail(OperationResult.ERR_BAD_REQUEST, "任务 Callable 无效", module_name)
	var ret = null
	if p_work.get_argument_count() <= 0:
		ret = p_work.call()
	else:
		ret = p_work.call(p_token)
	if p_token != null and p_token.is_cancel_requested():
		return _cancelled_result("任务执行过程中被取消")
	if ret is OperationResult:
		return ret as OperationResult
	return OperationResult.ok(ret)


## 内部：消费工作线程结果（一次性读取）。
func _consume_worker_result(p_job_id: int) -> OperationResult:
	_worker_result_mutex.lock()
	var result := _worker_results.get(p_job_id, null) as OperationResult
	_worker_results.erase(p_job_id)
	_worker_result_mutex.unlock()
	return result


## 内部：构造取消结果对象。
func _cancelled_result(p_message: String) -> OperationResult:
	return OperationResult.fail(OperationResult.ERR_PRECONDITION, p_message, module_name)


## 内部：构造任务摘要快照。
func _build_summary(p_record: JobRecord) -> ThreadJobSummary:
	var s := ThreadJobSummary.new()
	s.job_id = p_record.job_id
	s.name = p_record.options.name
	s.tag = p_record.options.tag
	s.state = p_record.state
	s.attempts = p_record.attempts
	s.submitted_at_ms = p_record.submitted_at_ms
	s.started_at_ms = p_record.started_at_ms
	s.finished_at_ms = p_record.finished_at_ms
	s.timeout_ms = p_record.options.resolve_timeout_ms(_default_timeout_ms)
	s.cancel_reason = p_record.cancel_reason
	s.metadata = p_record.options.metadata.duplicate(true)
	s.result = p_record.final_result
	return s

