# tests/helpers/fake_save_provider.gd
## 内存存档 Provider，用于测试，不写磁盘。
class_name GF_FakeSaveProvider
extends GF_SaveProvider

var _store: Dictionary = {}  ## int slot → {"meta": ..., "data": ...}


func save(p_slot: int, p_data: Dictionary, p_meta: GF_SaveMeta) -> GF_OperationResult:
	_store[p_slot] = {
		"meta": {"save_version": p_meta.save_version, "save_mode": p_meta.save_mode},
		"data": p_data,
	}
	return GF_OperationResult.ok()


func load_full(p_slot: int) -> GF_OperationResult:
	if not _store.has(p_slot):
		return GF_OperationResult.fail(GF_OperationResult.ERR_NOT_FOUND, "slot not found: %d" % p_slot, "GF_FakeSaveProvider")
	return GF_OperationResult.ok(_store[p_slot])


func load(p_slot: int) -> GF_OperationResult:
	if not _store.has(p_slot):
		return GF_OperationResult.fail(GF_OperationResult.ERR_NOT_FOUND, "slot not found: %d" % p_slot, "GF_FakeSaveProvider")
	var wrapper: Dictionary = _store[p_slot]
	return GF_OperationResult.ok(wrapper.get("data", {}))


func list_slots() -> GF_OperationResult:
	return GF_OperationResult.ok(_store.keys())


func delete(p_slot: int) -> GF_OperationResult:
	_store.erase(p_slot)
	return GF_OperationResult.ok()
