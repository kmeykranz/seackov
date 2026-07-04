extends Control

var world_rect: Rect2
var regions: Array = []
var unlocked_region_count: int = 1
var anchors: Array = []
var spawn_anchor_id: String = ""
var player: Node2D


func configure(new_world_rect: Rect2, new_regions: Array) -> void:
	world_rect = new_world_rect
	regions = new_regions
	queue_redraw()


func set_run_state(new_unlocked_region_count: int, new_anchors: Array, new_spawn_anchor_id: String, new_player: Node2D) -> void:
	unlocked_region_count = new_unlocked_region_count
	anchors = new_anchors
	spawn_anchor_id = new_spawn_anchor_id
	player = new_player
	queue_redraw()


func get_visible_region_count() -> int:
	var count := 0
	for region in regions:
		if int(region.get("id", 0)) <= unlocked_region_count:
			count += 1
	return count


func _draw() -> void:
	var unlocked_bounds := _unlocked_bounds()
	if unlocked_bounds.size.x <= 0.0 or unlocked_bounds.size.y <= 0.0:
		return

	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.04, 0.055, 0.96), true)
	for region in regions:
		if int(region.get("id", 0)) > unlocked_region_count:
			continue
		var rect := Rect2(
			Vector2(float(region["x_min"]), world_rect.position.y),
			Vector2(float(region["x_max"]) - float(region["x_min"]), world_rect.size.y)
		)
		var map_rect := _to_map_rect(rect, unlocked_bounds)
		draw_rect(map_rect, Color(0.06, 0.22, 0.28, 0.72), true)
		draw_rect(map_rect, Color(0.32, 0.75, 0.82, 0.9), false, 2.0)

	for anchor in anchors:
		if int(anchor.get_meta("region_id", 1)) > unlocked_region_count:
			continue
		if String(anchor.get_meta("anchor_id", "")) == spawn_anchor_id:
			continue
		var anchor_pos := _world_to_map(anchor.global_position, unlocked_bounds)
		draw_circle(anchor_pos, 5.0, Color(1.0, 0.22, 0.24, 0.95))

	if player != null:
		draw_circle(_world_to_map(player.global_position, unlocked_bounds), 6.0, Color(1.0, 0.9, 0.24, 1.0))


func _unlocked_bounds() -> Rect2:
	var has_region := false
	var min_x := INF
	var max_x := -INF
	for region in regions:
		if int(region.get("id", 0)) > unlocked_region_count:
			continue
		has_region = true
		min_x = minf(min_x, float(region["x_min"]))
		max_x = maxf(max_x, float(region["x_max"]))

	if not has_region:
		return Rect2()
	return Rect2(Vector2(min_x, world_rect.position.y), Vector2(max_x - min_x, world_rect.size.y))


func _to_map_rect(rect: Rect2, bounds: Rect2) -> Rect2:
	var top_left := _world_to_map(rect.position, bounds)
	var bottom_right := _world_to_map(rect.end, bounds)
	return Rect2(top_left, bottom_right - top_left)


func _world_to_map(world_position: Vector2, bounds: Rect2) -> Vector2:
	var padding := 16.0
	var drawable := Vector2(maxf(1.0, size.x - padding * 2.0), maxf(1.0, size.y - padding * 2.0))
	var normalized := Vector2(
		(world_position.x - bounds.position.x) / bounds.size.x,
		(world_position.y - bounds.position.y) / bounds.size.y
	)
	return Vector2(padding, padding) + normalized * drawable
