# tests/helpers/fake_save_provider.gd
## 内存存档 Provider，用于测试，不写磁盘。
class_name FakeSaveProvider
extends SaveProvider

var _store: Dictionary = {}  ## int slot → {"meta": ..., "data": ...}


func save(p_slot: int, p_data: Dictionary, p_meta: SaveMeta) -> OperationResult:
	_store[p_slot] = {"meta": {"save_version": p_meta.save_version}, "data": p_data}
	return OperationResult.ok()


func load_full(p_slot: int) -> OperationResult:
	if not _store.has(p_slot):
		return OperationResult.fail(OperationResult.ERR_NOT_FOUND, "slot not found: %d" % p_slot, "FakeSaveProvider")
	return OperationResult.ok(_store[p_slot])


func load(p_slot: int) -> OperationResult:
	if not _store.has(p_slot):
		return OperationResult.fail(OperationResult.ERR_NOT_FOUND, "slot not found: %d" % p_slot, "FakeSaveProvider")
	var wrapper: Dictionary = _store[p_slot]
	return OperationResult.ok(wrapper.get("data", {}))


func list_slots() -> OperationResult:
	return OperationResult.ok(_store.keys())


func delete(p_slot: int) -> OperationResult:
	_store.erase(p_slot)
	return OperationResult.ok()
