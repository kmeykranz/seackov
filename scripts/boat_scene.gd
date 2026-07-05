extends Node2D

const RunLayout := preload("res://scripts/level/run_layout.gd")
const RunStorySystemScript := preload("res://scripts/story/run_story_system.gd")

const RunScenePath := "res://scenes/run_scene.tscn"
const LobbyScenePath := "res://scenes/ui/lobby.tscn"
const OPENING_TEXT := "\
欢迎回来，希望你没有被撞失忆。几百年前，我们的母星因资源滥用和环境崩溃，所有陆地沉入海底，人类被迫移居太空。如今我们回来了，但地球已被一种名为“黑雾”的未知物质笼罩——海洋表面和海底都受其侵蚀。降落冲击导致净化器装置受损，两块棱晶零件散落在附近海底。
你的首要任务：回收棱晶，修复装置。附近浅海已部分净化，搜索范围已标记。立即出发。
哦对了，进入新的区域或者遇到奇怪的生物会自动扫描并获取知识，上传可进行研究。"
const SUCCESS_TEXT := "\
数据已收到。“茧”并非地球产物，而是宇宙级侵蚀者，且可能存在于其他星球。人类必须寻找新的家园。感谢你的付出。

你的衣服上，一颗黑色结晶悄然生长。耳麦里传来极低的嗡鸣，随即中断。

欢迎回家，好好休息。我们很快会再见的。"

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
var _terminal_marks_intro: bool = false

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
@onready var _mission_ui: CanvasLayer = $MissionConsoleUi


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
	_mission_ui.spawn_anchor_selected.connect(_on_mission_spawn_anchor_selected)

	var progress = _progress()
	if progress != null and not progress.has_seen_intro:
		_start_intro_sequence()
		return
	if progress != null and progress.has_method("get_story_ending") and String(progress.get_story_ending()) == "success":
		_show_success_crystal()

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
			_show_purifier_status()
			return true
		ACTION_MISSION:
			_handle_mission_console()
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
	var story_result := {"stage_changed": false, "story_stage": ""}
	var knowledge_result := {"knowledge_ids": [], "tool_ids": []}
	if progress != null and progress.has_method("upload_pending_knowledge"):
		knowledge_result = progress.upload_pending_knowledge()

	if result["total_count"] > 0:
		if progress != null:
			story_result = progress.record_uploaded_counts(result["counts"])
	var final_result := {"completed_stage": false}
	if progress != null and progress.has_method("upload_final_data"):
		final_result = progress.upload_final_data()
	var unlocked_tools: Array = knowledge_result["tool_ids"]
	var final_uploaded := bool(final_result.get("completed_stage", false))
	if result["total_count"] <= 0 and unlocked_tools.is_empty() and not final_uploaded:
		_show_message("上传装置：背包为空，也没有待解析知识。")
	elif unlocked_tools.is_empty() and not final_uploaded:
		_show_message("上传完成：%s，获得 %d 研究点。" % [
			inventory.format_counts(result["counts"]),
			result["value"],
		])
	elif result["total_count"] <= 0 and not final_uploaded:
		_show_message("知识解析完成，解锁道具：%s。" % progress.format_tool_ids(unlocked_tools))
	else:
		var parts: Array[String] = []
		if result["total_count"] > 0:
			parts.append("上传完成：%s，获得 %d 研究点" % [inventory.format_counts(result["counts"]), result["value"]])
		if not unlocked_tools.is_empty():
			parts.append("知识解析解锁：%s" % progress.format_tool_ids(unlocked_tools))
		if final_uploaded:
			parts.append("最终真相数据上传完成")
		_show_message("。".join(parts) + "。")
	_update_inventory_status()
	if final_uploaded:
		_show_success_crystal()
		_open_terminal_dialogue(SUCCESS_TEXT, "终端（总部）", false)
	elif bool(story_result.get("stage_changed", false)) and String(story_result.get("story_stage", "")) == "signal_tower":
		_open_terminal_dialogue(RunStorySystemScript.PRISM_DONE_TEXT, "终端（总部）", false)


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
	if _mission_ui != null and _mission_ui.has_method("close_panel"):
		_mission_ui.close_panel()
	_update_inventory_status(false)
	_storage_ui.open_panel(message)


func toggle_storage_ui() -> void:
	if not _storage_ui.is_open() and _mission_ui != null and _mission_ui.has_method("close_panel"):
		_mission_ui.close_panel()
	_update_inventory_status(false)
	_storage_ui.toggle_panel()


func is_storage_ui_open() -> bool:
	return _storage_ui.is_open()


func is_mission_ui_open() -> bool:
	return _mission_ui.is_open()


func select_mission_spawn_anchor(anchor_id: String) -> bool:
	return _mission_ui.choose_spawn_anchor(anchor_id)


func is_terminal_active() -> bool:
	return _intro_active


func _on_storage_changed(message: String) -> void:
	_update_inventory_status(false)
	_show_message(message)


func _show_purifier_status() -> void:
	var progress = _progress()
	if progress == null:
		_show_message("净化装置：存档不可用，无法读取装置状态。")
		return
	var stage := String(progress.get_story_stage())
	if stage == "prism_recovery":
		var remaining := maxi(0, 2 - progress.get_uploaded_legendary_count())
		_show_message("净化装置：核心缺少棱晶零件。还需要上传 %d 个紫色历史遗物。" % remaining)
	elif stage == "signal_tower":
		_show_message("净化装置：近海净化率97%。中部海域已开放，信号塔任务物品已装载。")
	elif stage == "tunnel_repair":
		_show_message("净化装置：信号塔网络在线。深部海域已开放，可从总部任务面板选择下潜点。")
	elif stage == "ruins_investigation":
		_show_message("净化装置：探索船正在临时压制断崖黑雾。遗迹入口已标记。")
	elif stage == "final_escape":
		_show_message("净化装置：无法净化“茧”。真相数据必须撤离后上传。")
	elif stage == "ending_success":
		_show_message("净化装置：最终数据已归档。黑色结晶样本状态异常。")
	elif stage == "ending_failure":
		_show_message("净化装置：最终通讯中断。总部准备继续派遣探索队。")


func _handle_mission_console() -> void:
	var progress = _progress()
	if progress == null:
		_show_message("总部任务：存档不可用。")
		return
	if _storage_ui != null and _storage_ui.has_method("close_panel"):
		_storage_ui.close_panel()
	_open_mission_panel(progress)
	_show_message("总部任务：任务面板已打开。")


func _open_mission_panel(progress: Node) -> void:
	var specs := RunLayout.get_anchor_specs_for_unlocked_count(progress.get_unlocked_region_count())
	_mission_ui.open_panel(
		_mission_task_items(progress),
		specs,
		String(progress.get_selected_spawn_anchor_id()),
		progress.can_choose_spawn_anchor()
	)


func _on_mission_spawn_anchor_selected(anchor_id: String) -> void:
	var progress = _progress()
	if progress == null or not progress.can_choose_spawn_anchor():
		return
	progress.set_selected_spawn_anchor_id(anchor_id)
	call_deferred("_refresh_mission_panel")
	if anchor_id == "":
		_show_message("总部任务：下潜点已恢复为当前最深区域随机。")
	else:
		_show_message("总部任务：下潜点已选择为「%s」。" % RunLayout.get_anchor_label(anchor_id))
	_update_inventory_status()


func _refresh_mission_panel() -> void:
	var progress = _progress()
	if progress == null or _mission_ui == null or not _mission_ui.is_open():
		return
	_open_mission_panel(progress)


func _mission_task_items(progress: Node) -> Array:
	var stage := String(progress.get_story_stage())
	var signal_count := _completed_count([
		progress.is_signal_site_deployed("signal_bridge"),
		progress.is_signal_site_deployed("signal_volcano"),
	])
	var tunnel_count := _completed_count([
		progress.is_tunnel_site_repaired("tunnel_west"),
		progress.is_tunnel_site_repaired("tunnel_core"),
		progress.is_tunnel_site_repaired("tunnel_east"),
	])
	return [
		{
			"title": "修复净化装置",
			"detail": "上传紫色历史遗物：%d/2" % mini(2, progress.get_uploaded_legendary_count()),
			"completed": _story_stage_rank(stage) >= 1,
			"active": stage == "prism_recovery",
		},
		{
			"title": "部署信号塔",
			"detail": "沉没大桥和火山口：%d/2" % signal_count,
			"completed": _story_stage_rank(stage) >= 2,
			"active": stage == "signal_tower",
		},
		{
			"title": "修复海洋隧道",
			"detail": "前往异常隧道并修复断裂点：%d/3" % tunnel_count,
			"completed": _story_stage_rank(stage) >= 3,
			"active": stage == "tunnel_repair",
		},
		{
			"title": "调查遗迹源头",
			"detail": "读取遗迹电脑，查明黑雾来源。",
			"completed": _story_stage_rank(stage) >= 4,
			"active": stage == "ruins_investigation",
		},
		{
			"title": "撤离并上传真相",
			"detail": _final_task_detail(progress),
			"completed": String(progress.get_story_ending()) == "success",
			"active": stage == "final_escape",
		},
	]


func _completed_count(values: Array) -> int:
	var count := 0
	for value in values:
		if bool(value):
			count += 1
	return count


func _story_stage_rank(stage: String) -> int:
	match stage:
		"signal_tower":
			return 1
		"tunnel_repair":
			return 2
		"ruins_investigation":
			return 3
		"final_escape":
			return 4
		"ending_success", "ending_failure":
			return 5
	return 0


func _final_task_detail(progress: Node) -> String:
	if String(progress.get_story_ending()) == "success":
		return "最终数据已上传。"
	if String(progress.get_story_ending()) == "failure":
		return "通讯中断，任务失败。"
	if progress.has_final_data_pending():
		return "真相数据待上传。"
	return "取得真相数据后从锚点撤离。"


func _show_success_crystal() -> void:
	var player := $World/PlayerDiver
	if player.has_node("StoryCrystal"):
		return
	var crystal := Polygon2D.new()
	crystal.name = "StoryCrystal"
	crystal.position = Vector2(28.0, -30.0)
	crystal.color = Color(0.02, 0.0, 0.035, 1.0)
	crystal.polygon = PackedVector2Array([
		Vector2(0, -24),
		Vector2(16, 0),
		Vector2(0, 28),
		Vector2(-16, 0),
	])
	player.add_child(crystal)


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
	_begin_terminal_lock(true)

	# 先震屏 2.5 秒
	await _shake_camera(2.5, 28.0)
	await get_tree().create_timer(0.4).timeout

	# 弹出终端独白
	_open_terminal_dialogue(OPENING_TEXT, "终端（总部）", true)


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


func _open_terminal_dialogue(text: String, speaker: String = "终端（总部）", marks_intro: bool = false) -> void:
	if _intro_active and not marks_intro:
		return
	_begin_terminal_lock(marks_intro)
	var terminal := TerminalIntro.new()
	terminal.name = "TerminalDialogue"
	terminal.configure(text, speaker)
	add_child(terminal)
	terminal.intro_finished.connect(_on_terminal_finished)


func _begin_terminal_lock(marks_intro: bool) -> void:
	_intro_active = true
	_terminal_marks_intro = marks_intro
	var player := $World/PlayerDiver
	if player.has_method("set_control_enabled") or "control_enabled" in player:
		player.set("control_enabled", false)
	_back_button.visible = false
	if _mission_ui != null and _mission_ui.has_method("close_panel"):
		_mission_ui.close_panel()
	for label in _prompt_labels.values():
		label.visible = false
	_show_message("")


func _on_terminal_finished() -> void:
	var progress = _progress()
	if progress != null and _terminal_marks_intro:
		progress.mark_intro_seen()

	# 恢复玩家控制
	var player := $World/PlayerDiver
	if player.has_method("set_control_enabled") or "control_enabled" in player:
		player.set("control_enabled", true)
	_back_button.visible = true

	_intro_active = false
	_terminal_marks_intro = false
	_refresh_prompts()
	_update_inventory_status()
	_show_message("船舱待命：查看任务，处理背包物品，或从下潜口进入海底。")
