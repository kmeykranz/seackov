extends Node

signal progress_changed

const DEFAULT_SAVE_PATH := "user://seackov_progress.json"
const INITIAL_UNLOCKED_REGION_COUNT := 1
const MAX_REGION_COUNT := 4
const LEGENDARY_PER_REGION_UNLOCK := 2
const LEGENDARY_RARITY := "legendary"
const STORY_STAGE_PRISM := "prism_recovery"
const STORY_STAGE_SIGNAL := "signal_tower"
const STORY_STAGE_TUNNEL := "tunnel_repair"
const STORY_STAGE_RUINS := "ruins_investigation"
const STORY_STAGE_ESCAPE := "final_escape"
const STORY_STAGE_SUCCESS := "ending_success"
const STORY_STAGE_FAILURE := "ending_failure"
const SIGNAL_SITE_IDS := ["signal_bridge", "signal_volcano"]
const TUNNEL_SITE_IDS := ["tunnel_west", "tunnel_core", "tunnel_east"]
const STORY_STAGE_LABELS := {
	STORY_STAGE_PRISM: "回收棱晶，修复净化装置",
	STORY_STAGE_SIGNAL: "部署信号塔",
	STORY_STAGE_TUNNEL: "调查并修复隧道",
	STORY_STAGE_RUINS: "进入遗迹调查",
	STORY_STAGE_ESCAPE: "带回真相并撤离",
	STORY_STAGE_SUCCESS: "成功结局",
	STORY_STAGE_FAILURE: "失败结局",
}
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
var has_seen_intro: bool = false
var story_stage: String = STORY_STAGE_PRISM
var story_events: Array[String] = []
var deployed_signal_site_ids: Array[String] = []
var repaired_tunnel_site_ids: Array[String] = []
var selected_spawn_anchor_id: String = ""
var final_data_pending_upload: bool = false
var story_ending: String = ""

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


func record_uploaded_counts(counts: Dictionary) -> Dictionary:
	var before_stage := story_stage
	var before_region := unlocked_region_count
	add_uploaded_legendary_progress(int(counts.get(LEGENDARY_RARITY, 0)))
	return {
		"stage_changed": before_stage != story_stage,
		"region_changed": before_region != unlocked_region_count,
		"story_stage": story_stage,
		"unlocked_region_count": unlocked_region_count,
	}


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
	_apply_story_unlock_rules()
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
	story_stage = STORY_STAGE_PRISM
	deployed_signal_site_ids.clear()
	repaired_tunnel_site_ids.clear()
	selected_spawn_anchor_id = ""
	final_data_pending_upload = false
	story_ending = ""
	save()
	progress_changed.emit()


func get_unlocked_region_count() -> int:
	return unlocked_region_count


func get_uploaded_legendary_count() -> int:
	return uploaded_legendary_count


func get_story_stage() -> String:
	return story_stage


func get_story_stage_label() -> String:
	return String(STORY_STAGE_LABELS.get(story_stage, story_stage))


func is_story_stage(stage_id: String) -> bool:
	return story_stage == stage_id


func has_story_event(event_id: String) -> bool:
	return story_events.has(event_id)


func mark_story_event(event_id: String) -> void:
	if event_id == "" or story_events.has(event_id):
		return
	story_events.append(event_id)
	save()
	progress_changed.emit()


func deploy_signal_site(site_id: String) -> Dictionary:
	if story_stage != STORY_STAGE_SIGNAL or not SIGNAL_SITE_IDS.has(site_id):
		return _story_result(false, false)
	var changed := _append_unique(deployed_signal_site_ids, site_id)
	var completed_stage := false
	if _has_all(deployed_signal_site_ids, SIGNAL_SITE_IDS):
		story_stage = STORY_STAGE_TUNNEL
		unlocked_region_count = maxi(unlocked_region_count, 3)
		completed_stage = true
	if changed or completed_stage:
		save()
		progress_changed.emit()
	return _story_result(changed, completed_stage)


func repair_tunnel_site(site_id: String) -> Dictionary:
	if story_stage != STORY_STAGE_TUNNEL or not TUNNEL_SITE_IDS.has(site_id):
		return _story_result(false, false)
	var changed := _append_unique(repaired_tunnel_site_ids, site_id)
	var completed_stage := false
	if _has_all(repaired_tunnel_site_ids, TUNNEL_SITE_IDS):
		story_stage = STORY_STAGE_RUINS
		unlocked_region_count = maxi(unlocked_region_count, 4)
		completed_stage = true
	if changed or completed_stage:
		save()
		progress_changed.emit()
	return _story_result(changed, completed_stage)


func start_final_escape() -> Dictionary:
	if story_stage != STORY_STAGE_RUINS:
		return _story_result(false, false)
	story_stage = STORY_STAGE_ESCAPE
	final_data_pending_upload = false
	story_ending = ""
	save()
	progress_changed.emit()
	return _story_result(true, true)


func mark_final_extraction() -> Dictionary:
	if story_stage != STORY_STAGE_ESCAPE:
		return _story_result(false, false)
	final_data_pending_upload = true
	save()
	progress_changed.emit()
	return _story_result(true, false)


func upload_final_data() -> Dictionary:
	if not final_data_pending_upload or story_stage != STORY_STAGE_ESCAPE:
		return _story_result(false, false)
	final_data_pending_upload = false
	story_stage = STORY_STAGE_SUCCESS
	story_ending = "success"
	save()
	progress_changed.emit()
	return _story_result(true, true)


func mark_final_failure() -> Dictionary:
	if story_stage != STORY_STAGE_ESCAPE:
		return _story_result(false, false)
	final_data_pending_upload = false
	story_stage = STORY_STAGE_FAILURE
	story_ending = "failure"
	save()
	progress_changed.emit()
	return _story_result(true, true)


func is_final_escape_active() -> bool:
	return story_stage == STORY_STAGE_ESCAPE


func has_final_data_pending() -> bool:
	return final_data_pending_upload


func get_story_ending() -> String:
	return story_ending


func can_choose_spawn_anchor() -> bool:
	return story_stage in [
		STORY_STAGE_TUNNEL,
		STORY_STAGE_RUINS,
		STORY_STAGE_ESCAPE,
		STORY_STAGE_SUCCESS,
		STORY_STAGE_FAILURE,
	]


func set_selected_spawn_anchor_id(anchor_id: String) -> void:
	selected_spawn_anchor_id = anchor_id
	save()
	progress_changed.emit()


func get_selected_spawn_anchor_id() -> String:
	return selected_spawn_anchor_id


func is_signal_site_deployed(site_id: String) -> bool:
	return deployed_signal_site_ids.has(site_id)


func is_tunnel_site_repaired(site_id: String) -> bool:
	return repaired_tunnel_site_ids.has(site_id)


func get_deployed_signal_site_ids() -> Array[String]:
	return deployed_signal_site_ids.duplicate()


func get_repaired_tunnel_site_ids() -> Array[String]:
	return repaired_tunnel_site_ids.duplicate()


func get_summary_text() -> String:
	return "剧情：%s\n已解锁区域：%d/%d\n已上传紫色：%d/2\n待上传知识：%d\n已解锁道具：%s\n下潜点：%s" % [
		get_story_stage_label(),
		unlocked_region_count,
		MAX_REGION_COUNT,
		uploaded_legendary_count,
		pending_knowledge_ids.size(),
		format_tool_ids(unlocked_tool_ids),
		"随机" if selected_spawn_anchor_id == "" else selected_spawn_anchor_id,
	]


func to_save_data() -> Dictionary:
	return {
		"unlocked_region_count": unlocked_region_count,
		"uploaded_legendary_count": uploaded_legendary_count,
		"pending_knowledge_ids": pending_knowledge_ids,
		"uploaded_knowledge_ids": uploaded_knowledge_ids,
		"unlocked_tool_ids": unlocked_tool_ids,
		"has_seen_intro": has_seen_intro,
		"story_stage": story_stage,
		"story_events": story_events,
		"deployed_signal_site_ids": deployed_signal_site_ids,
		"repaired_tunnel_site_ids": repaired_tunnel_site_ids,
		"selected_spawn_anchor_id": selected_spawn_anchor_id,
		"final_data_pending_upload": final_data_pending_upload,
		"story_ending": story_ending,
	}


func _set_defaults() -> void:
	unlocked_region_count = INITIAL_UNLOCKED_REGION_COUNT
	uploaded_legendary_count = 0
	pending_knowledge_ids.clear()
	uploaded_knowledge_ids.clear()
	unlocked_tool_ids.clear()
	has_seen_intro = false
	story_stage = STORY_STAGE_PRISM
	story_events.clear()
	deployed_signal_site_ids.clear()
	repaired_tunnel_site_ids.clear()
	selected_spawn_anchor_id = ""
	final_data_pending_upload = false
	story_ending = ""


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
	has_seen_intro = bool(data.get("has_seen_intro", false))
	story_stage = _sanitize_story_stage(String(data.get("story_stage", STORY_STAGE_PRISM)))
	story_events = _sanitize_string_ids(data.get("story_events", []))
	deployed_signal_site_ids = _sanitize_allowed_ids(data.get("deployed_signal_site_ids", []), SIGNAL_SITE_IDS)
	repaired_tunnel_site_ids = _sanitize_allowed_ids(data.get("repaired_tunnel_site_ids", []), TUNNEL_SITE_IDS)
	selected_spawn_anchor_id = String(data.get("selected_spawn_anchor_id", ""))
	final_data_pending_upload = bool(data.get("final_data_pending_upload", false))
	story_ending = _sanitize_ending(String(data.get("story_ending", "")))
	for knowledge_id in uploaded_knowledge_ids:
		var tool_id := String(KNOWLEDGE_TOOL_MAP.get(knowledge_id, ""))
		if tool_id != "" and not unlocked_tool_ids.has(tool_id):
			unlocked_tool_ids.append(tool_id)
	_apply_story_unlock_rules()


func _apply_story_unlock_rules() -> void:
	if story_stage == STORY_STAGE_PRISM and uploaded_legendary_count >= LEGENDARY_PER_REGION_UNLOCK:
		story_stage = STORY_STAGE_SIGNAL
		unlocked_region_count = maxi(unlocked_region_count, 2)
	if _story_stage_rank(story_stage) >= _story_stage_rank(STORY_STAGE_SIGNAL):
		unlocked_region_count = maxi(unlocked_region_count, 2)
	if _story_stage_rank(story_stage) >= _story_stage_rank(STORY_STAGE_TUNNEL):
		unlocked_region_count = maxi(unlocked_region_count, 3)
	if _story_stage_rank(story_stage) >= _story_stage_rank(STORY_STAGE_RUINS):
		unlocked_region_count = maxi(unlocked_region_count, 4)
	unlocked_region_count = clampi(unlocked_region_count, INITIAL_UNLOCKED_REGION_COUNT, MAX_REGION_COUNT)


func mark_intro_seen() -> void:
	has_seen_intro = true
	save()


func _story_result(changed: bool, completed_stage: bool) -> Dictionary:
	return {
		"changed": changed,
		"completed_stage": completed_stage,
		"story_stage": story_stage,
		"unlocked_region_count": unlocked_region_count,
	}


func _append_unique(target: Array[String], id: String) -> bool:
	if target.has(id):
		return false
	target.append(id)
	return true


func _has_all(current_ids: Array[String], required_ids: Array) -> bool:
	for id in required_ids:
		if not current_ids.has(String(id)):
			return false
	return true


func _story_stage_rank(stage_id: String) -> int:
	match stage_id:
		STORY_STAGE_PRISM:
			return 1
		STORY_STAGE_SIGNAL:
			return 2
		STORY_STAGE_TUNNEL:
			return 3
		STORY_STAGE_RUINS:
			return 4
		STORY_STAGE_ESCAPE:
			return 5
		STORY_STAGE_SUCCESS:
			return 6
		STORY_STAGE_FAILURE:
			return 6
	return 1


func _sanitize_story_stage(stage_id: String) -> String:
	if STORY_STAGE_LABELS.has(stage_id):
		return stage_id
	return STORY_STAGE_PRISM


func _sanitize_ending(ending_id: String) -> String:
	if ending_id == "success" or ending_id == "failure":
		return ending_id
	return ""


func _sanitize_string_ids(value) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array):
		return result
	for id in value:
		var text := String(id)
		if text != "" and not result.has(text):
			result.append(text)
	return result


func _sanitize_allowed_ids(value, allowed_ids: Array) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array):
		return result
	for id in value:
		var text := String(id)
		if allowed_ids.has(text) and not result.has(text):
			result.append(text)
	return result


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
