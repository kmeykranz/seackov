extends Node

const CollisionLayers := preload("res://scripts/support/collision_layers.gd")
const SolidCoverScene := preload("res://scenes/props/solid_cover.tscn")
const SeaweedCoverScene := preload("res://scenes/props/seaweed_cover.tscn")
const PlayerScene := preload("res://scenes/actors/player_diver.tscn")
const MonsterScene := preload("res://scenes/actors/monster_patrol.tscn")
const TreasureScene := preload("res://scenes/pickups/treasure_pickup.tscn")
const AnchorScene := preload("res://scenes/props/anchor_exit.tscn")
const ChestScenePath := "res://scenes/props/chest_box.tscn"


func build(containers: Dictionary, layout: Dictionary) -> Dictionary:
	var world_rect: Rect2 = layout["world_rect"]
	_spawn_boundaries(containers["cover"], world_rect)
	_spawn_solid_cover(containers["cover"], layout["solid_cover"])
	_spawn_seaweed(containers["cover"], layout["seaweed"])
	var chests := _spawn_chests(containers["cover"], layout["chests"])

	var player := _spawn_player(containers["actors"], layout["player_spawn"], world_rect)
	var anchor := _spawn_anchor(containers["exits"], layout["anchor_spawn"])
	var treasures := _spawn_treasures(containers["pickups"], layout["treasures"])
	var monsters := _spawn_monsters(containers["actors"], layout["monsters"], player)

	return {
		"player": player,
		"anchor": anchor,
		"chests": chests,
		"treasures": treasures,
		"monsters": monsters,
		"world_rect": world_rect,
	}


func _spawn_boundaries(parent: Node, world_rect: Rect2) -> void:
	var thickness := 52.0
	var specs := [
		{"name": "North Wall", "position": Vector2(world_rect.size.x * 0.5, -thickness * 0.5), "size": Vector2(world_rect.size.x, thickness), "kind": "wall"},
		{"name": "South Wall", "position": Vector2(world_rect.size.x * 0.5, world_rect.size.y + thickness * 0.5), "size": Vector2(world_rect.size.x, thickness), "kind": "wall"},
		{"name": "West Wall", "position": Vector2(-thickness * 0.5, world_rect.size.y * 0.5), "size": Vector2(thickness, world_rect.size.y), "kind": "wall"},
		{"name": "East Wall", "position": Vector2(world_rect.size.x + thickness * 0.5, world_rect.size.y * 0.5), "size": Vector2(thickness, world_rect.size.y), "kind": "wall"},
	]
	_spawn_solid_cover(parent, specs)


func _spawn_solid_cover(parent: Node, specs: Array) -> void:
	for spec in specs:
		var cover := SolidCoverScene.instantiate()
		cover.name = _node_name(spec["name"])
		cover.position = spec["position"]
		cover.collision_layer = CollisionLayers.WALL
		cover.collision_mask = CollisionLayers.PLAYER | CollisionLayers.MONSTER
		parent.add_child(cover)
		cover.configure(spec["size"], spec.get("kind", "reef"), spec["name"])


func _spawn_seaweed(parent: Node, specs: Array) -> void:
	for spec in specs:
		var cover := SeaweedCoverScene.instantiate()
		cover.name = _node_name(spec["name"])
		cover.position = spec["position"]
		cover.collision_layer = CollisionLayers.COVER
		cover.collision_mask = CollisionLayers.PLAYER
		parent.add_child(cover)
		cover.configure(spec["size"], spec["name"])


func _spawn_player(parent: Node, spawn_position: Vector2, world_rect: Rect2) -> Node:
	var player := PlayerScene.instantiate()
	player.name = "Player"
	player.position = spawn_position
	player.collision_layer = CollisionLayers.PLAYER
	player.collision_mask = CollisionLayers.WALL | CollisionLayers.MONSTER
	parent.add_child(player)
	player.configure_camera(world_rect)
	return player


func _spawn_anchor(parent: Node, spawn_position: Vector2) -> Node:
	var anchor := AnchorScene.instantiate()
	anchor.name = "AnchorExit"
	anchor.position = spawn_position
	anchor.collision_layer = CollisionLayers.EXIT
	anchor.collision_mask = CollisionLayers.PLAYER
	parent.add_child(anchor)
	return anchor


func _spawn_chests(parent: Node, specs: Array) -> Array:
	var chest_scene: PackedScene = load(ChestScenePath)
	var chests := []
	for index in range(specs.size()):
		var spec: Dictionary = specs[index]
		var chest: Area2D = chest_scene.instantiate()
		chest.name = "TreasureChest_%02d" % index
		chest.position = spec["position"]
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
		treasure.collision_layer = CollisionLayers.TREASURE
		treasure.collision_mask = CollisionLayers.PLAYER
		parent.add_child(treasure)
		treasure.configure(spec["rarity"])
		treasures.append(treasure)
	return treasures


func _spawn_monsters(parent: Node, specs: Array, player: Node2D) -> Array:
	var monsters := []
	for spec in specs:
		var monster := MonsterScene.instantiate()
		monster.name = _node_name(spec["name"])
		parent.add_child(monster)
		monster.configure(spec["points"], player, CollisionLayers.WALL)
		monster.configure_collision(CollisionLayers.MONSTER, CollisionLayers.WALL | CollisionLayers.PLAYER, CollisionLayers.PLAYER)
		monsters.append(monster)
	return monsters


func _node_name(label: String) -> String:
	return label.replace(" ", "")
