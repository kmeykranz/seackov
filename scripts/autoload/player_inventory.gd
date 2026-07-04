extends Node

const RARITY_ORDER := ["common", "rare", "legendary"]
const RARITY_VALUES := {
	"common": 25,
	"rare": 75,
	"legendary": 200,
}
const RARITY_LABELS := {
	"common": "沉积样本",
	"rare": "装置碎片",
	"legendary": "历史遗物",
}
const RARITY_COLORS := {
	"common": Color(1.0, 0.82, 0.18, 1.0),
	"rare": Color(0.18, 0.72, 1.0, 1.0),
	"legendary": Color(1.0, 0.28, 0.86, 1.0),
}

const STORAGE_BACKPACK := "backpack"
const STORAGE_WAREHOUSE := "warehouse"
const STORAGE_UPLOADED := "uploaded"
const BACKPACK_SLOT_COUNT := 18
const WAREHOUSE_SLOT_COUNT := 18
const MAX_STACK_SIZE := 64

var backpack_slots: Array = []
var warehouse_slots: Array = []
var uploaded_counts: Dictionary = {}
var research_points: int = 0
var total_extracted_value: int = 0


func _init() -> void:
	reset_runtime_state()


func reset_runtime_state() -> void:
	backpack_slots = _empty_slots(BACKPACK_SLOT_COUNT)
	warehouse_slots = _empty_slots(WAREHOUSE_SLOT_COUNT)
	uploaded_counts = _empty_counts()
	research_points = 0
	total_extracted_value = 0


func receive_extracted_counts(counts: Dictionary) -> Dictionary:
	var moved := _empty_counts()
	var sanitized := _sanitize_counts(counts)
	for rarity in RARITY_ORDER:
		var result := add_to_storage(STORAGE_BACKPACK, rarity, sanitized[rarity])
		moved[rarity] = int(result["counts"][rarity])

	total_extracted_value += _value_of_counts(moved)
	return _result(STORAGE_BACKPACK, moved)


func add_to_storage(storage_id: String, rarity: String, amount: int) -> Dictionary:
	var moved := _empty_counts()
	if not _is_transfer_storage(storage_id) or not RARITY_ORDER.has(rarity) or amount <= 0:
		return _result_with_remainder(storage_id, moved, maxi(0, amount))

	var slots := _slots_for_storage(storage_id)
	var remaining := amount
	for slot in slots:
		if remaining <= 0:
			break
		if String(slot.get("rarity", "")) != rarity:
			continue

		var capacity := MAX_STACK_SIZE - int(slot.get("count", 0))
		if capacity <= 0:
			continue

		var added := mini(capacity, remaining)
		slot["count"] = int(slot["count"]) + added
		remaining -= added
		moved[rarity] += added

	for slot in slots:
		if remaining <= 0:
			break
		if not _is_empty_stack(slot):
			continue

		var added := mini(MAX_STACK_SIZE, remaining)
		slot["rarity"] = rarity
		slot["count"] = added
		remaining -= added
		moved[rarity] += added

	return _result_with_remainder(storage_id, moved, remaining)


func add_stack_to_storage(storage_id: String, stack: Dictionary) -> Dictionary:
	var sanitized := _sanitize_stack(stack)
	return add_to_storage(storage_id, sanitized["rarity"], sanitized["count"])


func remove_from_storage(storage_id: String, rarity: String, amount: int) -> Dictionary:
	var moved := _empty_counts()
	if not _is_transfer_storage(storage_id) or not RARITY_ORDER.has(rarity) or amount <= 0:
		return _result_with_remainder(storage_id, moved, maxi(0, amount))

	var slots := _slots_for_storage(storage_id)
	var remaining := amount
	for index in range(slots.size()):
		if remaining <= 0:
			break

		var slot := _sanitize_stack(slots[index])
		if String(slot.get("rarity", "")) != rarity:
			continue

		var removed := mini(int(slot["count"]), remaining)
		slot["count"] = int(slot["count"]) - removed
		slots[index] = _empty_stack() if int(slot["count"]) <= 0 else slot
		remaining -= removed
		moved[rarity] += removed

	return _result_with_remainder(storage_id, moved, remaining)


func remove_counts_from_storage(storage_id: String, counts: Dictionary) -> Dictionary:
	var sanitized := _sanitize_counts(counts)
	var moved := _empty_counts()
	var remainder := 0
	for rarity in RARITY_ORDER:
		var result: Dictionary = remove_from_storage(storage_id, rarity, sanitized[rarity])
		moved[rarity] = int(result["counts"][rarity])
		remainder += int(result["remainder"])

	return _result_with_remainder(storage_id, moved, remainder)


func upload_all_from_backpack() -> Dictionary:
	var moved := _counts_from_slots(backpack_slots)
	for rarity in RARITY_ORDER:
		uploaded_counts[rarity] = get_uploaded_count(rarity) + moved[rarity]

	backpack_slots = _empty_slots(BACKPACK_SLOT_COUNT)
	research_points += _value_of_counts(moved)
	return _result(STORAGE_UPLOADED, moved)


func quick_transfer_slot(source_storage: String, slot_index: int) -> Dictionary:
	if not _is_transfer_storage(source_storage):
		return _result("", _empty_counts())

	var target_storage := STORAGE_WAREHOUSE if source_storage == STORAGE_BACKPACK else STORAGE_BACKPACK
	var stack := take_slot_stack(source_storage, slot_index)
	if _is_empty_stack(stack):
		return _result(target_storage, _empty_counts())

	var result := add_stack_to_storage(target_storage, stack)
	var remainder := int(result["remainder"])
	if remainder > 0:
		add_to_storage(source_storage, stack["rarity"], remainder)

	return _result(target_storage, result["counts"])


func take_slot_stack(storage_id: String, slot_index: int) -> Dictionary:
	if not _has_slot(storage_id, slot_index):
		return _empty_stack()

	var slots := _slots_for_storage(storage_id)
	var stack := _sanitize_stack(slots[slot_index])
	slots[slot_index] = _empty_stack()
	return stack


func take_half_slot_stack(storage_id: String, slot_index: int) -> Dictionary:
	if not _has_slot(storage_id, slot_index):
		return _empty_stack()

	var slots := _slots_for_storage(storage_id)
	var slot := _sanitize_stack(slots[slot_index])
	if _is_empty_stack(slot):
		return _empty_stack()

	var taken_count := int(ceil(float(slot["count"]) / 2.0))
	slot["count"] = int(slot["count"]) - taken_count
	slots[slot_index] = _empty_stack() if int(slot["count"]) <= 0 else slot
	return {
		"rarity": slot["rarity"],
		"count": taken_count,
	}


func place_stack_in_slot(storage_id: String, slot_index: int, incoming_stack: Dictionary) -> Dictionary:
	if not _has_slot(storage_id, slot_index):
		return _sanitize_stack(incoming_stack)

	var incoming := _sanitize_stack(incoming_stack)
	if _is_empty_stack(incoming):
		return _empty_stack()

	var slots := _slots_for_storage(storage_id)
	var slot := _sanitize_stack(slots[slot_index])
	if _is_empty_stack(slot):
		var placed := mini(MAX_STACK_SIZE, int(incoming["count"]))
		slots[slot_index] = {"rarity": incoming["rarity"], "count": placed}
		incoming["count"] = int(incoming["count"]) - placed
		return _empty_stack() if int(incoming["count"]) <= 0 else incoming

	if String(slot["rarity"]) == String(incoming["rarity"]):
		var capacity := MAX_STACK_SIZE - int(slot["count"])
		var placed := mini(capacity, int(incoming["count"]))
		slot["count"] = int(slot["count"]) + placed
		slots[slot_index] = slot
		incoming["count"] = int(incoming["count"]) - placed
		return _empty_stack() if int(incoming["count"]) <= 0 else incoming

	# Different item types cannot merge into one grid cell; left-click swaps stacks.
	slots[slot_index] = incoming
	return slot


func place_one_in_slot(storage_id: String, slot_index: int, incoming_stack: Dictionary) -> Dictionary:
	if not _has_slot(storage_id, slot_index):
		return _sanitize_stack(incoming_stack)

	var incoming := _sanitize_stack(incoming_stack)
	if _is_empty_stack(incoming):
		return _empty_stack()

	var slots := _slots_for_storage(storage_id)
	var slot := _sanitize_stack(slots[slot_index])
	if _is_empty_stack(slot):
		slots[slot_index] = {"rarity": incoming["rarity"], "count": 1}
		incoming["count"] = int(incoming["count"]) - 1
		return _empty_stack() if int(incoming["count"]) <= 0 else incoming

	if String(slot["rarity"]) == String(incoming["rarity"]) and int(slot["count"]) < MAX_STACK_SIZE:
		slot["count"] = int(slot["count"]) + 1
		slots[slot_index] = slot
		incoming["count"] = int(incoming["count"]) - 1

	return _empty_stack() if int(incoming["count"]) <= 0 else incoming


func get_slot_stack(storage_id: String, slot_index: int) -> Dictionary:
	if not _has_slot(storage_id, slot_index):
		return _empty_stack()

	return _sanitize_stack(_slots_for_storage(storage_id)[slot_index])


func get_storage_slot_count(storage_id: String) -> int:
	if storage_id == STORAGE_BACKPACK:
		return BACKPACK_SLOT_COUNT
	if storage_id == STORAGE_WAREHOUSE:
		return WAREHOUSE_SLOT_COUNT
	return 0


func get_backpack_count(rarity: String) -> int:
	return int(_counts_from_slots(backpack_slots).get(rarity, 0))


func get_warehouse_count(rarity: String) -> int:
	return int(_counts_from_slots(warehouse_slots).get(rarity, 0))


func get_uploaded_count(rarity: String) -> int:
	return int(uploaded_counts.get(rarity, 0))


func get_backpack_total_count() -> int:
	return _count_items(_counts_from_slots(backpack_slots))


func get_warehouse_total_count() -> int:
	return _count_items(_counts_from_slots(warehouse_slots))


func get_uploaded_total_count() -> int:
	return _count_items(uploaded_counts)


func get_backpack_value() -> int:
	return _value_of_counts(_counts_from_slots(backpack_slots))


func get_warehouse_value() -> int:
	return _value_of_counts(_counts_from_slots(warehouse_slots))


func get_uploaded_value() -> int:
	return _value_of_counts(uploaded_counts)


func get_rarity_label(rarity: String) -> String:
	return String(RARITY_LABELS.get(rarity, rarity))


func get_rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, Color(0.9, 0.9, 0.9, 1.0))


func format_counts(counts: Dictionary) -> String:
	var parts: Array[String] = []
	for rarity in RARITY_ORDER:
		var count := int(counts.get(rarity, 0))
		if count > 0:
			parts.append("%s x%d" % [get_rarity_label(rarity), count])

	return "无" if parts.is_empty() else "，".join(parts)


func format_stack(stack: Dictionary) -> String:
	var sanitized := _sanitize_stack(stack)
	if _is_empty_stack(sanitized):
		return "空"
	return "%s x%d" % [get_rarity_label(sanitized["rarity"]), sanitized["count"]]


func get_summary_text() -> String:
	return "背包：%s\n仓库：%s\n已上传：%s\n研究点：%d" % [
		format_counts(_counts_from_slots(backpack_slots)),
		format_counts(_counts_from_slots(warehouse_slots)),
		format_counts(uploaded_counts),
		research_points,
	]


func is_empty_stack(stack: Dictionary) -> bool:
	return _is_empty_stack(stack)


func _result(destination: String, moved: Dictionary) -> Dictionary:
	return _result_with_remainder(destination, moved, 0)


func _result_with_remainder(destination: String, moved: Dictionary, remainder: int) -> Dictionary:
	return {
		"destination": destination,
		"counts": _sanitize_counts(moved),
		"total_count": _count_items(moved),
		"value": _value_of_counts(moved),
		"remainder": maxi(0, remainder),
	}


func _sanitize_counts(counts: Dictionary) -> Dictionary:
	var sanitized := _empty_counts()
	for rarity in RARITY_ORDER:
		sanitized[rarity] = maxi(0, int(counts.get(rarity, 0)))
	return sanitized


func _sanitize_stack(stack: Dictionary) -> Dictionary:
	var rarity := String(stack.get("rarity", ""))
	var count := maxi(0, int(stack.get("count", 0)))
	if not RARITY_ORDER.has(rarity) or count <= 0:
		return _empty_stack()
	return {
		"rarity": rarity,
		"count": mini(MAX_STACK_SIZE, count),
	}


func _empty_counts() -> Dictionary:
	var counts := {}
	for rarity in RARITY_ORDER:
		counts[rarity] = 0
	return counts


func _empty_stack() -> Dictionary:
	return {
		"rarity": "",
		"count": 0,
	}


func _empty_slots(slot_count: int) -> Array:
	var slots := []
	for _index in range(slot_count):
		slots.append(_empty_stack())
	return slots


func _is_transfer_storage(storage_id: String) -> bool:
	return storage_id == STORAGE_BACKPACK or storage_id == STORAGE_WAREHOUSE


func _slots_for_storage(storage_id: String) -> Array:
	if storage_id == STORAGE_BACKPACK:
		return backpack_slots
	if storage_id == STORAGE_WAREHOUSE:
		return warehouse_slots
	return []


func _has_slot(storage_id: String, slot_index: int) -> bool:
	return _is_transfer_storage(storage_id) and slot_index >= 0 and slot_index < _slots_for_storage(storage_id).size()


func _is_empty_stack(stack: Dictionary) -> bool:
	return String(stack.get("rarity", "")) == "" or int(stack.get("count", 0)) <= 0


func _counts_from_slots(slots: Array) -> Dictionary:
	var counts := _empty_counts()
	for slot in slots:
		var sanitized := _sanitize_stack(slot)
		if _is_empty_stack(sanitized):
			continue
		counts[sanitized["rarity"]] += int(sanitized["count"])
	return counts


func _count_items(counts: Dictionary) -> int:
	var total := 0
	for rarity in RARITY_ORDER:
		total += int(counts.get(rarity, 0))
	return total


func _value_of_counts(counts: Dictionary) -> int:
	var total := 0
	for rarity in RARITY_ORDER:
		total += int(counts.get(rarity, 0)) * int(RARITY_VALUES[rarity])
	return total
