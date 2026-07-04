extends Node2D

const RunScenePath := "res://scenes/run_scene.tscn"
const LobbyScenePath := "res://scenes/ui/lobby.tscn"

const ACTION_DIVE := "dive"
const ACTION_UPLOAD := "upload"
const ACTION_WAREHOUSE := "warehouse"
const ACTION_PURIFIER := "purifier"
const ACTION_MISSION := "mission"

var _transitioning: bool = false
var _available_actions: Array[String] = []

@onready var _interaction_areas := {
	ACTION_DIVE: $World/Manhole,
	ACTION_UPLOAD: $World/UploadDevice,
	ACTION_WAREHOUSE: $World/Warehouse,
	ACTION_PURIFIER: $World/PurifierDevice,
	ACTION_MISSION: $World/MissionConsole,
}
@onready var _prompt_labels := {
	ACTION_DIVE: $World/Manhole/PromptLabel,
	ACTION_UPLOAD: $World/UploadDevice/PromptLabel,
	ACTION_WAREHOUSE: $World/Warehouse/PromptLabel,
	ACTION_PURIFIER: $World/PurifierDevice/PromptLabel,
	ACTION_MISSION: $World/MissionConsole/PromptLabel,
}
@onready var _message_label: Label = $BoatHud/Panel/MessageLabel
@onready var _inventory_label: Label = $BoatHud/Panel/InventoryLabel
@onready var _back_button: Button = $BoatHud/BackToMenuButton
@onready var _storage_ui: CanvasLayer = $StorageTransferUi


func _ready() -> void:
	set_process_unhandled_input(true)
	MusicManager.play_lobby_music()
	for action in _interaction_areas.keys():
		var area: Area2D = _interaction_areas[action]
		area.body_entered.connect(_on_interaction_body_entered.bind(action))
		area.body_exited.connect(_on_interaction_body_exited.bind(action))

	_back_button.pressed.connect(_on_back_to_menu_pressed)
	_storage_ui.storage_changed.connect(_on_storage_changed)
	_refresh_prompts()
	_update_inventory_status()
	_show_message("船舱待命：查看任务，处理背包物品，或从下潜口进入海底。")


func _unhandled_input(event: InputEvent) -> void:
	if _transitioning:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	if event.keycode == KEY_B:
		_handle_key_input()
		toggle_storage_ui()
		return

	if event.keycode == KEY_F and not _available_actions.is_empty():
		_handle_key_input()
		perform_interaction(_available_actions.back())


func perform_interaction(action: String) -> bool:
	match action:
		ACTION_DIVE:
			_transitioning = true
			get_tree().change_scene_to_file(RunScenePath)
			return true
		ACTION_UPLOAD:
			_upload_backpack()
			return true
		ACTION_WAREHOUSE:
			open_storage_ui("仓库已打开：左键整组，右键半组/单个，Shift+点击快速转移。")
			return true
		ACTION_PURIFIER:
			_show_message("净化装置：降落冲击导致核心散成碎片。先把海底回收物带回船上，再决定存放或上传分析。")
			return true
		ACTION_MISSION:
			_show_message("总部任务：修复净化装置，寻找信号塔部署点，继续探索更深区域并调查被摧毁的海洋隧道。")
			return true

	return false


func _on_interaction_body_entered(body: Node, action: String) -> void:
	if body.is_in_group("player"):
		if not _available_actions.has(action):
			_available_actions.append(action)
		_refresh_prompts()


func _on_interaction_body_exited(body: Node, action: String) -> void:
	if body.is_in_group("player"):
		_available_actions.erase(action)
		_refresh_prompts()


func _upload_backpack() -> void:
	var inventory = _inventory()
	var result: Dictionary = inventory.upload_all_from_backpack()
	if result["total_count"] <= 0:
		_show_message("上传装置：背包为空，没有可传输的样本或碎片。")
	else:
		_show_message("上传完成：%s，获得 %d 研究点。" % [
			inventory.format_counts(result["counts"]),
			result["value"],
		])
	_update_inventory_status()


func _on_back_to_menu_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	get_tree().change_scene_to_file(LobbyScenePath)


func _refresh_prompts() -> void:
	for action in _prompt_labels.keys():
		var label: Label = _prompt_labels[action]
		label.visible = _available_actions.has(action) and not _transitioning


func _update_inventory_status(refresh_storage_ui: bool = true) -> void:
	_inventory_label.text = _inventory().get_summary_text()
	if refresh_storage_ui and _storage_ui != null and _storage_ui.has_method("refresh"):
		_storage_ui.refresh()


func _show_message(message: String) -> void:
	_message_label.text = message


func open_storage_ui(message: String = "") -> void:
	_update_inventory_status(false)
	_storage_ui.open_panel(message)


func toggle_storage_ui() -> void:
	_update_inventory_status(false)
	_storage_ui.toggle_panel()


func is_storage_ui_open() -> bool:
	return _storage_ui.is_open()


func _on_storage_changed(message: String) -> void:
	_update_inventory_status(false)
	_show_message(message)


func _handle_key_input() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _inventory():
	return get_node("/root/PlayerInventory")
