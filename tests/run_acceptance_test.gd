extends SceneTree

const RunSceneControllerScript := preload("res://scripts/game_controller.gd")
const MonsterPatrolScript := preload("res://scripts/monster_patrol.gd")
const RunLayout := preload("res://scripts/level/run_layout.gd")
const TerminalIntroScript := preload("res://scenes/ui/terminal_intro.gd")
const MAIN_MENU_FONT_PATH := "res://assets/ZaoZiGongFangYingLiHeiGuiTi-1.otf"

const ENTITY_SCENE_PATHS := [
	"res://scenes/actors/player_diver.tscn",
	"res://scenes/actors/monster_patrol.tscn",
	"res://scenes/actors/monster_shark.tscn",
	"res://scenes/actors/monster_fish.tscn",
	"res://scenes/pickups/treasure_pickup.tscn",
	"res://scenes/props/anchor_exit.tscn",
	"res://scenes/props/solid_cover.tscn",
	"res://scenes/props/seaweed_cover.tscn",
	"res://scenes/props/coral.tscn",
	"res://scenes/props/chest_box.tscn",
	"res://scenes/ui/run_hud.tscn",
	"res://scenes/ui/storage_transfer_ui.tscn",
	"res://scenes/ui/mission_console_ui.tscn",
	"res://scenes/ui/minimap_ui.tscn",
	"res://scenes/ui/pause_menu_ui.tscn",
	"res://scenes/boat_scene.tscn",
]

var failures: Array[String] = []
var game: Node
var inventory
var progress
var transitioned_boat: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	inventory = root.get_node("/root/PlayerInventory")
	progress = root.get_node("/root/ProgressState")
	progress.use_save_path("user://acceptance_progress.json")
	progress.reset_save()
	inventory.reset_runtime_state()
	await _test_upload_progression_unlocks()
	progress.reset_save()
	inventory.reset_runtime_state()
	await _test_story_campaign_system()
	progress.reset_save()
	inventory.reset_runtime_state()
	await _test_terminal_hold_dismissal()
	progress.reset_save()
	inventory.reset_runtime_state()
	await _test_run_tool_system()
	progress.reset_save()
	inventory.reset_runtime_state()
	_test_map_population_distribution()
	await _test_monster_collision_death_opens_failure_scene()
	progress.reset_save()
	inventory.reset_runtime_state()
	progress.mark_intro_seen()
	var scene := load("res://scenes/run_scene.tscn")
	_assert(scene != null, "run scene loads")
	if scene == null:
		_finish()
		return

	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame

	_test_initial_state()
	_test_scene_split_and_visibility()
	_test_depth_lighting_gradient()
	_test_pause_menu_controls()
	await _test_player_movement_and_perimeter()
	await _test_region_progression()
	await _test_collect_and_clear_penalty()
	await _test_monster_vision_guards()
	await _test_anchor_choices_and_extraction()
	await _test_inventory_and_boat_scene()
	await _test_lobby_debug_controls()

	_finish()


func _test_upload_progression_unlocks() -> void:
	var boat_scene := load("res://scenes/boat_scene.tscn")
	_assert(boat_scene != null, "boat scene loads for upload progression")
	if boat_scene == null:
		return

	var boat = boat_scene.instantiate()
	root.add_child(boat)
	await process_frame

	progress.reset_save()
	inventory.reset_runtime_state()
	inventory.add_to_storage("backpack", "legendary", 2)
	var upload_handled: bool = boat.perform_interaction("upload")
	_assert(upload_handled, "boat upload handles purifier repair batch")
	_assert(inventory.get_backpack_total_count() == 0, "upload progression batch clears backpack")
	_assert(progress.get_uploaded_legendary_count() == 2, "uploaded legendary progress records prism count")
	_assert(progress.get_unlocked_region_count() == 2, "two uploaded legendary items unlock the middle region")
	_assert(progress.get_story_stage() == "signal_tower", "two uploaded legendary items advance the story to signal towers")

	inventory.add_to_storage("backpack", "legendary", 4)
	boat.perform_interaction("upload")
	_assert(progress.get_uploaded_legendary_count() == 6, "additional uploaded legendary items remain recorded")
	_assert(progress.get_unlocked_region_count() == 2, "additional legendary uploads do not skip signal and tunnel story gates")

	boat.queue_free()
	await process_frame


func _test_story_campaign_system() -> void:
	progress.add_uploaded_legendary_progress(2)
	_assert(progress.get_story_stage() == "signal_tower", "purifier repair starts the signal tower stage")
	_assert(progress.get_unlocked_region_count() == 2, "purifier repair opens the middle region")

	var scene := load("res://scenes/run_scene.tscn")
	_assert(scene != null, "run scene loads for story campaign")
	if scene == null:
		return

	var story_run = scene.instantiate()
	root.add_child(story_run)
	current_scene = story_run
	await process_frame
	await physics_frame

	var story_system = story_run.get_story_system()
	_assert(story_system != null, "run story system is available")
	_assert(story_system.has_target("signal_bridge"), "signal bridge deployment marker is visible")
	_assert(story_system.has_target("signal_volcano"), "signal volcano deployment marker is visible")
	_assert(story_run.get_node("RunHud/ObjectivePanel/MarginContainer/VBoxContainer/ObjectiveLabel").text.contains("目标"), "run HUD displays story objective status")
	_assert(story_run.get_node("MiniMapUi").get_story_target_count() >= 2, "minimap shows active story target markers")

	story_run.player.global_position = story_system.get_target_position("signal_bridge")
	await process_frame
	var e_press := InputEventKey.new()
	e_press.keycode = KEY_E
	e_press.pressed = true
	var e_release := InputEventKey.new()
	e_release.keycode = KEY_E
	e_release.pressed = false
	story_run._unhandled_input(e_press)
	for _index in range(20):
		await process_frame
	story_run._unhandled_input(e_release)
	_assert(not progress.is_signal_site_deployed("signal_bridge"), "releasing E early resets signal tower deployment")

	story_run._unhandled_input(e_press)
	for _index in range(520):
		if progress.is_signal_site_deployed("signal_bridge"):
			break
		await process_frame
	_assert(progress.is_signal_site_deployed("signal_bridge"), "holding E completes signal tower deployment")
	story_system.complete_target("signal_volcano")
	_assert(progress.get_story_stage() == "tunnel_repair", "both signal towers advance the story to tunnel repair")
	_assert(progress.get_unlocked_region_count() == 3, "signal tower network opens the deep region")
	await _assert_default_spawn_uses_deepest_unlocked_region(3)
	await _assert_selected_spawn_anchor_override("coral_mid")

	story_run.player.global_position = story_system.get_target_position("tunnel_arrival")
	await process_frame
	await process_frame
	_assert(progress.has_story_event("tunnel_arrived"), "approaching the tunnel triggers hidden story dialogue")
	_assert(story_system.has_target("tunnel_west"), "tunnel repair markers appear after the hidden dialogue trigger")
	story_system.complete_target("tunnel_west")
	story_system.complete_target("tunnel_core")
	story_system.complete_target("tunnel_east")
	_assert(progress.get_story_stage() == "ruins_investigation", "repairing all tunnel sites opens the ruins objective")
	_assert(progress.get_unlocked_region_count() == 4, "tunnel repair opens the ruins region")
	_assert(story_system.has_target("ruins_terminal"), "ruins terminal marker is visible")

	story_system.complete_target("ruins_terminal")
	_assert(progress.is_final_escape_active(), "reading the ruins terminal starts final escape")
	story_run.run_state = RunSceneControllerScript.RunState.ANCHOR_PROMPT
	story_run.player_on_anchor = true
	story_run.choose_extract()
	for _index in range(5):
		await process_frame
	_assert(progress.has_final_data_pending(), "extracting during final escape carries truth data to the boat")

	var boat = current_scene
	_assert(boat != null and boat.name == "BoatScene", "final extraction returns to the boat")
	if boat != null:
		boat.perform_interaction("upload")
		_assert(progress.get_story_ending() == "success", "uploading final data records the success ending")
		_assert(boat.has_node("World/PlayerDiver/StoryCrystal"), "success ending shows the black crystal placeholder on the player")
		boat.queue_free()
		if current_scene == boat:
			current_scene = null
	await process_frame

	progress.reset_save()
	progress.add_uploaded_legendary_progress(2)
	progress.deploy_signal_site("signal_bridge")
	progress.deploy_signal_site("signal_volcano")
	progress.mark_story_event("tunnel_arrived")
	progress.repair_tunnel_site("tunnel_west")
	progress.repair_tunnel_site("tunnel_core")
	progress.repair_tunnel_site("tunnel_east")
	progress.start_final_escape()
	progress.mark_final_failure()
	var fail_scene = load("res://scenes/ui/fail.tscn").instantiate()
	root.add_child(fail_scene)
	await process_frame
	_assert(fail_scene.get_node("title").text == "通讯中断", "final escape death uses the story failure title")
	_assert(fail_scene.get_node("reason").text.contains("信号丢失"), "final escape death uses the story failure terminal copy")
	fail_scene.queue_free()
	await process_frame


func _test_terminal_hold_dismissal() -> void:
	var terminal: TerminalIntro = TerminalIntroScript.new()
	terminal.configure("测试剧情文字", "终端")
	root.add_child(terminal)
	await process_frame

	terminal._input(_key_event(KEY_SPACE, true))
	await process_frame
	_assert(terminal.is_dismiss_progress_visible(), "terminal dismissal progress bar is visible after full text")
	var dismiss_bar: ProgressBar = terminal.get_node("DismissProgress")
	_assert(dismiss_bar.size.y <= 16.0 and dismiss_bar.size.x >= 240.0, "terminal dismissal progress bar stays as a compact horizontal bar")
	terminal._input(_key_event(KEY_E, true))
	terminal._input(_key_event(KEY_E, false))
	await process_frame
	_assert(is_instance_valid(terminal) and not terminal.is_queued_for_deletion(), "short E press does not dismiss terminal text")
	_assert(is_zero_approx(terminal.get_dismiss_hold_progress()), "short E press leaves terminal dismissal progress empty")

	terminal._input(_key_event(KEY_E, true))
	await create_timer(0.35).timeout
	_assert(is_instance_valid(terminal) and terminal.get_dismiss_hold_progress() > 0.1, "holding E fills terminal dismissal progress")
	await create_timer(1.4).timeout
	await process_frame
	_assert(not is_instance_valid(terminal) or terminal.is_queued_for_deletion(), "holding E dismisses terminal text")
	if is_instance_valid(terminal):
		terminal.queue_free()
	await process_frame


func _test_run_tool_system() -> void:
	var all_knowledge := [
		"mangrove_toxins",
		"shipwreck_drive",
		"cold_current",
		"volcano_heat",
		"turtle_shell",
		"electric_eel",
	]
	progress.record_recovered_knowledge(all_knowledge)
	var upload_result: Dictionary = progress.upload_pending_knowledge()
	_assert(upload_result["tool_ids"].size() == 6, "uploading story knowledge unlocks all placeholder tools")

	var scene := load("res://scenes/run_scene.tscn")
	_assert(scene != null, "run scene loads for tool system")
	if scene == null:
		return

	var tool_run = scene.instantiate()
	root.add_child(tool_run)
	await process_frame
	await physics_frame

	var tool_system = tool_run.get_tool_system()
	_assert(tool_system != null, "run tool system is available")
	_assert(tool_system.get_unlocked_tool_ids().size() == 6, "run tool system exposes unlocked tools")
	_assert(tool_run.get_node("RunHud/ToolPanel/MarginContainer/VBoxContainer/ToolLabel").text.contains("道具"), "run HUD displays tool status")

	for monster in tool_run.monsters:
		monster.set_active(false)

	tool_run.player.global_position = Vector2(9000.0, 3000.0)
	tool_run.player.facing = Vector2.RIGHT
	var first_monster = tool_run.monsters[0]
	first_monster.global_position = tool_run.player.global_position + Vector2(220.0, 0.0)
	tool_system.select_tool_by_id("toxin_net")
	tool_system.activate_tool("toxin_net")
	_assert(first_monster.is_disarmed(), "toxin net disarms monsters in front")
	_assert(tool_system.get_tool_count("toxin_net") == 0, "toxin net is consumed after use")

	tool_system.select_tool_by_id("turtle_armor")
	tool_system.activate_tool("turtle_armor")
	_assert(tool_system.is_armor_active(), "turtle armor can be equipped")
	tool_run.handle_player_caught("collision")
	_assert(tool_run.run_state != RunSceneControllerScript.RunState.CAUGHT, "turtle armor blocks one monster contact death")
	_assert(not tool_system.is_armor_active(), "turtle armor breaks after blocking")

	var speed_before: float = tool_run.player.velocity.length()
	tool_system.select_tool_by_id("propeller")
	tool_system.activate_tool("propeller")
	_assert(tool_run.player.velocity.length() > speed_before + 300.0, "propeller gives a forward burst")
	_assert(tool_system.get_tool_cooldown("propeller") > 0.0, "propeller enters cooldown")

	var freeze_monster = tool_run.monsters[1]
	freeze_monster.global_position = tool_run.player.global_position
	tool_system.select_tool_by_id("freeze_trap")
	tool_system.activate_tool("freeze_trap")
	tool_system._update_traps()
	await process_frame
	_assert(freeze_monster.is_stunned(), "freeze trap controls monsters when triggered")
	_assert(tool_system.get_tool_count("freeze_trap") == 0, "freeze trap is consumed after deployment")

	var bomb_monster = tool_run.monsters[2]
	bomb_monster.global_position = tool_run.player.global_position + Vector2(300.0, 0.0)
	tool_system.select_tool_by_id("magma_bomb")
	tool_system.activate_tool("magma_bomb")
	_assert(bomb_monster.is_queued_for_deletion(), "magma bomb removes monsters in its blast radius")

	var whip_monster = tool_run.monsters[3]
	whip_monster.global_position = tool_run.player.global_position + Vector2(260.0, 0.0)
	tool_system.select_tool_by_id("electric_whip")
	tool_system.activate_tool("electric_whip")
	_assert(whip_monster.is_stunned(), "electric whip controls the first monster in front")
	_assert(tool_system.get_tool_cooldown("electric_whip") > 0.0, "electric whip starts its cooldown")

	tool_run.queue_free()
	await process_frame


func _test_map_population_distribution() -> void:
	var layout := RunLayout.build(4)
	_assert(RunLayout.get_anchor_count() == 7, "run layout authors exactly seven anchors")
	_assert(layout["anchors"].size() == 7, "generated layout exposes exactly seven anchors")

	var monster_kinds := {}
	var monster_speeds := {}

	for region_id in [1, 2, 3, 4]:
		_assert(_count_specs_in_region(layout["seaweed"], region_id) > 0, "region %d has seaweed" % region_id)
		_assert(_count_specs_in_region(layout["coral"], region_id) > 0, "region %d has coral" % region_id)
		_assert(_count_specs_in_region(layout["treasures"], region_id) > 0, "region %d has treasures" % region_id)

	for spec in layout["monsters"]:
		monster_kinds[String(spec.get("kind", ""))] = true
		monster_speeds[float(spec.get("patrol_speed", 0.0))] = true

	_assert(_count_specs_in_region(layout["chests"], 4) > _count_specs_in_region(layout["chests"], 1), "leftmost region has more chests than rightmost region")
	_assert(_count_specs_in_region(layout["monsters"], 4) > _count_specs_in_region(layout["monsters"], 1), "leftmost region has more monsters than rightmost region")
	_assert(monster_kinds.size() == 3, "run layout produces three monster kinds")
	_assert(monster_speeds.size() == 3, "monster kinds have three distinct patrol speeds")
	_assert(_count_treasure_rarity_in_region(layout["treasures"], 4, "legendary") > _count_treasure_rarity_in_region(layout["treasures"], 1, "legendary"), "leftmost region has more legendary treasure")
	_assert(_treasure_value_weight_in_region(layout["treasures"], 4) > _treasure_value_weight_in_region(layout["treasures"], 1), "leftmost region has more valuable treasure mix")


func _test_monster_collision_death_opens_failure_scene() -> void:
	var scene := load("res://scenes/run_scene.tscn")
	_assert(scene != null, "run scene loads for monster collision death")
	if scene == null:
		return

	var collision_run = scene.instantiate()
	root.add_child(collision_run)
	current_scene = collision_run
	await process_frame
	await physics_frame

	inventory.add_to_storage("backpack", "common", 1)
	collision_run.carried_counts["common"] = 1
	collision_run.carried_value = 25
	collision_run._on_monster_detected_player(collision_run.monsters[0], "collision")
	_assert(collision_run.run_state == RunSceneControllerScript.RunState.CAUGHT, "monster collision changes the run to caught state")
	for index in range(45):
		await process_frame

	var fail_scene = current_scene
	_assert(fail_scene != null and fail_scene.name == "Fail", "monster collision opens the failure scene")
	_assert(inventory.get_backpack_total_count() == 0, "monster collision death empties the backpack")
	if fail_scene != null and fail_scene.has_node("back"):
		fail_scene.get_node("back").pressed.emit()
		await process_frame
		await process_frame

	var boat = current_scene
	_assert(boat != null and boat.name == "BoatScene", "failure scene return button returns to boat scene")
	if boat != null:
		boat.queue_free()
		if current_scene == boat:
			current_scene = null
	await process_frame


func _test_initial_state() -> void:
	_assert(game.run_state == RunSceneControllerScript.RunState.SEARCHING, "run starts in searching state")
	_assert(game.player != null, "player exists")
	_assert(game.anchor != null, "anchor exists")
	_assert(game.treasures_remaining == game.treasures_container.get_child_count(), "treasure spawn count is tracked")
	_assert(game.monsters.size() >= 2, "patrol monsters exist")
	_assert(game.get_unlocked_region_count() == 1, "fresh progress starts with one unlocked region")
	_assert(game.spawn_anchor_id != "", "run chooses a spawn anchor")
	_assert(game.player.global_position.distance_to(game.spawn_anchor_position) < 1.0, "player spawns at the selected anchor")
	for anchor in game.anchors:
		_assert(String(anchor.get_meta("anchor_id", "")) != game.spawn_anchor_id, "spawn anchor is not instanced as an exit")
	_assert(game.anchor.get_meta("region_id", 1) <= game.get_unlocked_region_count(), "default extraction anchor is in an unlocked region")
	_assert(is_equal_approx(game.get_soft_boundary_x(), RunLayout.soft_boundary_x_for_unlocked_count(1)), "initial soft boundary is at the first region gate")
	_assert(game.get_locked_fog_count() > 0, "locked regions start covered by fog")
	_assert(game.get_boundary_segment_count() >= 60, "outer perimeter is built from segmented wall pieces")


func _test_scene_split_and_visibility() -> void:
	for path in ENTITY_SCENE_PATHS:
		_assert(load(path) != null, "entity scene loads: %s" % path)

	_assert(game.has_node("World/Background"), "run background node exists")
	_assert(game.get_cover_kind_count("reef") > 0, "solid reef cover scenes are instanced")
	_assert(game.get_cover_kind_count("seaweed") > 0, "seaweed scenes are instanced")
	_assert(game.get_cover_kind_count("coral") > 0, "coral scenes are instanced")
	_assert(game.has_node("World/Exits/AnchorExit"), "anchor scene is instanced")
	_assert(_all_spawned_entities_avoid_forbidden_zones(game), "spawned run entities avoid collision and no-monster zones")
	_assert(game.has_node("World/Fog"), "region fog container exists")
	_assert(game.has_node("RunHud"), "HUD scene is instanced")
	_assert(game.has_node("StorageTransferUi"), "run backpack UI is instanced")
	_assert(game.has_node("MiniMapUi"), "run minimap UI is instanced")
	_assert(game.has_node("PauseMenuUi"), "run pause menu UI is instanced")
	_assert(game.player.has_node("BodyPivot"), "player placeholder art exists")
	_assert(game.player.position.y >= 250.0, "player starts below the HUD area")
	_assert_uses_main_menu_font(game.get_node("RunHud/StatusPanel/MarginContainer/StatusLabel"), "run HUD uses the main menu Chinese font")
	_assert_uses_main_menu_font(game.get_node("RunHud/ObjectivePanel/MarginContainer/VBoxContainer/ObjectiveLabel"), "run objective HUD uses the main menu Chinese font")
	_assert_uses_main_menu_font(game.get_node("StorageTransferUi/Panel/MarginContainer/VBoxContainer/Header/TitleLabel"), "storage UI uses the main menu Chinese font")
	_assert_uses_main_menu_font(game.get_node("MiniMapUi/Panel/MarginContainer/VBoxContainer/Header/TitleLabel"), "minimap UI uses the main menu Chinese font")
	_assert_uses_main_menu_font(game.get_node("PauseMenuUi/Panel/MarginContainer/VBoxContainer/TitleLabel"), "pause UI uses the main menu Chinese font")

	var monster = game.monsters[0]
	_assert(monster.has_node("VisionCone"), "monster vision placeholder exists")
	_assert(game.treasures_container.get_child(0).has_node("Gem"), "treasure placeholder art exists")

	var run_storage_ui = game.get_node("StorageTransferUi")
	_assert(not game.is_backpack_ui_open(), "run backpack UI starts closed")
	var b_key := InputEventKey.new()
	b_key.keycode = KEY_B
	b_key.pressed = true
	game._unhandled_input(b_key)
	_assert(game.is_backpack_ui_open(), "B opens run backpack UI")
	_assert(not run_storage_ui.is_warehouse_visible(), "run backpack UI hides warehouse storage")
	_assert(_is_centered_control(run_storage_ui.get_node("Panel")), "run backpack UI is centered")
	game._unhandled_input(b_key)
	_assert(not game.is_backpack_ui_open(), "B closes run backpack UI")

	var m_key := InputEventKey.new()
	m_key.keycode = KEY_M
	m_key.pressed = true
	_assert(not game.is_minimap_open(), "run minimap UI starts closed")
	game._unhandled_input(m_key)
	_assert(game.is_minimap_open(), "M opens run minimap UI")
	_assert(game.get_minimap_visible_region_count() == 1, "fresh minimap shows only the first unlocked region")
	_assert(_is_centered_control(game.get_node("MiniMapUi/Panel")), "minimap UI is centered")
	game._unhandled_input(m_key)
	_assert(not game.is_minimap_open(), "M closes run minimap UI")


func _test_depth_lighting_gradient() -> void:
	var right_region_color: Color = game.get_depth_light_color_at_x(10000.0)
	var second_region_color: Color = game.get_depth_light_color_at_x(6000.0)
	var third_region_color: Color = game.get_depth_light_color_at_x(3000.0)
	var left_region_color: Color = game.get_depth_light_color_at_x(10.0)
	var first_boundary := RunLayout.soft_boundary_x_for_unlocked_count(1)
	var half_transition_width := RunSceneControllerScript.DEPTH_LIGHT_TRANSITION_WIDTH * 0.5

	_assert(_color_luminance(right_region_color) > _color_luminance(second_region_color), "rightmost region has the lightest depth filter")
	_assert(_color_luminance(second_region_color) > _color_luminance(third_region_color), "third region is darker than the second region")
	_assert(_color_luminance(third_region_color) > _color_luminance(left_region_color), "leftmost region has the darkest depth filter")
	_assert(_color_luminance(left_region_color) < 0.02, "leftmost region is very dark")

	var region_one_plateau: Color = game.get_depth_light_color_at_x(first_boundary + half_transition_width + 40.0)
	var region_two_plateau: Color = game.get_depth_light_color_at_x(first_boundary - half_transition_width - 40.0)
	_assert(_colors_close(region_one_plateau, right_region_color, 0.001), "rightmost region keeps one fixed depth filter away from boundaries")
	_assert(_colors_close(region_two_plateau, second_region_color, 0.001), "second region keeps one fixed depth filter away from boundaries")

	var boundary_middle: Color = game.get_depth_light_color_at_x(first_boundary)
	_assert(_color_luminance(right_region_color) > _color_luminance(boundary_middle), "depth filter starts darkening inside the boundary band")
	_assert(_color_luminance(boundary_middle) > _color_luminance(second_region_color), "depth filter reaches the next layer after the boundary band")

	game.player.global_position = Vector2(10000.0, 3000.0)
	game._update_depth_lighting()
	var current_right: Color = game.get_current_depth_light_color()
	game.player.global_position = Vector2(10.0, 3000.0)
	game._update_depth_lighting()
	var current_left: Color = game.get_current_depth_light_color()
	_assert(_color_luminance(current_right) > _color_luminance(current_left), "moving the player updates the active depth filter")


func _test_pause_menu_controls() -> void:
	var esc_key := InputEventKey.new()
	esc_key.keycode = KEY_ESCAPE
	esc_key.pressed = true

	_assert(not game.is_pause_menu_open(), "pause menu starts closed")
	game._unhandled_input(esc_key)
	_assert(game.is_pause_menu_open(), "Esc opens the pause menu")
	_assert(paused, "opening pause menu pauses the scene tree")
	_assert(game.get_node("PauseMenuUi").has_node("Panel/MarginContainer/VBoxContainer/ResumeButton"), "pause menu has a resume option")
	_assert(game.get_node("PauseMenuUi").has_node("Panel/MarginContainer/VBoxContainer/SettingsButton"), "pause menu has a settings option")
	_assert(game.get_node("PauseMenuUi").has_node("Panel/MarginContainer/VBoxContainer/ExitMenuButton"), "pause menu has an exit-to-menu option")
	_assert(_is_centered_control(game.get_node("PauseMenuUi/Panel")), "pause menu is centered")
	game.show_pause_settings()
	game.resume_from_pause()
	_assert(not game.is_pause_menu_open(), "resume closes the pause menu")
	_assert(not paused, "resume unpauses the scene tree")
	_assert(not game.get_node("PauseMenuUi").has_node("Panel/MarginContainer/VBoxContainer/ReturnBoatButton"), "pause menu does not expose return-to-ship")


func _test_player_movement_and_perimeter() -> void:
	for monster in game.monsters:
		monster.set_active(false)

	game.player.global_position = Vector2(8500, 5300)
	game.player.velocity = Vector2.ZERO
	var movement_delta := 1.0 / 60.0
	game.player._update_dash_timers(movement_delta)
	game.player._update_velocity(Vector2.RIGHT, movement_delta)
	var first_speed: float = game.player.velocity.length()
	_assert(first_speed > 0.0, "accelerated movement starts moving on input")
	_assert(first_speed < game.player.get_base_max_speed() * 0.35, "accelerated movement does not snap to max speed")

	for index in range(34):
		game.player._update_dash_timers(movement_delta)
		game.player._update_velocity(Vector2.RIGHT, movement_delta)
	var cruising_speed: float = game.player.velocity.length()
	_assert(cruising_speed > first_speed + 120.0, "accelerated movement builds speed over time")
	_assert(cruising_speed <= game.player.get_base_max_speed() + 35.0, "base movement stays under the slower max speed")

	game.player.trigger_dash(Vector2.RIGHT)
	game.player._update_velocity(Vector2.RIGHT, movement_delta)
	_assert(game.player.is_dash_active(), "Space starts the dash state")
	_assert(game.player.get_current_speed_cap() > game.player.get_base_max_speed(), "dash temporarily raises the speed cap")
	_assert(game.player.velocity.length() > game.player.get_base_max_speed(), "dash impulse can push velocity above base speed")

	for index in range(40):
		game.player._update_dash_timers(movement_delta)
		game.player._update_velocity(Vector2.RIGHT, movement_delta)
	_assert(game.player.get_current_speed_cap() <= game.player.get_base_max_speed() + 1.0, "dash speed cap curves back to base speed")

	var speed_before_release: float = game.player.velocity.length()
	for index in range(12):
		game.player._update_dash_timers(movement_delta)
		game.player._update_velocity(Vector2.ZERO, movement_delta)
	_assert(game.player.velocity.length() < speed_before_release, "movement decelerates after input release")

	var rebound_distance: float = game.player.get_world_boundary_rebound_distance()
	var near_right_edge := Vector2(game.world_rect.end.x - rebound_distance * 0.35, 3000.0)
	game.player.global_position = near_right_edge
	game.player.velocity = Vector2.ZERO
	for index in range(50):
		await physics_frame
	_assert(game.player.global_position.x < near_right_edge.x, "outer soft perimeter pushes the player inward")


func _test_region_progression() -> void:
	var boundary_x: float = game.get_soft_boundary_x()
	var rebound_distance: float = game.player.get_soft_left_boundary_rebound_distance()
	var released_in_margin := Vector2(boundary_x + rebound_distance * 0.35, 3000.0)
	game.player.global_position = released_in_margin
	for index in range(90):
		await physics_frame
	_assert(game.player.global_position.x > released_in_margin.x, "soft boundary elastically pushes the player outward after release")
	_assert(game.player.global_position.x <= boundary_x + rebound_distance + 20.0, "soft boundary release rebound stays near two body lengths")

	var pushed_from := Vector2(boundary_x - 180.0, 3000.0)
	game.player.global_position = pushed_from
	await physics_frame
	await physics_frame
	_assert(game.player.global_position.x > pushed_from.x, "soft boundary pushes the player back from locked space")
	_assert(game.player.is_soft_left_boundary_enabled(), "player has an active soft boundary")

	game.player.global_position = game.spawn_anchor_position
	var legendary_treasures := []
	for treasure in game.treasures_container.get_children():
		if String(treasure.rarity) == "legendary" and int(treasure.get_meta("region_id", 1)) == 1:
			legendary_treasures.append(treasure)
	_assert(legendary_treasures.size() >= 2, "first region has two legendary unlock items")

	var previous_remaining: int = game.treasures_remaining
	legendary_treasures[0].collect(game.player)
	await process_frame
	legendary_treasures[1].collect(game.player)
	await process_frame

	_assert(progress.get_uploaded_legendary_count() == 0, "legendary collection alone does not update uploaded progression")
	_assert(progress.get_unlocked_region_count() == 1, "legendary collection alone does not unlock the second region")
	_assert(game.get_unlocked_region_count() == 1, "run scene remains locked until upload progression changes")
	_assert(game.treasures_remaining == previous_remaining - 2, "unlock treasure collection still decrements run treasure count")

	game.handle_player_discovered("unlock cleanup")
	_assert(game.carried_value == 0, "unlock test cleanup clears carried value")
	progress.add_uploaded_legendary_progress(2)
	await process_frame
	_assert(progress.get_unlocked_region_count() == 2, "two uploaded legendary items unlock the second region")
	_assert(game.get_unlocked_region_count() == 2, "run scene reacts to uploaded progression unlock")
	_assert(is_equal_approx(game.get_soft_boundary_x(), RunLayout.soft_boundary_x_for_unlocked_count(2)), "soft boundary moves to the second region gate")
	_assert(game.get_minimap_visible_region_count() == 2, "minimap expands when the second region unlocks")


func _test_collect_and_clear_penalty() -> void:
	var treasure = game.treasures_container.get_child(0)
	var value: int = treasure.value
	var rarity: String = treasure.rarity
	var backpack_before: int = inventory.get_backpack_total_count()
	var rarity_before: int = inventory.get_backpack_count(rarity)
	var previous_remaining: int = game.treasures_remaining
	treasure.collect(game.player)
	await process_frame

	_assert(game.carried_value == value, "collecting treasure increases carried value")
	_assert(inventory.get_backpack_count(rarity) == rarity_before + 1, "collecting treasure stores item in backpack immediately")
	_assert(game.treasures_remaining == previous_remaining - 1, "collecting treasure decreases remaining count")

	var run_storage_ui = game.get_node("StorageTransferUi")
	var b_key := InputEventKey.new()
	b_key.keycode = KEY_B
	b_key.pressed = true
	game._unhandled_input(b_key)
	run_storage_ui.click_slot("backpack", 0, MOUSE_BUTTON_LEFT)
	_assert(run_storage_ui.get_cursor_stack()["count"] == 1, "run backpack can hold a picked-up item on the cursor")

	game.handle_player_discovered("test")
	_assert(game.carried_value == 0, "detection clears carried value")
	_assert(run_storage_ui.get_cursor_stack()["count"] == 0, "detection clears current run item even if it was held by the cursor")
	_assert(inventory.get_backpack_total_count() == backpack_before, "detection removes current run backpack items")
	_assert(game.warehouse_value == 0, "detection does not change banked value")
	game._unhandled_input(b_key)

	var chest = game.chests[0]
	chest._open()
	await process_frame
	_assert(inventory.get_backpack_total_count() == backpack_before + 1, "opening a chest stores one random item in backpack")
	_assert(game.carried_value > 0, "opening a chest increases carried value")
	game.handle_player_discovered("test chest")
	_assert(inventory.get_backpack_total_count() == backpack_before, "detection removes chest reward from backpack")


func _test_anchor_choices_and_extraction() -> void:
	game.choose_extract()
	_assert(game.run_state != RunSceneControllerScript.RunState.EXTRACTED, "extraction is ignored away from anchor")

	var treasure = game.treasures_container.get_child(0)
	var value: int = treasure.value
	var backpack_before: int = inventory.get_backpack_total_count()
	treasure.collect(game.player)
	await process_frame
	_assert(inventory.get_backpack_total_count() == backpack_before + 1, "run pickup enters backpack before extraction")

	game.player.global_position = game.anchor.global_position
	await physics_frame
	await physics_frame
	_assert(game.player_on_anchor, "standing on anchor is tracked")
	_assert(game.is_anchor_prompt_visible(), "anchor prompt is visible at anchor")

	var f_key := InputEventKey.new()
	f_key.keycode = KEY_F
	f_key.pressed = true
	game._unhandled_input(f_key)
	_assert(game.run_state == RunSceneControllerScript.RunState.EXTRACTED, "F extracts at the anchor")
	_assert(not game.is_anchor_prompt_visible(), "F hides anchor prompt")
	current_scene = game
	game.choose_extract()
	_assert(game.run_state == RunSceneControllerScript.RunState.EXTRACTED, "extracting ends the run")
	_assert(game.warehouse_value == value, "extracting banks carried value")
	_assert(game.carried_value == 0, "extracting clears carried value")
	_assert(inventory.get_backpack_total_count() == backpack_before + 1, "extracting keeps recovered backpack items without duplicating them")
	_assert(progress.has_pending_knowledge(), "extracting brings discovered knowledge back for upload")
	await process_frame
	await process_frame
	await process_frame
	transitioned_boat = current_scene
	_assert(transitioned_boat != null and transitioned_boat.name == "BoatScene", "extracting returns to boat scene")


func _test_inventory_and_boat_scene() -> void:
	var boat := transitioned_boat
	if boat == null:
		var boat_scene := load("res://scenes/boat_scene.tscn")
		_assert(boat_scene != null, "boat scene loads")
		if boat_scene == null:
			return
		boat = boat_scene.instantiate()
		root.add_child(boat)
	await process_frame

	_assert(load("res://scenes/boat_scene.tscn") != null, "boat scene loads")
	_assert(boat.has_node("World/Manhole"), "boat has dive hatch")
	_assert(boat.has_node("World/MissionConsole"), "boat has mission console")
	_assert(boat.has_node("World/PurifierDevice"), "boat has purifier device")
	_assert(boat.has_node("World/UploadDevice"), "boat has upload device")
	_assert(boat.has_node("World/Warehouse"), "boat has warehouse")
	_assert(boat.has_node("BoatHud/Panel/InventoryLabel"), "boat inventory HUD exists")
	_assert(boat.has_node("StorageTransferUi"), "boat storage transfer UI exists")
	_assert(boat.has_node("MissionConsoleUi"), "boat mission console UI exists")
	_assert_uses_main_menu_font(boat.get_node("BoatHud/Panel/InventoryLabel"), "boat HUD uses the main menu Chinese font")
	_assert_uses_main_menu_font(boat.get_node("MissionConsoleUi/Panel/MarginContainer/VBoxContainer/Header/TitleLabel"), "boat mission UI uses the main menu Chinese font")

	var storage_ui = boat.get_node("StorageTransferUi")
	var mission_ui = boat.get_node("MissionConsoleUi")
	_assert(not boat.is_storage_ui_open(), "storage UI starts closed")
	_assert(not boat.is_mission_ui_open(), "mission UI starts closed")

	var b_key := InputEventKey.new()
	b_key.keycode = KEY_B
	b_key.pressed = true
	boat._unhandled_input(b_key)
	_assert(boat.is_storage_ui_open(), "B opens storage UI")
	_assert(_is_centered_control(storage_ui.get_node("Panel")), "boat storage UI is centered")
	boat._unhandled_input(b_key)
	_assert(not boat.is_storage_ui_open(), "B closes storage UI")

	var warehouse_handled: bool = boat.perform_interaction("warehouse")
	_assert(warehouse_handled, "boat warehouse interaction is handled")
	_assert(boat.is_storage_ui_open(), "warehouse interaction opens storage UI")
	_assert(inventory.get_backpack_total_count() == 1, "opening warehouse keeps backpack items")
	_assert(inventory.get_warehouse_total_count() == 0, "opening warehouse does not auto-store items")

	inventory.receive_extracted_counts({"common": 3, "rare": 0, "legendary": 0})
	storage_ui.refresh()
	_assert(inventory.get_backpack_count("common") == 4, "backpack grid stacks matching item icons")

	storage_ui.click_slot("backpack", 0, MOUSE_BUTTON_RIGHT)
	_assert(storage_ui.get_cursor_stack()["count"] == 2, "right click takes half a stack")
	_assert(storage_ui.is_cursor_preview_visible(), "held item preview appears at the cursor")
	_assert(inventory.get_backpack_count("common") == 2, "right click leaves the other half in the slot")

	storage_ui.click_slot("warehouse", 0, MOUSE_BUTTON_RIGHT)
	_assert(storage_ui.get_cursor_stack()["count"] == 1, "right click places one item from hand")
	_assert(inventory.get_warehouse_count("common") == 1, "right click places one item into target slot")

	storage_ui.click_slot("backpack", 0, MOUSE_BUTTON_LEFT)
	_assert(storage_ui.get_cursor_stack()["count"] == 0, "left click places all held items")
	_assert(not storage_ui.is_cursor_preview_visible(), "held item preview hides after placing all items")
	_assert(inventory.get_backpack_count("common") == 3, "left click merges held stack into matching slot")

	storage_ui.click_slot("warehouse", 0, MOUSE_BUTTON_LEFT)
	storage_ui.click_slot("backpack", 0, MOUSE_BUTTON_LEFT)
	_assert(inventory.get_backpack_count("common") == 4, "left click can pick up and replace a full stack")
	_assert(inventory.get_warehouse_total_count() == 0, "left click transfer clears source slot")

	storage_ui.click_slot("backpack", 0, MOUSE_BUTTON_LEFT, true)
	_assert(inventory.get_backpack_total_count() == 0, "shift click quick-moves a backpack stack")
	_assert(inventory.get_warehouse_count("common") == 4, "shift click moves stack to warehouse")

	storage_ui.click_slot("warehouse", 0, MOUSE_BUTTON_LEFT, true)
	_assert(inventory.get_backpack_count("common") == 4, "shift click can move warehouse stack back")
	_assert(inventory.get_warehouse_total_count() == 0, "shift click clears warehouse source stack")

	inventory.add_to_storage("warehouse", "rare", 1)
	storage_ui.refresh()
	storage_ui.click_slot("backpack", 0, MOUSE_BUTTON_LEFT)
	storage_ui.click_slot("warehouse", 0, MOUSE_BUTTON_LEFT)
	_assert(inventory.get_warehouse_count("common") == 4, "left click swaps different item types instead of merging")
	_assert(inventory.get_warehouse_count("rare") == 0, "different item types do not share one slot")
	_assert(storage_ui.get_cursor_stack()["rarity"] == "rare", "swapping leaves the replaced item on the cursor")
	storage_ui.click_slot("backpack", 0, MOUSE_BUTTON_LEFT)
	storage_ui.click_slot("backpack", 0, MOUSE_BUTTON_LEFT, true)
	storage_ui.click_slot("warehouse", 0, MOUSE_BUTTON_LEFT, true)
	_assert(inventory.get_backpack_count("common") == 4, "common stack returns to backpack after swap guard test")

	inventory.receive_extracted_counts({"common": 1, "rare": 0, "legendary": 1})
	var upload_handled: bool = boat.perform_interaction("upload")
	_assert(upload_handled, "boat upload interaction is handled")
	_assert(inventory.get_backpack_total_count() == 0, "upload clears backpack")
	_assert(inventory.get_uploaded_count("common") == 5, "upload records common items")
	_assert(inventory.get_uploaded_count("legendary") == 1, "upload records legendary items")
	_assert(inventory.research_points == 325, "upload adds research points")
	_assert(progress.is_tool_unlocked("toxin_net"), "uploading recovered knowledge unlocks its mapped tool")
	_assert(boat.get_node("BoatHud/Panel/InventoryLabel").text.contains("研究点：325"), "boat HUD shows research points")

	progress.reset_save()
	progress.mark_intro_seen()
	var mission_handled: bool = boat.perform_interaction("mission")
	_assert(mission_handled, "boat mission interaction is handled")
	_assert(boat.is_mission_ui_open(), "mission interaction opens the task panel")
	_assert(mission_ui.get_task_count() >= 5, "mission panel shows the task list")
	_assert(mission_ui.get_spawn_option_count() == 3, "locked mission panel previews first-region spawn anchors")
	_assert(not boat.select_mission_spawn_anchor("coral_mid"), "spawn selection is locked before signal tower completion")
	_assert(progress.get_selected_spawn_anchor_id() == "", "locked mission panel does not change selected spawn")

	progress.add_uploaded_legendary_progress(2)
	progress.deploy_signal_site("signal_bridge")
	progress.deploy_signal_site("signal_volcano")
	boat.perform_interaction("mission")
	await process_frame
	_assert(mission_ui.get_spawn_option_count() == 6, "mission panel lists all unlocked spawn anchors after region three opens")
	_assert(boat.select_mission_spawn_anchor("abyss_ridge"), "mission panel can select an unlocked spawn anchor")
	await process_frame
	_assert(progress.get_selected_spawn_anchor_id() == "abyss_ridge", "mission panel writes the selected spawn anchor")
	_assert(boat.get_node("BoatHud/Panel/MessageLabel").text.contains("深海平原"), "mission panel selection updates boat status text")
	_assert(mission_ui.get_spawn_option_count() == 6, "mission panel refreshes after selecting an anchor")
	_assert(boat.select_mission_spawn_anchor(""), "mission panel can restore default deepest-region random spawn")
	await process_frame
	_assert(progress.get_selected_spawn_anchor_id() == "", "mission panel clears selected spawn anchor for default spawn")

	boat.queue_free()
	if current_scene == boat:
		current_scene = null
	transitioned_boat = null
	await process_frame


func _test_monster_vision_guards() -> void:
	var monster = game.monsters[0]
	monster.set_active(false)
	monster.state = MonsterPatrolScript.State.PATROL
	monster.global_position = Vector2(8300, 1800)
	monster.facing = Vector2.RIGHT
	game.player.global_position = Vector2(8420, 1800)
	game.player.cover_depth = 0
	await physics_frame

	_assert(monster.can_see_player(game.player), "monster sees player inside forward cone")

	game.player.enter_cover()
	_assert(not monster.can_see_player(game.player), "hiding cover prevents sight")
	game.player.exit_cover()

	game.player.global_position = Vector2(8180, 1800)
	_assert(not monster.can_see_player(game.player), "monster does not see behind itself")

	game.player.global_position = Vector2(8450, 1800)
	var blocker := StaticBody2D.new()
	blocker.name = "VisionBlocker"
	blocker.global_position = Vector2(8370, 1800)
	blocker.collision_layer = RunSceneControllerScript.WALL_LAYER
	blocker.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(26, 140)
	collision.shape = shape
	blocker.add_child(collision)
	game.world.add_child(blocker)
	await physics_frame
	await physics_frame

	_assert(not monster.can_see_player(game.player), "solid cover blocks monster sight ray")
	blocker.queue_free()


func _test_lobby_debug_controls() -> void:
	var lobby_scene := load("res://scenes/ui/lobby.tscn")
	_assert(lobby_scene != null, "lobby scene loads")
	if lobby_scene == null:
		return

	var lobby = lobby_scene.instantiate()
	root.add_child(lobby)
	await process_frame

	_assert(lobby.has_node("save_debug"), "lobby has save debug button")
	_assert(lobby.has_node("DebugPanel"), "lobby has save debug panel")
	lobby.get_node("save_debug").pressed.emit()
	_assert(lobby.is_debug_panel_visible(), "save debug button opens the debug panel")

	_assert(lobby.perform_debug_save_action("reset"), "debug reset action is handled")
	_assert(progress.get_unlocked_region_count() == 1, "debug reset locks progress to the first region")
	_assert(lobby.perform_debug_save_action("add_uploaded_legendary"), "debug add uploaded legendary action is handled")
	_assert(progress.get_uploaded_legendary_count() == 1, "debug add uploaded legendary updates save progress")
	_assert(lobby.perform_debug_save_action("unlock_next"), "debug unlock next action is handled")
	_assert(progress.get_unlocked_region_count() == 2, "debug unlock next opens the second region")
	_assert(lobby.perform_debug_save_action("lock_start"), "debug lock start action is handled")
	_assert(progress.get_unlocked_region_count() == 1, "debug lock start closes back to the first region")
	_assert(progress.get_uploaded_legendary_count() < 2, "debug lock start remains locked after reload rules")

	lobby.queue_free()
	await process_frame


func _assert_default_spawn_uses_deepest_unlocked_region(expected_region_id: int) -> void:
	progress.set_selected_spawn_anchor_id("")
	var scene := load("res://scenes/run_scene.tscn")
	var spawn_run = scene.instantiate()
	root.add_child(spawn_run)
	await process_frame
	await physics_frame

	_assert(_anchor_region_id(spawn_run.spawn_anchor_id) == expected_region_id, "default spawn uses the deepest unlocked region")
	spawn_run.queue_free()
	await process_frame


func _assert_selected_spawn_anchor_override(anchor_id: String) -> void:
	progress.set_selected_spawn_anchor_id(anchor_id)
	var scene := load("res://scenes/run_scene.tscn")
	var spawn_run = scene.instantiate()
	root.add_child(spawn_run)
	await process_frame
	await physics_frame

	_assert(spawn_run.spawn_anchor_id == anchor_id, "manual selected spawn anchor overrides deepest-region default")
	spawn_run.queue_free()
	progress.set_selected_spawn_anchor_id("")
	await process_frame


func _anchor_region_id(anchor_id: String) -> int:
	for spec in RunLayout.get_anchor_specs_for_unlocked_count(4):
		if String(spec.get("id", "")) == anchor_id:
			return int(spec.get("region_id", 0))
	return 0


func _key_event(keycode: int, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	return event


func _count_specs_in_region(specs: Array, region_id: int) -> int:
	var count := 0
	for spec in specs:
		if int(spec.get("region_id", 0)) == region_id:
			count += 1
	return count


func _all_spawned_entities_avoid_forbidden_zones(run_scene: Node) -> bool:
	var forbidden_polygons := _forbidden_zone_polygons(run_scene.world)
	if forbidden_polygons.is_empty():
		return true

	if _point_in_any_polygon(run_scene.player.global_position, forbidden_polygons):
		return false

	for anchor in run_scene.anchors:
		if _point_in_any_polygon(anchor.global_position, forbidden_polygons):
			return false

	for chest in run_scene.chests:
		if _point_in_any_polygon(chest.global_position, forbidden_polygons):
			return false

	for treasure in run_scene.treasures_container.get_children():
		if _point_in_any_polygon(treasure.global_position, forbidden_polygons):
			return false

	for cover in run_scene.world.get_node("Cover").get_children():
		if bool(cover.get_meta("boundary_segment", false)):
			continue
		if String(cover.get_meta("cover_kind", "")) in ["reef", "wreck"] and _point_in_any_polygon(cover.global_position, forbidden_polygons):
			return false
		if String(cover.get_meta("cover_kind", "")) == "seaweed" and _point_in_any_polygon(cover.global_position, forbidden_polygons):
			return false
		if String(cover.get_meta("cover_kind", "")) == "coral" and _point_in_any_polygon(cover.global_position, forbidden_polygons):
			return false

	for monster in run_scene.monsters:
		if _point_in_any_polygon(monster.global_position, forbidden_polygons):
			return false

	return true


func _forbidden_zone_polygons(world: Node) -> Array:
	var polygons := []
	if world == null:
		return polygons

	for zone_name in ["collision", "no-monster"]:
		var zone := world.get_node_or_null(zone_name)
		if zone == null:
			continue
		for child in zone.get_children():
			if not (child is CollisionPolygon2D):
				continue
			var world_polygon := PackedVector2Array()
			for point in child.polygon:
				world_polygon.append(zone.to_global(point))
			if not world_polygon.is_empty():
				polygons.append(world_polygon)
	return polygons


func _point_in_any_polygon(point: Vector2, polygons: Array) -> bool:
	for polygon in polygons:
		if Geometry2D.is_point_in_polygon(point, polygon):
			return true
	return false


func _count_treasure_rarity_in_region(specs: Array, region_id: int, rarity: String) -> int:
	var count := 0
	for spec in specs:
		if int(spec.get("region_id", 0)) == region_id and String(spec.get("rarity", "")) == rarity:
			count += 1
	return count


func _treasure_value_weight_in_region(specs: Array, region_id: int) -> int:
	var value := 0
	for spec in specs:
		if int(spec.get("region_id", 0)) != region_id:
			continue
		match String(spec.get("rarity", "")):
			"common":
				value += 1
			"rare":
				value += 3
			"legendary":
				value += 8
	return value


func _color_luminance(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722


func _colors_close(first: Color, second: Color, tolerance: float) -> bool:
	return absf(first.r - second.r) <= tolerance and absf(first.g - second.g) <= tolerance and absf(first.b - second.b) <= tolerance


func _assert_uses_main_menu_font(control: Control, label: String) -> void:
	var font: Font = control.get_theme_font("font")
	_assert(font != null and font.resource_path == MAIN_MENU_FONT_PATH, label)


func _is_centered_control(control: Control, tolerance: float = 2.0) -> bool:
	var viewport_center := root.get_visible_rect().size * 0.5
	return control.get_global_rect().get_center().distance_to(viewport_center) <= tolerance


func _assert(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
		printerr("FAIL: %s" % label)


func _finish() -> void:
	if failures.is_empty():
		print("ACCEPTANCE TESTS PASSED")
		quit(0)
	else:
		printerr("ACCEPTANCE TESTS FAILED: %s" % ", ".join(failures))
		quit(1)
