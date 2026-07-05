extends Node2D
class_name RunSceneController

const CollisionLayers := preload("res://scripts/support/collision_layers.gd")
const RunLayout := preload("res://scripts/level/run_layout.gd")
const LevelBuilderScript := preload("res://scripts/level/level_builder.gd")
const RunToolSystemScript := preload("res://scripts/items/run_tool_system.gd")
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
const DEPTH_LIGHT_COLORS := {
	1: Color(0.96, 0.985, 1.0, 1.0),
	2: Color(0.55, 0.70, 0.86, 1.0),
	3: Color(0.20, 0.36, 0.55, 1.0),
	4: Color(0.0, 0.015, 0.045, 1.0),
}
const DEPTH_LIGHT_TRANSITION_WIDTH := 520.0

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
var _tool_system: Node

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
@onready var _effect_container: Node2D = $World/Effects
@onready var _hud: CanvasLayer = $RunHud
@onready var _storage_ui: CanvasLayer = $StorageTransferUi
@onready var _minimap_ui: CanvasLayer = $MiniMapUi
@onready var _pause_menu: CanvasLayer = $PauseMenuUi
@onready var _depth_light: CanvasModulate = $CanvasModulate


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	world = $World
	treasures_container = _pickup_container
	monsters_container = _actor_container
	_build_level()
	_wire_ui()
	_setup_tool_system()
	_update_depth_lighting()
	_update_status()

	var music_manager = _music_manager()
	if music_manager != null:
		music_manager.play_underwater()
		music_manager.play_underwater_level_music(unlocked_region_count)
		music_manager.play_bubble()
		music_manager.diving_from_boat = false

	_hud.show_message("收集宝物，躲进海草，利用掩体，在锚点返回。")


func _process(_delta: float) -> void:
	_update_depth_lighting()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or event.echo:
		return

	if run_state == RunState.EXTRACTED or run_state == RunState.CAUGHT:
		return

	if not get_tree().paused and _tool_system != null and _tool_system.handle_key_event(event):
		_handle_key_input()
		return

	if not event.pressed:
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

	if run_state == RunState.ANCHOR_PROMPT and event.keycode == KEY_F:
		_handle_key_input()
		choose_extract()
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
		_hud.show_message("返回前请先把手上的背包物品放回去。")
		return

	for rarity in warehouse_counts.keys():
		warehouse_counts[rarity] += carried_counts[rarity]
		carried_counts[rarity] = 0

	warehouse_value += carried_value
	carried_value = 0
	run_state = RunState.EXTRACTED

	var music_mgr: Node = _music_manager()
	if music_mgr != null:
		music_mgr.play_board_back()

	_set_gameplay_enabled(false)
	_hud.hide_anchor_prompt()
	_hud.show_end(warehouse_value)
	_hud.show_message("本轮结束。")
	_record_recovered_knowledge()
	_update_status()
	_leave_pause_mode()
	_stop_bubble()
	get_tree().change_scene_to_file(BoatScenePath)


func choose_continue() -> void:
	if run_state != RunState.ANCHOR_PROMPT:
		return

	run_state = RunState.SEARCHING
	_hud.hide_anchor_prompt()
	_hud.show_message("已跳过返回，继续搜索。")
	_update_status()


func handle_player_discovered(reason: String) -> void:
	if run_state == RunState.EXTRACTED or run_state == RunState.CAUGHT:
		return

	var reason_label := _detection_reason_label(reason)
	var lost_value := carried_value
	_return_backpack_cursor_stack()
	_inventory().remove_counts_from_storage(STORAGE_BACKPACK, carried_counts)
	for rarity in carried_counts.keys():
		carried_counts[rarity] = 0
	carried_value = 0
	_refresh_backpack_ui()

	if lost_value > 0:
		_hud.show_message("被%s发现，携带的宝物损失：%d。" % [reason_label, lost_value])
	else:
		_hud.show_message("被%s发现，但没有损失携带的宝物。" % reason_label)
	_update_status()


func handle_player_caught(reason: String) -> void:
	if run_state == RunState.EXTRACTED or run_state == RunState.CAUGHT:
		return
	if _tool_system != null and _tool_system.try_block_damage():
		return

	var reason_label := _detection_reason_label(reason)
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
	_hud.show_message("被%s抓到。背包已清空，正在返回船上。" % reason_label)
	_update_status()
	_refresh_backpack_ui()
	_stop_bubble()
	_leave_pause_mode()
	_transition_to_fail_page()


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


func get_depth_light_color_at_x(x_position: float) -> Color:
	if regions.is_empty():
		return _depth_light_color_for_region(1)

	var rightmost_max := world_rect.end.x
	var leftmost_min := world_rect.position.x
	for region in regions:
		rightmost_max = maxf(rightmost_max, float(region["x_max"]))
		leftmost_min = minf(leftmost_min, float(region["x_min"]))

	if x_position >= rightmost_max:
		return _depth_light_color_for_region(1)
	if x_position <= leftmost_min:
		return _depth_light_color_for_region(_deepest_region_id())

	var half_transition_width := DEPTH_LIGHT_TRANSITION_WIDTH * 0.5
	for index in range(regions.size() - 1):
		var shallow_region: Dictionary = regions[index]
		var deep_region: Dictionary = regions[index + 1]
		var boundary_x := float(shallow_region["x_min"])
		var transition_start := boundary_x + half_transition_width
		var transition_end := boundary_x - half_transition_width
		if x_position <= transition_start and x_position >= transition_end:
			var transition := clampf((transition_start - x_position) / DEPTH_LIGHT_TRANSITION_WIDTH, 0.0, 1.0)
			return _depth_light_color_for_region(int(shallow_region["id"])).lerp(_depth_light_color_for_region(int(deep_region["id"])), transition)

	for region in regions:
		var region_id := int(region["id"])
		var region_min := float(region["x_min"])
		var region_max := float(region["x_max"])
		if x_position < region_min or x_position > region_max:
			continue
		return _depth_light_color_for_region(region_id)

	return _depth_light_color_for_region(_deepest_region_id())


func get_current_depth_light_color() -> Color:
	return _depth_light.color if _depth_light != null else _depth_light_color_for_region(1)


func get_tool_system() -> Node:
	return _tool_system


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
		_hud.show_message("已收集%s，价值 %d，放入背包。" % [_inventory().get_rarity_label(treasure.rarity), treasure.value])
	_update_status()


func _on_chest_opened(_chest: Node, rarity: String, value: int) -> void:
	if run_state == RunState.EXTRACTED:
		return

	if _add_run_item_to_backpack(rarity, value):
		_hud.show_message("已打开宝箱，收入%s，价值 %d。" % [_inventory().get_rarity_label(rarity), value])
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
		_hud.show_message("锚点已就绪。按 F 返回船上并结算。")
		_update_status()


func _on_anchor_player_exited() -> void:
	player_on_anchor = false
	active_anchor = null
	if run_state == RunState.ANCHOR_PROMPT:
		run_state = RunState.SEARCHING
		_hud.hide_anchor_prompt()
		_hud.show_message("已离开锚点范围。")
		_update_status()


func _set_gameplay_enabled(enabled: bool) -> void:
	if not enabled and _tool_system != null:
		_tool_system.cancel_use()
	if player != null:
		player.control_enabled = enabled
	for monster in monsters:
		if not is_instance_valid(monster):
			continue
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
		_hud.show_message("背包已满，回收的物品无法存入。")
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


func _setup_tool_system() -> void:
	_tool_system = RunToolSystemScript.new()
	_tool_system.name = "RunToolSystem"
	add_child(_tool_system)
	_tool_system.message_requested.connect(_hud.show_message)
	_tool_system.configure(player, monsters, regions, _effect_container, _hud, _progress())


func _record_recovered_knowledge() -> void:
	if _tool_system == null:
		return
	var recovered: Array = _tool_system.flush_recovered_knowledge()
	if recovered.is_empty():
		return
	var progress = _progress()
	if progress == null or not progress.has_method("record_recovered_knowledge"):
		return
	var added: Array[String] = progress.record_recovered_knowledge(recovered)
	if not added.is_empty():
		_hud.show_message("已带回 %d 条新知识，回船后可在上传装置解析。" % added.size())


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
	var state_text := "搜索中"
	if run_state == RunState.ANCHOR_PROMPT:
		state_text = "锚点处"
	elif run_state == RunState.EXTRACTED:
		state_text = "已撤离"
	elif run_state == RunState.CAUGHT:
		state_text = "已被抓到"

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


func _update_depth_lighting() -> void:
	if _depth_light == null or player == null:
		return
	_depth_light.color = get_depth_light_color_at_x(player.global_position.x)


func _depth_light_color_for_region(region_id: int) -> Color:
	return DEPTH_LIGHT_COLORS.get(region_id, DEPTH_LIGHT_COLORS[1])


func _detection_reason_label(reason: String) -> String:
	if reason == "sight":
		return "怪物视线"
	if reason == "collision":
		return "怪物"
	return reason


func _deepest_region_id() -> int:
	var deepest_id := 1
	for region in regions:
		deepest_id = maxi(deepest_id, int(region["id"]))
	return deepest_id


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


func _transition_to_fail_page() -> void:
	get_tree().change_scene_to_file(FailScenePath)


func _progress():
	return get_node_or_null("/root/ProgressState")
