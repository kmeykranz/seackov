extends Node

signal progress_changed

const DEFAULT_SAVE_PATH := "user://seackov_progress.json"
const INITIAL_UNLOCKED_REGION_COUNT := 1
const MAX_REGION_COUNT := 4
const LEGENDARY_PER_REGION_UNLOCK := 2
const LEGENDARY_RARITY := "legendary"

var unlocked_region_count: int = INITIAL_UNLOCKED_REGION_COUNT
var uploaded_legendary_count: int = 0

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
	return "Unlocked regions: %d/%d\nUploaded purple: %d/%d" % [
		unlocked_region_count,
		MAX_REGION_COUNT,
		uploaded_legendary_count,
		LEGENDARY_PER_REGION_UNLOCK * (MAX_REGION_COUNT - 1),
	]


func to_save_data() -> Dictionary:
	return {
		"unlocked_region_count": unlocked_region_count,
		"uploaded_legendary_count": uploaded_legendary_count,
	}


func _set_defaults() -> void:
	unlocked_region_count = INITIAL_UNLOCKED_REGION_COUNT
	uploaded_legendary_count = 0


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
	_apply_unlock_rules()


func _apply_unlock_rules() -> void:
	var unlocks_from_upload := 1 + int(uploaded_legendary_count / LEGENDARY_PER_REGION_UNLOCK)
	unlocked_region_count = maxi(unlocked_region_count, unlocks_from_upload)
	unlocked_region_count = clampi(unlocked_region_count, INITIAL_UNLOCKED_REGION_COUNT, MAX_REGION_COUNT)
