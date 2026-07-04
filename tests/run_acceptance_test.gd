extends SceneTree

const RunSceneControllerScript := preload("res://scripts/game_controller.gd")
const MonsterPatrolScript := preload("res://scripts/monster_patrol.gd")

const ENTITY_SCENE_PATHS := [
	"res://scenes/actors/player_diver.tscn",
	"res://scenes/actors/monster_patrol.tscn",
	"res://scenes/pickups/treasure_pickup.tscn",
	"res://scenes/props/anchor_exit.tscn",
	"res://scenes/props/solid_cover.tscn",
	"res://scenes/props/seaweed_cover.tscn",
	"res://scenes/ui/run_hud.tscn",
	"res://scenes/boat_scene.tscn",
]

var failures: Array[String] = []
var game: Node
var inventory
var transitioned_boat: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	inventory = root.get_node("/root/PlayerInventory")
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
	await _test_collect_and_clear_penalty()
	await _test_monster_vision_guards()
	await _test_anchor_choices_and_extraction()
	await _test_inventory_and_boat_scene()

	_finish()


func _test_initial_state() -> void:
	_assert(game.run_state == RunSceneControllerScript.RunState.SEARCHING, "run starts in searching state")
	_assert(game.player != null, "player exists")
	_assert(game.anchor != null, "anchor exists")
	_assert(game.treasures_remaining == 9, "treasure spawn count is tracked")
	_assert(game.monsters.size() == 2, "patrol monsters exist")


func _test_scene_split_and_visibility() -> void:
	for path in ENTITY_SCENE_PATHS:
		_assert(load(path) != null, "entity scene loads: %s" % path)

	_assert(game.has_node("World/Background"), "run background node exists")
	_assert(game.has_node("World/Cover/NorthReef"), "solid cover scene is instanced")
	_assert(game.has_node("World/Cover/WestGrass"), "seaweed scene is instanced")
	_assert(game.has_node("World/Exits/AnchorExit"), "anchor scene is instanced")
	_assert(game.has_node("RunHud"), "HUD scene is instanced")
	_assert(game.player.has_node("BodyPivot"), "player placeholder art exists")
	_assert(game.player.position.y >= 250.0, "player starts below the HUD area")

	var monster = game.monsters[0]
	_assert(monster.has_node("VisionCone"), "monster vision placeholder exists")
	_assert(game.treasures_container.get_child(0).has_node("Gem"), "treasure placeholder art exists")


func _test_collect_and_clear_penalty() -> void:
	var treasure = game.treasures_container.get_child(0)
	var value: int = treasure.value
	treasure.collect(game.player)
	await process_frame

	_assert(game.carried_value == value, "collecting treasure increases carried value")
	_assert(game.treasures_remaining == 8, "collecting treasure decreases remaining count")

	game.handle_player_discovered("test")
	_assert(game.carried_value == 0, "detection clears carried value")
	_assert(game.warehouse_value == 0, "detection does not change banked value")


func _test_anchor_choices_and_extraction() -> void:
	game.choose_extract()
	_assert(game.run_state != RunSceneControllerScript.RunState.EXTRACTED, "extraction is ignored away from anchor")

	var treasure = game.treasures_container.get_child(0)
	var value: int = treasure.value
	treasure.collect(game.player)
	await process_frame

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
	_assert(inventory.get_backpack_total_count() == 1, "extracting moves recovered items into backpack")
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
	_assert(inventory.get_backpack_count("common") == 2, "right click leaves the other half in the slot")

	storage_ui.click_slot("warehouse", 0, MOUSE_BUTTON_RIGHT)
	_assert(storage_ui.get_cursor_stack()["count"] == 1, "right click places one item from hand")
	_assert(inventory.get_warehouse_count("common") == 1, "right click places one item into target slot")

	storage_ui.click_slot("backpack", 0, MOUSE_BUTTON_LEFT)
	_assert(storage_ui.get_cursor_stack()["count"] == 0, "left click places all held items")
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
	monster.global_position = Vector2(300, 180)
	monster.facing = Vector2.RIGHT
	game.player.global_position = Vector2(420, 180)
	game.player.cover_depth = 0
	await physics_frame

	_assert(monster.can_see_player(game.player), "monster sees player inside forward cone")

	game.player.enter_cover()
	_assert(not monster.can_see_player(game.player), "hiding cover prevents sight")
	game.player.exit_cover()

	game.player.global_position = Vector2(180, 180)
	_assert(not monster.can_see_player(game.player), "monster does not see behind itself")

	game.player.global_position = Vector2(450, 180)
	var blocker := StaticBody2D.new()
	blocker.name = "VisionBlocker"
	blocker.global_position = Vector2(370, 180)
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
