extends Node2D

const RunScenePath := "res://scenes/run_scene.tscn"
const LobbyScenePath := "res://scenes/ui/lobby.tscn"

const ACTION_DIVE := "dive"
const ACTION_UPLOAD := "upload"
const ACTION_WAREHOUSE := "warehouse"
const ACTION_PURIFIER := "purifier"
const ACTION_MISSION := "mission"

var _transitioning: bool = false
var _intro_active: bool = false
var _available_actions: Array[String] = []
var _hull_world_polygon: PackedVector2Array
var _player_last_safe_pos: Vector2

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
	MusicManager.play_boat_music()
	_configure_player_collision()

	# Hull 多边形边界 —— 计算世界坐标多边形
	var hull_area: Area2D = $World/Hull
	var hull_collision: CollisionPolygon2D = $World/Hull/HullCollision
	_hull_world_polygon = _to_world_polygon(hull_area, hull_collision, hull_collision.polygon)
	_player_last_safe_pos = $World/PlayerDiver.global_position

	# 确保 Hull 的 collision_mask 能检测到玩家
	hull_area.collision_mask = 1 << 0  # PLAYER

	for action in _interaction_areas.keys():
		var area: Area2D = _interaction_areas[action]
		area.body_entered.connect(_on_interaction_body_entered.bind(action))
		area.body_exited.connect(_on_interaction_body_exited.bind(action))

	_back_button.pressed.connect(_on_back_to_menu_pressed)
	_storage_ui.storage_changed.connect(_on_storage_changed)

	var progress = _progress()
	if progress != null and not progress.has_seen_intro:
		_start_intro_sequence()
		return

	_refresh_prompts()
	_update_inventory_status()
	_show_message("船舱待命：查看任务，处理背包物品，或从下潜口进入海底。")


func _unhandled_input(event: InputEvent) -> void:
	if _transitioning or _intro_active:
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
			MusicManager.diving_from_boat = true
			MusicManager.play_dive_alarm()
			await get_tree().create_timer(0.3).timeout
			get_tree().change_scene_to_file(RunScenePath)
			return true
		ACTION_UPLOAD:
			_upload_backpack()
			return true
		ACTION_WAREHOUSE:
			open_storage_ui("仓库已打开：左键整组，右键半组/单个，按住换挡键点击快速转移。")
			return true
		ACTION_PURIFIER:
			_show_message("净化装置：降落冲击导致核心散成碎片。先把海底回收物带回船上，再决定存放或上传分析。")
			return true
		ACTION_MISSION:
			_show_message("总部任务：修复净化装置，寻找信号塔部署点，继续探索更深区域并调查被摧毁的海洋隧道。")
			return true

	return false


func _configure_player_collision() -> void:
	var player := $World/PlayerDiver as CharacterBody2D
	player.collision_layer = 1 << 0   # PLAYER
	player.collision_mask = 1 << 1    # WALL
	var cam := player.get_node("Camera2D") as Camera2D
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = 1920
	cam.limit_bottom = 1080
	cam.make_current()


func _process(_delta: float) -> void:
	if _intro_active:
		return
	# _process 在 _physics_process 之后运行，确保 move_and_slide 已执行完毕
	var player := $World/PlayerDiver
	if Geometry2D.is_point_in_polygon(player.global_position, _hull_world_polygon):
		_player_last_safe_pos = player.global_position
	else:
		player.global_position = _player_last_safe_pos


func _to_world_polygon(area: Area2D, collision_node: CollisionPolygon2D, local_poly: PackedVector2Array) -> PackedVector2Array:
	var world := PackedVector2Array()
	var offset: Vector2 = area.global_position + collision_node.position
	for pt in local_poly:
		world.append(offset + pt)
	return world


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
	MusicManager.play_upload()

	var inventory = _inventory()
	var result: Dictionary = inventory.upload_all_from_backpack()
	var progress = _progress()
	var knowledge_result := {"knowledge_ids": [], "tool_ids": []}
	if progress != null and progress.has_method("upload_pending_knowledge"):
		knowledge_result = progress.upload_pending_knowledge()

	if result["total_count"] > 0:
		if progress != null:
			progress.record_uploaded_counts(result["counts"])
	var unlocked_tools: Array = knowledge_result["tool_ids"]
	if result["total_count"] <= 0 and unlocked_tools.is_empty():
		_show_message("上传装置：背包为空，也没有待解析知识。")
	elif unlocked_tools.is_empty():
		_show_message("上传完成：%s，获得 %d 研究点。" % [
			inventory.format_counts(result["counts"]),
			result["value"],
		])
	elif result["total_count"] <= 0:
		_show_message("知识解析完成，解锁道具：%s。" % progress.format_tool_ids(unlocked_tools))
	else:
		_show_message("上传完成：%s，获得 %d 研究点。知识解析解锁：%s。" % [
			inventory.format_counts(result["counts"]),
			result["value"],
			progress.format_tool_ids(unlocked_tools),
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


func _progress():
	return get_node_or_null("/root/ProgressState")


# —— 开场序列：镜头剧烈晃动 → 终端独白 ——

func _start_intro_sequence() -> void:
	_intro_active = true
	# 禁用玩家控制
	var player := $World/PlayerDiver
	if player.has_method("set_control_enabled") or "control_enabled" in player:
		player.set("control_enabled", false)
	# 隐藏 HUD 按钮和提示
	_back_button.visible = false
	for label in _prompt_labels.values():
		label.visible = false
	_show_message("")

	# 先震屏 2.5 秒
	await _shake_camera(2.5, 28.0)
	await get_tree().create_timer(0.4).timeout

	# 弹出终端独白
	var terminal := TerminalIntro.new()
	add_child(terminal)
	terminal.intro_finished.connect(_on_intro_finished)


func _shake_camera(duration: float, intensity: float) -> void:
	var cam: Camera2D = $World/PlayerDiver/Camera2D
	var original_offset := cam.offset
	var elapsed := 0.0
	while elapsed < duration:
		elapsed += get_process_delta_time()
		var decay := 1.0 - elapsed / duration
		var amp := intensity * decay * decay
		cam.offset = original_offset + Vector2(
			randf_range(-amp, amp),
			randf_range(-amp, amp),
		)
		# 旋转也晃
		cam.rotation = randf_range(-0.04, 0.04) * decay
		await get_tree().process_frame
	cam.offset = original_offset
	cam.rotation = 0.0


func _on_intro_finished() -> void:
	var progress = _progress()
	if progress != null:
		progress.mark_intro_seen()

	# 恢复玩家控制
	var player := $World/PlayerDiver
	if player.has_method("set_control_enabled") or "control_enabled" in player:
		player.set("control_enabled", true)
	_back_button.visible = true

	_intro_active = false
	_refresh_prompts()
	_update_inventory_status()
	_show_message("船舱待命：查看任务，处理背包物品，或从下潜口进入海底。")
