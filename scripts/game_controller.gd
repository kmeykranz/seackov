extends Node2D
class_name RunSceneController

const CollisionLayers := preload("res://scripts/support/collision_layers.gd")
const RunLayout := preload("res://scripts/level/run_layout.gd")
const LevelBuilderScript := preload("res://scripts/level/level_builder.gd")
const BoatScenePath := "res://scenes/boat_scene.tscn"
const LobbyScenePath := "res://scenes/ui/lobby.tscn"
const FailScenePath := "res://scenes/ui/fail.tscn"
const STORAGE_BACKPACK := "backpack"

const PLAYER_LAYER: int = CollisionLayers.PLAYER
const WALL_LAYER: int = CollisionLayers.WALL
const MONSTER_LAYER: int = CollisionLayers.MONSTER
const TREASURE_LAYER: int = CollisionLayers.TREASURE
const EXIT_LAYER: int = CollisionLayers.EXIT
const COVER_LAYER: int = CollisionLayers.COVER
const DRAW_ORDER_SCALE := 0.5

enum RunState {SEARCHING, ANCHOR_PROMPT, EXTRACTED, CAUGHT}

var run_state: RunState = RunState.SEARCHING
var world_rect: Rect2

var player: Node
var anchor: Node
var anchors: Array = []
var active_anchor: Node
var chests: Array = []
var world: Node2D
var treasures_container: Node2D
var monsters_container: Node2D
var monsters: Array = []
var spawn_anchor_id: String = ""
var spawn_anchor_position: Vector2
var unlocked_region_count: int = 1
var regions: Array = []
var locked_region_rects: Array = []
var soft_boundary_x: float = -1.0
var soft_boundary_margin: float = 520.0

var player_on_anchor: bool = false
var carried_value: int = 0
var warehouse_value: int = 0
var treasures_remaining: int = 0
var carried_counts := {
	"common": 0,
	"rare": 0,
	"legendary": 0,
}
var warehouse_counts := {
	"common": 0,
	"rare": 0,
	"legendary": 0,
}

@onready var _background_container: Node2D = $World/Background
@onready var _cover_container: Node2D = $World/Cover
@onready var _pickup_container: Node2D = $World/Pickups
@onready var _exit_container: Node2D = $World/Exits
@onready var _actor_container: Node2D = $World/Actors
@onready var _fog_container: Node2D = $World/Fog
@onready var _hud: CanvasLayer = $RunHud
@onready var _storage_ui: CanvasLayer = $StorageTransferUi
@onready var _minimap_ui: CanvasLayer = $MiniMapUi
@onready var _pause_menu: CanvasLayer = $PauseMenuUi


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	world = $World
	treasures_container = _pickup_container
	monsters_container = _actor_container
	_build_level()
	_wire_ui()
	_update_status()

	var music_manager = _music_manager()
	if music_manager != null:
		music_manager.play_underwater()
		music_manager.play_bubble()
		music_manager.diving_from_boat = false

	_hud.show_message("Collect treasure, hide in seaweed, use cover, extract at the anchor.")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	if run_state == RunState.EXTRACTED or run_state == RunState.CAUGHT:
		return

	if event.keycode == KEY_ESCAPE:
		_handle_key_input()
		if is_pause_menu_open():
			resume_from_pause()
		else:
			open_pause_menu()
		return

	if get_tree().paused:
		return

	if event.keycode == KEY_B:
		_handle_key_input()
		toggle_backpack_ui()
		return

	if event.keycode == KEY_M:
		_handle_key_input()
		toggle_minimap_ui()


func _physics_process(_delta: float) -> void:
	if get_tree().paused:
		return
	if anchor == null or player == null or run_state == RunState.EXTRACTED or run_state == RunState.CAUGHT:
		return

	var overlapping_anchor := _find_overlapping_anchor()
	if overlapping_anchor != null and overlapping_anchor != active_anchor:
		_on_anchor_player_entered(overlapping_anchor)
	elif overlapping_anchor == null and player_on_anchor:
		_on_anchor_player_exited()

	#_update_draw_order()


func choose_extract() -> void:
	if run_state != RunState.ANCHOR_PROMPT or not player_on_anchor:
		return
	if not _return_backpack_cursor_stack():
		_hud.show_message("Return the held backpack item before extracting.")
		return

	for rarity in warehouse_counts.keys():
		warehouse_counts[rarity] += carried_counts[rarity]
		carried_counts[rarity] = 0

	warehouse_value += carried_value
	carried_value = 0
	run_state = RunState.EXTRACTED
	_set_gameplay_enabled(false)
	_hud.hide_anchor_prompt()
	_hud.show_end(warehouse_value)
	_hud.show_message("Run complete.")
	_update_status()
	_leave_pause_mode()
	_stop_bubble()
	get_tree().change_scene_to_file(BoatScenePath)


func choose_continue() -> void:
	if run_state != RunState.ANCHOR_PROMPT:
		return

	run_state = RunState.SEARCHING
	_hud.hide_anchor_prompt()
	_hud.show_message("Extraction skipped. Keep searching.")
	_update_status()


func handle_player_discovered(reason: String) -> void:
	if run_state == RunState.EXTRACTED or run_state == RunState.CAUGHT:
		return

	var lost_value := carried_value
	_return_backpack_cursor_stack()
	_inventory().remove_counts_from_storage(STORAGE_BACKPACK, carried_counts)
	for rarity in carried_counts.keys():
		carried_counts[rarity] = 0
	carried_value = 0
	_refresh_backpack_ui()

	if lost_value > 0:
		_hud.show_message("Detected by %s. Carried treasure lost: %d." % [reason, lost_value])
	else:
		_hud.show_message("Detected by %s, but no carried treasure was lost." % reason)
	_update_status()


func handle_player_caught(reason: String) -> void:
	if run_state == RunState.EXTRACTED or run_state == RunState.CAUGHT:
		return

	var music_mgr: Node = _music_manager()
	if music_mgr != null:
		music_mgr.play_fail()

	_return_backpack_cursor_stack()
	_inventory().clear_backpack()
	for rarity in carried_counts.keys():
		carried_counts[rarity] = 0
	carried_value = 0
	run_state = RunState.CAUGHT
	player_on_anchor = false
	active_anchor = null
	_set_gameplay_enabled(false)
	_hud.hide_anchor_prompt()
	_hud.show_message("Caught by %s. Backpack emptied." % reason)
	_update_status()
	_refresh_backpack_ui()
	_stop_bubble()

	get_tree().paused = true
	# await get_tree().create_timer(1.0).timeout
	get_tree().paused = false
	_transition_to_fail()


func is_anchor_prompt_visible() -> bool:
	return _hud.is_anchor_prompt_visible()


func is_backpack_ui_open() -> bool:
	return _storage_ui.is_open()


func is_minimap_open() -> bool:
	return _minimap_ui.is_open()


func is_pause_menu_open() -> bool:
	return _pause_menu != null and _pause_menu.is_open()


func get_minimap_visible_region_count() -> int:
	return _minimap_ui.get_visible_region_count()


func get_unlocked_region_count() -> int:
	return unlocked_region_count


func get_locked_fog_count() -> int:
	return _fog_container.get_child_count()


func get_soft_boundary_x() -> float:
	return soft_boundary_x


func get_boundary_segment_count() -> int:
	var count := 0
	for item in _cover_container.get_children():
		if bool(item.get_meta("boundary_segment", false)):
			count += 1
	return count


func get_cover_kind_count(kind: String) -> int:
	var count := 0
	for item in _cover_container.get_children():
		if String(item.get_meta("cover_kind", "")) == kind:
			count += 1
	return count


func _build_level() -> void:
	var builder := LevelBuilderScript.new()
	add_child(builder)
	var layout := RunLayout.build(_progress_unlocked_region_count())
	var result := builder.build(_containers(), layout)

	player = result["player"]
	anchor = result["anchor"]
	anchors = result["anchors"]
	spawn_anchor_id = result["spawn_anchor_id"]
	spawn_anchor_position = result["spawn_anchor_position"]
	chests = result["chests"]
	monsters = result["monsters"]
	world_rect = result["world_rect"]
	regions = result["regions"]
	locked_region_rects = result["locked_region_rects"]
	soft_boundary_x = float(result["soft_boundary_x"])
	soft_boundary_margin = float(result["soft_boundary_margin"])
	unlocked_region_count = int(result["unlocked_region_count"])
	treasures_remaining = result["treasures"].size()
	_refresh_region_access()

	for chest in chests:
		chest.opened.connect(_on_chest_opened)
	for treasure in result["treasures"]:
		treasure.collected.connect(_on_treasure_collected)
	for monster in monsters:
		monster.player_detected.connect(_on_monster_detected_player)


func _containers() -> Dictionary:
	return {
		"background": _background_container,
		"cover": _cover_container,
		"pickups": _pickup_container,
		"exits": _exit_container,
		"actors": _actor_container,
	}


func _wire_ui() -> void:
	_hud.extract_pressed.connect(choose_extract)
	_hud.continue_pressed.connect(choose_continue)
	_pause_menu.resume_pressed.connect(resume_from_pause)
	_pause_menu.settings_pressed.connect(show_pause_settings)
	_pause_menu.exit_to_menu_pressed.connect(exit_to_main_menu)
	_storage_ui.set_backpack_only(true)
	_storage_ui.storage_changed.connect(_on_storage_changed)
	_refresh_minimap_ui()
	var progress = _progress()
	if progress != null and not progress.progress_changed.is_connected(_on_progress_changed):
		progress.progress_changed.connect(_on_progress_changed)


func _on_treasure_collected(treasure: Node) -> void:
	if run_state == RunState.EXTRACTED:
		return

	var stored := _add_run_item_to_backpack(treasure.rarity, treasure.value)
	treasures_remaining = maxi(0, treasures_remaining - 1)
	if stored:
		_hud.show_message("Collected %s treasure worth %d into backpack." % [treasure.rarity, treasure.value])
	_update_status()


func _on_chest_opened(_chest: Node, rarity: String, value: int) -> void:
	if run_state == RunState.EXTRACTED:
		return

	if _add_run_item_to_backpack(rarity, value):
		_hud.show_message("Opened chest and packed %s treasure worth %d." % [rarity, value])
	_update_status()


func _on_monster_detected_player(_monster: Node, reason: String) -> void:
	var music_mgr: Node = _music_manager()
	if music_mgr != null:
		music_mgr.play_monster_discovered()

	if reason == "collision":
		handle_player_caught(reason)
	else:
		handle_player_discovered(reason)


func _on_anchor_player_entered(new_active_anchor: Node) -> void:
	player_on_anchor = true
	active_anchor = new_active_anchor
	if run_state != RunState.EXTRACTED:
		run_state = RunState.ANCHOR_PROMPT
		_hud.show_anchor_prompt(carried_value)
		_hud.show_message("Anchor ready. Choose extraction or keep searching.")
		_update_status()


func _on_anchor_player_exited() -> void:
	player_on_anchor = false
	active_anchor = null
	if run_state == RunState.ANCHOR_PROMPT:
		run_state = RunState.SEARCHING
		_hud.hide_anchor_prompt()
		_hud.show_message("Left anchor range.")
		_update_status()


func _set_gameplay_enabled(enabled: bool) -> void:
	if player != null:
		player.control_enabled = enabled
	for monster in monsters:
		monster.set_active(enabled)


func open_pause_menu() -> void:
	if run_state == RunState.EXTRACTED or run_state == RunState.CAUGHT:
		return
	get_tree().paused = true
	_set_gameplay_enabled(false)
	_pause_menu.open_panel()


func resume_from_pause() -> void:
	_leave_pause_mode()
	_set_gameplay_enabled(true)


func show_pause_settings() -> void:
	_pause_menu.show_settings_message()


func exit_to_main_menu() -> void:
	_stop_bubble()
	_leave_pause_mode()
	get_tree().change_scene_to_file(LobbyScenePath)


func toggle_backpack_ui() -> void:
	_storage_ui.set_backpack_only(true)
	_storage_ui.toggle_panel()


func toggle_minimap_ui() -> void:
	_refresh_minimap_ui()
	_minimap_ui.toggle_panel()


func _add_run_item_to_backpack(rarity: String, value: int) -> bool:
	var result: Dictionary = _inventory().add_to_storage(STORAGE_BACKPACK, rarity, 1)
	if int(result["total_count"]) <= 0:
		_hud.show_message("Backpack is full. The recovered item could not be stored.")
		return false

	carried_counts[rarity] += 1
	carried_value += value
	_refresh_backpack_ui()
	return true


func _refresh_backpack_ui() -> void:
	if _storage_ui != null and _storage_ui.has_method("refresh"):
		_storage_ui.refresh()


func _return_backpack_cursor_stack() -> bool:
	if _storage_ui == null or not _storage_ui.has_method("return_cursor_stack_to_storage"):
		return true
	return _storage_ui.return_cursor_stack_to_storage()


func _on_storage_changed(message: String) -> void:
	_hud.show_message(message)
	_update_status()


func _on_progress_changed() -> void:
	unlocked_region_count = _progress_unlocked_region_count()
	locked_region_rects = RunLayout.locked_region_rects_for_unlocked_count(unlocked_region_count)
	soft_boundary_x = RunLayout.soft_boundary_x_for_unlocked_count(unlocked_region_count)
	_refresh_region_access()
	_refresh_minimap_ui()
	_update_status()


func _refresh_region_access() -> void:
	_rebuild_locked_region_fog()
	if player == null:
		return
	if soft_boundary_x >= 0.0 and player.has_method("configure_soft_left_boundary"):
		player.configure_soft_left_boundary(soft_boundary_x, soft_boundary_margin)
	elif player.has_method("clear_soft_left_boundary"):
		player.clear_soft_left_boundary()
	_refresh_minimap_ui()


func _refresh_minimap_ui() -> void:
	if _minimap_ui == null:
		return
	_minimap_ui.configure(world_rect, regions)
	_minimap_ui.set_run_state(unlocked_region_count, anchors, spawn_anchor_id, player)
	_minimap_ui.refresh()


func _rebuild_locked_region_fog() -> void:
	for child in _fog_container.get_children():
		child.free()

	for index in range(locked_region_rects.size()):
		_add_locked_region_fog(index, locked_region_rects[index])


func _add_locked_region_fog(index: int, rect: Rect2) -> void:
	var fog := Polygon2D.new()
	fog.name = "LockedFog_%02d" % index
	fog.color = Color(0.0, 0.045, 0.075, 0.78)
	fog.polygon = PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	_fog_container.add_child(fog)

	var boundary := Polygon2D.new()
	boundary.name = "ElasticBoundary_%02d" % index
	boundary.color = Color(0.82, 0.08, 0.12, 0.26)
	var strip_width := 52.0
	boundary.polygon = PackedVector2Array([
		Vector2(rect.end.x - strip_width, rect.position.y),
		Vector2(rect.end.x + strip_width, rect.position.y),
		Vector2(rect.end.x + strip_width, rect.end.y),
		Vector2(rect.end.x - strip_width, rect.end.y),
	])
	_fog_container.add_child(boundary)


func _find_overlapping_anchor() -> Node:
	for candidate in anchors:
		if not _is_anchor_available(candidate):
			continue
		if candidate.has_method("contains_body") and candidate.contains_body(player):
			return candidate
	return null


func _is_anchor_available(candidate: Node) -> bool:
	if candidate == null:
		return false
	var region_id := int(candidate.get_meta("region_id", 1))
	return region_id <= unlocked_region_count


func _progress_unlocked_region_count() -> int:
	var progress = _progress()
	if progress == null:
		return 1
	return progress.get_unlocked_region_count()


func _handle_key_input() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _update_status() -> void:
	var state_text := "Searching"
	if run_state == RunState.ANCHOR_PROMPT:
		state_text = "At anchor"
	elif run_state == RunState.EXTRACTED:
		state_text = "Extracted"
	elif run_state == RunState.CAUGHT:
		state_text = "Caught"

	_hud.update_status(state_text, carried_value, carried_counts, warehouse_value, treasures_remaining)


func _inventory():
	return get_node("/root/PlayerInventory")


func _update_draw_order() -> void:
	# Use vertical position to determine draw order: larger y => draw on top
	if player == null:
		return
	# Set player z_index based on its y
	if player is CanvasItem:
		player.z_index = _draw_order_for_y(player.position.y)
	# Update cover items (seaweed, coral, solid_cover)
	for item in _cover_container.get_children():
		if item is CanvasItem:
			item.z_index = _draw_order_for_y(item.position.y)
	# Update pickups so treasures/chests interact visually too
	for item in _pickup_container.get_children():
		if item is CanvasItem:
			item.z_index = _draw_order_for_y(item.position.y)


func _draw_order_for_y(y_position: float) -> int:
	return clampi(int(roundf(y_position * DRAW_ORDER_SCALE)), -4096, 4096)


func _leave_pause_mode() -> void:
	get_tree().paused = false
	if _pause_menu != null:
		_pause_menu.close_panel()


func _music_manager():
	return get_node_or_null("/root/MusicManager")


func _stop_bubble() -> void:
	var mgr: Node = _music_manager()
	if mgr != null:
		mgr.stop_bubble()


func _transition_to_fail() -> void:
	var viewport_size := get_viewport().get_visible_rect().size

	var overlay := ColorRect.new()
	overlay.color = Color.BLACK
	overlay.modulate = Color.TRANSPARENT
	overlay.size = viewport_size
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var canvas := CanvasLayer.new()
	canvas.layer = 128
	canvas.add_child(overlay)
	add_child(canvas)

	var tween := create_tween()
	tween.tween_property(overlay, "modulate", Color.BLACK, 0.5)
	await tween.finished

	get_tree().change_scene_to_file(FailScenePath)


func _progress():
	return get_node_or_null("/root/ProgressState")
