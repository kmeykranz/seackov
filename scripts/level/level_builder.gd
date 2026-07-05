extends Node

const CollisionLayers := preload("res://scripts/support/collision_layers.gd")
const SolidCoverScene := preload("res://scenes/props/solid_cover.tscn")
const SeaweedCoverScene := preload("res://scenes/props/seaweed_cover.tscn")
const CoralCoverScene := preload("res://scenes/props/coral.tscn")
const PlayerScene := preload("res://scenes/actors/player_diver.tscn")
const MonsterScenePaths := {
	"octopus": "res://scenes/actors/monster_patrol.tscn",
	"shark": "res://scenes/actors/monster_shark.tscn",
	"fish": "res://scenes/actors/monster_fish.tscn",
}
const TreasureScene := preload("res://scenes/pickups/treasure_pickup.tscn")
const AnchorScene := preload("res://scenes/props/anchor_exit.tscn")
const ChestScenePath := "res://scenes/props/chest_box.tscn"
const WALL_THICKNESS := 52.0
const WALL_SEGMENT_LENGTH := 420.0
const WALL_SEGMENT_GAP := 24.0

var _rng := RandomNumberGenerator.new()


func build(containers: Dictionary, layout: Dictionary) -> Dictionary:
	_rng.randomize()
	var world_rect: Rect2 = layout["world_rect"]
	var unlocked_region_count := int(layout.get("unlocked_region_count", 1))
	var spawn_anchor_spec := _select_spawn_anchor(layout["anchors"], unlocked_region_count)

	_spawn_boundaries(containers["cover"], world_rect)
	_spawn_solid_cover(containers["cover"], layout["solid_cover"])
	_spawn_seaweed(containers["cover"], layout["seaweed"])
	_spawn_coral(containers["cover"], layout["coral"])
	var chests := _spawn_chests(containers["cover"], layout["chests"])

	var player := _spawn_player(containers["actors"], spawn_anchor_spec["position"], world_rect)
	var anchors := _spawn_anchors(containers["exits"], layout["anchors"], spawn_anchor_spec["id"])
	var treasures := _spawn_treasures(containers["pickups"], layout["treasures"])
	var monsters := _spawn_monsters(containers["actors"], layout["monsters"], player)

	return {
		"player": player,
		"anchor": anchors[0] if not anchors.is_empty() else null,
		"anchors": anchors,
		"spawn_anchor_id": spawn_anchor_spec["id"],
		"spawn_anchor_position": spawn_anchor_spec["position"],
		"chests": chests,
		"treasures": treasures,
		"monsters": monsters,
		"world_rect": world_rect,
		"regions": layout["regions"],
		"locked_region_rects": layout["locked_region_rects"],
		"soft_boundary_x": layout["soft_boundary_x"],
		"soft_boundary_margin": layout["soft_boundary_margin"],
		"unlocked_region_count": unlocked_region_count,
	}


func _spawn_boundaries(parent: Node, world_rect: Rect2) -> void:
	var left := world_rect.position.x
	var top := world_rect.position.y
	var right := world_rect.position.x + world_rect.size.x
	var bottom := world_rect.position.y + world_rect.size.y
	var specs := []
	_append_horizontal_wall_segments(specs, "North Wall", left, right, top - WALL_THICKNESS * 0.5)
	_append_horizontal_wall_segments(specs, "South Wall", left, right, bottom + WALL_THICKNESS * 0.5)
	_append_vertical_wall_segments(specs, "West Wall", top, bottom, left - WALL_THICKNESS * 0.5)
	_append_vertical_wall_segments(specs, "East Wall", top, bottom, right + WALL_THICKNESS * 0.5)
	_spawn_solid_cover(parent, specs)


func _append_horizontal_wall_segments(specs: Array, label: String, left: float, right: float, y_position: float) -> void:
	var cursor := left
	var index := 0
	while cursor < right:
		var length := minf(WALL_SEGMENT_LENGTH, right - cursor)
		specs.append({
			"name": "%s %02d" % [label, index],
			"position": Vector2(cursor + length * 0.5, y_position),
			"size": Vector2(length, WALL_THICKNESS),
			"kind": "wall",
			"boundary_segment": true,
		})
		cursor += WALL_SEGMENT_LENGTH + WALL_SEGMENT_GAP
		index += 1


func _append_vertical_wall_segments(specs: Array, label: String, top: float, bottom: float, x_position: float) -> void:
	var cursor := top
	var index := 0
	while cursor < bottom:
		var length := minf(WALL_SEGMENT_LENGTH, bottom - cursor)
		specs.append({
			"name": "%s %02d" % [label, index],
			"position": Vector2(x_position, cursor + length * 0.5),
			"size": Vector2(WALL_THICKNESS, length),
			"kind": "wall",
			"boundary_segment": true,
		})
		cursor += WALL_SEGMENT_LENGTH + WALL_SEGMENT_GAP
		index += 1


func _spawn_solid_cover(parent: Node, specs: Array) -> void:
	for spec in specs:
		var cover := SolidCoverScene.instantiate()
		cover.name = _node_name(spec["name"])
		cover.position = spec["position"]
		cover.set_meta("region_id", int(spec.get("region_id", 1)))
		cover.set_meta("boundary_segment", bool(spec.get("boundary_segment", false)))
		cover.set_meta("cover_kind", spec.get("kind", "reef"))
		cover.collision_layer = CollisionLayers.WALL
		cover.collision_mask = CollisionLayers.PLAYER | CollisionLayers.MONSTER
		parent.add_child(cover)
		cover.configure(spec["size"], spec.get("kind", "reef"), spec["name"])


func _spawn_seaweed(parent: Node, specs: Array) -> void:
	for spec in specs:
		var cover := SeaweedCoverScene.instantiate()
		cover.name = _node_name(spec["name"])
		cover.position = spec["position"]
		cover.set_meta("region_id", int(spec.get("region_id", 1)))
		cover.set_meta("cover_kind", "seaweed")
		cover.collision_layer = CollisionLayers.COVER
		cover.collision_mask = CollisionLayers.PLAYER
		parent.add_child(cover)
		cover.configure(spec["size"], spec["name"])


func _spawn_coral(parent: Node, specs: Array) -> void:
	for spec in specs:
		var cover := CoralCoverScene.instantiate()
		cover.name = _node_name(spec["name"])
		cover.position = spec["position"]
		cover.set_meta("region_id", int(spec.get("region_id", 1)))
		cover.set_meta("cover_kind", "coral")
		cover.collision_layer = CollisionLayers.WALL
		cover.collision_mask = CollisionLayers.PLAYER | CollisionLayers.MONSTER
		parent.add_child(cover)
		cover.configure(spec["size"], spec["name"])


func _spawn_player(parent: Node, spawn_position: Vector2, world_rect: Rect2) -> Node:
	var player := PlayerScene.instantiate()
	player.name = "Player"
	player.position = spawn_position
	player.collision_layer = CollisionLayers.PLAYER
	player.collision_mask = CollisionLayers.WALL
	parent.add_child(player)
	player.configure_camera(world_rect)
	player.configure_soft_world_bounds(world_rect)
	return player


func _spawn_anchors(parent: Node, specs: Array, spawn_anchor_id: String) -> Array:
	var anchors := []
	for spec in specs:
		if String(spec["id"]) == spawn_anchor_id:
			continue
		var anchor := AnchorScene.instantiate()
		anchor.name = "AnchorExit" if anchors.is_empty() else "AnchorExit_%s" % spec["id"]
		anchor.position = spec["position"]
		anchor.modulate = Color(1.0, 0.42, 0.45, 1.0)
		anchor.collision_layer = CollisionLayers.EXIT
		anchor.collision_mask = CollisionLayers.PLAYER
		anchor.set_meta("anchor_id", spec["id"])
		anchor.set_meta("region_id", int(spec.get("region_id", 1)))
		parent.add_child(anchor)
		anchors.append(anchor)
	return anchors


func _spawn_chests(parent: Node, specs: Array) -> Array:
	var chest_scene: PackedScene = load(ChestScenePath)
	var chests := []
	for index in range(specs.size()):
		var spec: Dictionary = specs[index]
		var chest: Area2D = chest_scene.instantiate()
		chest.name = "TreasureChest_%02d" % index
		chest.position = spec["position"]
		chest.set_meta("region_id", int(spec.get("region_id", 1)))
		chest.collision_layer = 0
		chest.collision_mask = CollisionLayers.PLAYER
		parent.add_child(chest)
		chests.append(chest)
	return chests


func _spawn_treasures(parent: Node, specs: Array) -> Array:
	var treasures := []
	for index in range(specs.size()):
		var spec: Dictionary = specs[index]
		var treasure := TreasureScene.instantiate()
		treasure.name = "Treasure_%s_%02d" % [spec["rarity"], index]
		treasure.position = spec["position"]
		treasure.set_meta("region_id", int(spec.get("region_id", 1)))
		treasure.collision_layer = CollisionLayers.TREASURE
		treasure.collision_mask = CollisionLayers.PLAYER
		parent.add_child(treasure)
		treasure.configure(spec["rarity"])
		treasures.append(treasure)
	return treasures


func _spawn_monsters(parent: Node, specs: Array, player: Node2D) -> Array:
	var monsters := []
	for spec in specs:
		var kind := String(spec.get("kind", "octopus"))
		var monster_scene_path := String(MonsterScenePaths.get(kind, MonsterScenePaths["octopus"]))
		var monster_scene := load(monster_scene_path) as PackedScene
		if monster_scene == null:
			monster_scene = load(String(MonsterScenePaths["octopus"])) as PackedScene
		var monster := monster_scene.instantiate()
		monster.name = _node_name(spec["name"])
		monster.monster_label = String(spec.get("display_name", "巡逻"))
		monster.patrol_speed = float(spec.get("patrol_speed", monster.patrol_speed))
		monster.set_meta("region_id", int(spec.get("region_id", 1)))
		monster.set_meta("monster_kind", kind)
		parent.add_child(monster)
		monster.configure(spec["points"], player, CollisionLayers.WALL)
		monster.configure_collision(CollisionLayers.MONSTER, CollisionLayers.WALL, CollisionLayers.PLAYER)
		monsters.append(monster)
	return monsters


func _select_spawn_anchor(specs: Array, unlocked_region_count: int) -> Dictionary:
	var candidates := []
	for spec in specs:
		if int(spec.get("region_id", 1)) <= unlocked_region_count:
			candidates.append(spec)
	if candidates.is_empty() and not specs.is_empty():
		candidates.append(specs[0])
	if candidates.is_empty():
		return {"id": "fallback", "region_id": 1, "position": Vector2.ZERO}

	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _node_name(label: String) -> String:
	return label.replace(" ", "")
