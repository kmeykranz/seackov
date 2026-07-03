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
	"res://scenes/props/sea_floor.tscn",
	"res://scenes/ui/run_hud.tscn",
]

var failures: Array[String] = []
var game: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
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
	await _test_anchor_choices_and_extraction()
	await _test_monster_vision_guards()

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

	_assert(game.has_node("World/Background/SeaFloor"), "sea floor scene is instanced")
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

	game.choose_extract()
	_assert(game.run_state == RunSceneControllerScript.RunState.EXTRACTED, "extracting ends the run")
	_assert(game.warehouse_value == value, "extracting banks carried value")
	_assert(game.carried_value == 0, "extracting clears carried value")


func _test_monster_vision_guards() -> void:
	var monster = game.monsters[0]
	monster.set_active(false)
	monster.state = MonsterPatrolScript.State.PATROL
	monster.global_position = Vector2(300, 300)
	monster.facing = Vector2.RIGHT
	game.player.global_position = Vector2(420, 300)
	game.player.cover_depth = 0
	await physics_frame

	_assert(monster.can_see_player(game.player), "monster sees player inside forward cone")

	game.player.enter_cover()
	_assert(not monster.can_see_player(game.player), "hiding cover prevents sight")
	game.player.exit_cover()

	game.player.global_position = Vector2(180, 300)
	_assert(not monster.can_see_player(game.player), "monster does not see behind itself")

	game.player.global_position = Vector2(450, 300)
	var blocker := StaticBody2D.new()
	blocker.name = "VisionBlocker"
	blocker.global_position = Vector2(370, 300)
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
