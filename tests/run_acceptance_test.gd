extends SceneTree

const RunSceneControllerScript := preload("res://scripts/game_controller.gd")
const MonsterPatrolScript := preload("res://scripts/monster_patrol.gd")
const RunLayout := preload("res://scripts/level/run_layout.gd")

const ENTITY_SCENE_PATHS := [
	"res://scenes/actors/player_diver.tscn",
	"res://scenes/actors/monster_patrol.tscn",
	"res://scenes/pickups/treasure_pickup.tscn",
	"res://scenes/props/anchor_exit.tscn",
	"res://scenes/props/solid_cover.tscn",
	"res://scenes/props/seaweed_cover.tscn",
	"res://scenes/props/coral.tscn",
	"res://scenes/props/chest_box.tscn",
	"res://scenes/ui/run_hud.tscn",
	"res://scenes/ui/storage_transfer_ui.tscn",
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
	_test_map_population_distribution()
	await _test_monster_collision_death_returns_boat()
	progress.reset_save()
	inventory.reset_runtime_state()
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
	await _test_pause_menu_controls()
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
	var expected_regions := [2, 3, 4]
	for expected_region in expected_regions:
		inventory.add_to_storage("backpack", "legendary", 2)
		var upload_handled: bool = boat.perform_interaction("upload")
		_assert(upload_handled, "boat upload handles legendary progression batch")
		_assert(inventory.get_backpack_total_count() == 0, "upload progression batch clears backpack")
		_assert(progress.get_unlocked_region_count() == expected_region, "uploaded legendary progression unlocks region %d" % expected_region)

	_assert(progress.get_uploaded_legendary_count() == 6, "uploaded legendary progress is persisted through all region thresholds")

	boat.queue_free()
	await process_frame


func _test_map_population_distribution() -> void:
	var layout := RunLayout.build(4)
	_assert(RunLayout.get_anchor_count() == 7, "run layout authors exactly seven anchors")
	_assert(layout["anchors"].size() == 7, "generated layout exposes exactly seven anchors")

	for region_id in [1, 2, 3, 4]:
		_assert(_count_specs_in_region(layout["seaweed"], region_id) > 0, "region %d has seaweed" % region_id)
		_assert(_count_specs_in_region(layout["coral"], region_id) > 0, "region %d has coral" % region_id)
		_assert(_count_specs_in_region(layout["treasures"], region_id) > 0, "region %d has treasures" % region_id)

	_assert(_count_specs_in_region(layout["chests"], 4) > _count_specs_in_region(layout["chests"], 1), "leftmost region has more chests than rightmost region")
	_assert(_count_specs_in_region(layout["monsters"], 4) > _count_specs_in_region(layout["monsters"], 1), "leftmost region has more monsters than rightmost region")
	_assert(_count_treasure_rarity_in_region(layout["treasures"], 4, "legendary") > _count_treasure_rarity_in_region(layout["treasures"], 1, "legendary"), "leftmost region has more legendary treasure")
	_assert(_treasure_value_weight_in_region(layout["treasures"], 4) > _treasure_value_weight_in_region(layout["treasures"], 1), "leftmost region has more valuable treasure mix")


func _test_monster_collision_death_returns_boat() -> void:
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
	await process_frame
	await process_frame
	await process_frame

	var boat = current_scene
	_assert(boat != null and boat.name == "BoatScene", "monster collision returns to boat scene")
	_assert(inventory.get_backpack_total_count() == 0, "monster collision death empties the backpack")
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
	_assert(game.has_node("World/Fog"), "region fog container exists")
	_assert(game.has_node("RunHud"), "HUD scene is instanced")
	_assert(game.has_node("StorageTransferUi"), "run backpack UI is instanced")
	_assert(game.has_node("MiniMapUi"), "run minimap UI is instanced")
	_assert(game.has_node("PauseMenuUi"), "run pause menu UI is instanced")
	_assert(game.player.has_node("BodyPivot"), "player placeholder art exists")
	_assert(game.player.position.y >= 250.0, "player starts below the HUD area")

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
	game._unhandled_input(b_key)
	_assert(not game.is_backpack_ui_open(), "B closes run backpack UI")

	var m_key := InputEventKey.new()
	m_key.keycode = KEY_M
	m_key.pressed = true
	_assert(not game.is_minimap_open(), "run minimap UI starts closed")
	game._unhandled_input(m_key)
	_assert(game.is_minimap_open(), "M opens run minimap UI")
	_assert(game.get_minimap_visible_region_count() == 1, "fresh minimap shows only the first unlocked region")
	game._unhandled_input(m_key)
	_assert(not game.is_minimap_open(), "M closes run minimap UI")


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

	game.choose_continue()
	_assert(game.run_state == RunSceneControllerScript.RunState.SEARCHING, "continue keeps the run active")
	_assert(not game.is_anchor_prompt_visible(), "continue hides anchor prompt")
	game.choose_extract()
	_assert(game.run_state == RunSceneControllerScript.RunState.SEARCHING, "hidden anchor prompt cannot extract")

	game.player.global_position = Vector2(120, 140)
	await physics_frame
	await physics_frame
	game.player.global_position = game.anchor.global_position
	await physics_frame
	await physics_frame

	current_scene = game
	game.choose_extract()
	_assert(game.run_state == RunSceneControllerScript.RunState.EXTRACTED, "extracting ends the run")
	_assert(game.warehouse_value == value, "extracting banks carried value")
	_assert(game.carried_value == 0, "extracting clears carried value")
	_assert(inventory.get_backpack_total_count() == backpack_before + 1, "extracting keeps recovered backpack items without duplicating them")
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

	var storage_ui = boat.get_node("StorageTransferUi")
	_assert(not boat.is_storage_ui_open(), "storage UI starts closed")

	var b_key := InputEventKey.new()
	b_key.keycode = KEY_B
	b_key.pressed = true
	boat._unhandled_input(b_key)
	_assert(boat.is_storage_ui_open(), "B opens storage UI")
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
	_assert(boat.get_node("BoatHud/Panel/InventoryLabel").text.contains("研究点：325"), "boat HUD shows research points")

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


func _count_specs_in_region(specs: Array, region_id: int) -> int:
	var count := 0
	for spec in specs:
		if int(spec.get("region_id", 0)) == region_id:
			count += 1
	return count


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
