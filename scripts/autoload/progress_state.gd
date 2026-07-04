extends Node

signal progress_changed

const DEFAULT_SAVE_PATH := "user://seackov_progress.json"
const INITIAL_UNLOCKED_REGION_COUNT := 1
const MAX_REGION_COUNT := 4
const LEGENDARY_PER_REGION_UNLOCK := 2
const LEGENDARY_RARITY := "legendary"
const KNOWLEDGE_TOOL_MAP := {
	"mangrove_toxins": "toxin_net",
	"shipwreck_drive": "propeller",
	"cold_current": "freeze_trap",
	"volcano_heat": "magma_bomb",
	"turtle_shell": "turtle_armor",
	"electric_eel": "electric_whip",
}
const TOOL_LABELS := {
	"toxin_net": "毒素网",
	"turtle_armor": "海龟盔甲",
	"propeller": "螺旋桨推进器",
	"freeze_trap": "急冻陷阱",
	"magma_bomb": "岩浆炸弹",
	"electric_whip": "电鞭",
}

var unlocked_region_count: int = INITIAL_UNLOCKED_REGION_COUNT
var uploaded_legendary_count: int = 0
var pending_knowledge_ids: Array[String] = []
var uploaded_knowledge_ids: Array[String] = []
var unlocked_tool_ids: Array[String] = []

var _save_path: String = DEFAULT_SAVE_PATH


func _ready() -> void:
	load_or_create()


func use_save_path(path: String) -> void:
	_save_path = path if path != "" else DEFAULT_SAVE_PATH
	load_or_create()


func load_or_create() -> void:
	var loaded := false
	if FileAccess.file_exists(_save_path):
		var file := FileAccess.open(_save_path, FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_apply_save_data(parsed)
				loaded = true

	if not loaded:
		_set_defaults()
		save()
	progress_changed.emit()


func save() -> void:
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(to_save_data(), "\t"))


func reset_save() -> void:
	_set_defaults()
	save()
	progress_changed.emit()


func record_uploaded_counts(counts: Dictionary) -> void:
	add_uploaded_legendary_progress(int(counts.get(LEGENDARY_RARITY, 0)))


func record_recovered_knowledge(knowledge_ids: Array) -> Array[String]:
	var added: Array[String] = []
	for id in knowledge_ids:
		var knowledge_id := String(id)
		if not KNOWLEDGE_TOOL_MAP.has(knowledge_id):
			continue
		if pending_knowledge_ids.has(knowledge_id) or uploaded_knowledge_ids.has(knowledge_id):
			continue
		pending_knowledge_ids.append(knowledge_id)
		added.append(knowledge_id)

	if not added.is_empty():
		save()
		progress_changed.emit()
	return added


func upload_pending_knowledge() -> Dictionary:
	var uploaded: Array[String] = pending_knowledge_ids.duplicate()
	var unlocked: Array[String] = []
	pending_knowledge_ids.clear()
	for knowledge_id in uploaded:
		if not uploaded_knowledge_ids.has(knowledge_id):
			uploaded_knowledge_ids.append(knowledge_id)
		var tool_id := String(KNOWLEDGE_TOOL_MAP[knowledge_id])
		if not unlocked_tool_ids.has(tool_id):
			unlocked_tool_ids.append(tool_id)
			unlocked.append(tool_id)

	if not uploaded.is_empty():
		save()
		progress_changed.emit()
	return {
		"knowledge_ids": uploaded,
		"tool_ids": unlocked,
	}


func has_pending_knowledge() -> bool:
	return not pending_knowledge_ids.is_empty()


func has_knowledge(knowledge_id: String) -> bool:
	return pending_knowledge_ids.has(knowledge_id) or uploaded_knowledge_ids.has(knowledge_id)


func get_pending_knowledge_ids() -> Array[String]:
	return pending_knowledge_ids.duplicate()


func get_uploaded_knowledge_ids() -> Array[String]:
	return uploaded_knowledge_ids.duplicate()


func get_unlocked_tool_ids() -> Array[String]:
	return unlocked_tool_ids.duplicate()


func is_tool_unlocked(tool_id: String) -> bool:
	return unlocked_tool_ids.has(tool_id)


func get_tool_label(tool_id: String) -> String:
	return String(TOOL_LABELS.get(tool_id, tool_id))


func format_tool_ids(tool_ids: Array) -> String:
	var labels: Array[String] = []
	for id in tool_ids:
		labels.append(get_tool_label(String(id)))
	return "无" if labels.is_empty() else "，".join(labels)


func add_uploaded_legendary_progress(amount: int = 1) -> void:
	if amount <= 0:
		return
	uploaded_legendary_count = maxi(0, uploaded_legendary_count + amount)
	_apply_unlock_rules()
	save()
	progress_changed.emit()


func set_unlocked_region_count(count: int) -> void:
	unlocked_region_count = clampi(count, INITIAL_UNLOCKED_REGION_COUNT, MAX_REGION_COUNT)
	save()
	progress_changed.emit()


func unlock_next_region() -> void:
	set_unlocked_region_count(unlocked_region_count + 1)


func lock_to_start_region() -> void:
	unlocked_region_count = INITIAL_UNLOCKED_REGION_COUNT
	uploaded_legendary_count = mini(uploaded_legendary_count, LEGENDARY_PER_REGION_UNLOCK - 1)
	save()
	progress_changed.emit()


func get_unlocked_region_count() -> int:
	return unlocked_region_count


func get_uploaded_legendary_count() -> int:
	return uploaded_legendary_count


func get_summary_text() -> String:
	return "已解锁区域：%d/%d\n已上传紫色：%d/%d\n待上传知识：%d\n已解锁道具：%s" % [
		unlocked_region_count,
		MAX_REGION_COUNT,
		uploaded_legendary_count,
		LEGENDARY_PER_REGION_UNLOCK * (MAX_REGION_COUNT - 1),
		pending_knowledge_ids.size(),
		format_tool_ids(unlocked_tool_ids),
	]


func to_save_data() -> Dictionary:
	return {
		"unlocked_region_count": unlocked_region_count,
		"uploaded_legendary_count": uploaded_legendary_count,
		"pending_knowledge_ids": pending_knowledge_ids,
		"uploaded_knowledge_ids": uploaded_knowledge_ids,
		"unlocked_tool_ids": unlocked_tool_ids,
	}


func _set_defaults() -> void:
	unlocked_region_count = INITIAL_UNLOCKED_REGION_COUNT
	uploaded_legendary_count = 0
	pending_knowledge_ids.clear()
	uploaded_knowledge_ids.clear()
	unlocked_tool_ids.clear()


func _apply_save_data(data: Dictionary) -> void:
	unlocked_region_count = clampi(
		int(data.get("unlocked_region_count", INITIAL_UNLOCKED_REGION_COUNT)),
		INITIAL_UNLOCKED_REGION_COUNT,
		MAX_REGION_COUNT
	)
	uploaded_legendary_count = maxi(0, int(data.get(
		"uploaded_legendary_count",
		data.get("lifetime_legendary_collected", 0)
	)))
	pending_knowledge_ids = _sanitize_knowledge_ids(data.get("pending_knowledge_ids", []))
	uploaded_knowledge_ids = _sanitize_knowledge_ids(data.get("uploaded_knowledge_ids", []))
	unlocked_tool_ids = _sanitize_tool_ids(data.get("unlocked_tool_ids", []))
	for knowledge_id in uploaded_knowledge_ids:
		var tool_id := String(KNOWLEDGE_TOOL_MAP.get(knowledge_id, ""))
		if tool_id != "" and not unlocked_tool_ids.has(tool_id):
			unlocked_tool_ids.append(tool_id)
	_apply_unlock_rules()


func _apply_unlock_rules() -> void:
	var unlocks_from_upload := 1 + int(uploaded_legendary_count / LEGENDARY_PER_REGION_UNLOCK)
	unlocked_region_count = maxi(unlocked_region_count, unlocks_from_upload)
	unlocked_region_count = clampi(unlocked_region_count, INITIAL_UNLOCKED_REGION_COUNT, MAX_REGION_COUNT)


func _sanitize_knowledge_ids(value) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array):
		return result
	for id in value:
		var knowledge_id := String(id)
		if KNOWLEDGE_TOOL_MAP.has(knowledge_id) and not result.has(knowledge_id):
			result.append(knowledge_id)
	return result


func _sanitize_tool_ids(value) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array):
		return result
	for id in value:
		var tool_id := String(id)
		if TOOL_LABELS.has(tool_id) and not result.has(tool_id):
			result.append(tool_id)
	return result
