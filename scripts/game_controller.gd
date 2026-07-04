extends Node2D
class_name RunSceneController

const CollisionLayers := preload("res://scripts/support/collision_layers.gd")
const RunLayout := preload("res://scripts/level/run_layout.gd")
const LevelBuilderScript := preload("res://scripts/level/level_builder.gd")

const PLAYER_LAYER: int = CollisionLayers.PLAYER
const WALL_LAYER: int = CollisionLayers.WALL
const MONSTER_LAYER: int = CollisionLayers.MONSTER
const TREASURE_LAYER: int = CollisionLayers.TREASURE
const EXIT_LAYER: int = CollisionLayers.EXIT
const COVER_LAYER: int = CollisionLayers.COVER

enum RunState { SEARCHING, ANCHOR_PROMPT, EXTRACTED }

var run_state: RunState = RunState.SEARCHING
var world_rect: Rect2

var player: Node
var anchor: Node
var chests: Array = []
var world: Node2D
var treasures_container: Node2D
var monsters_container: Node2D
var monsters: Array = []

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
@onready var _hud: CanvasLayer = $RunHud


func _ready() -> void:
	world = $World
	treasures_container = _pickup_container
	monsters_container = _actor_container
	_build_level()
	_wire_ui()
	_update_status()
	_hud.show_message("Collect treasure, hide in seaweed, use cover, extract at the anchor.")


func _physics_process(_delta: float) -> void:
	if anchor == null or player == null or run_state == RunState.EXTRACTED:
		return

	var overlaps_anchor := false
	if anchor.has_method("contains_body"):
		overlaps_anchor = anchor.contains_body(player)
	if overlaps_anchor and not player_on_anchor:
		_on_anchor_player_entered()
	elif not overlaps_anchor and player_on_anchor:
		_on_anchor_player_exited()


func choose_extract() -> void:
	if run_state != RunState.ANCHOR_PROMPT or not player_on_anchor:
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


func choose_continue() -> void:
	if run_state != RunState.ANCHOR_PROMPT:
		return

	run_state = RunState.SEARCHING
	_hud.hide_anchor_prompt()
	_hud.show_message("Extraction skipped. Keep searching.")
	_update_status()


func handle_player_discovered(reason: String) -> void:
	if run_state == RunState.EXTRACTED:
		return

	var lost_value := carried_value
	for rarity in carried_counts.keys():
		carried_counts[rarity] = 0
	carried_value = 0

	if lost_value > 0:
		_hud.show_message("Detected by %s. Carried treasure lost: %d." % [reason, lost_value])
	else:
		_hud.show_message("Detected by %s, but no carried treasure was lost." % reason)
	_update_status()


func is_anchor_prompt_visible() -> bool:
	return _hud.is_anchor_prompt_visible()


func _build_level() -> void:
	var builder := LevelBuilderScript.new()
	add_child(builder)
	var result := builder.build(_containers(), RunLayout.build())

	player = result["player"]
	anchor = result["anchor"]
	chests = result["chests"]
	monsters = result["monsters"]
	world_rect = result["world_rect"]
	treasures_remaining = result["treasures"].size()

	for chest in chests:
		chest.opened.connect(_on_chest_opened)
	for treasure in result["treasures"]:
		treasure.collected.connect(_on_treasure_collected)
	for monster in monsters:
		monster.player_detected.connect(_on_monster_detected_player)
	anchor.player_entered.connect(_on_anchor_player_entered)
	anchor.player_exited.connect(_on_anchor_player_exited)


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


func _on_treasure_collected(treasure: Node) -> void:
	if run_state == RunState.EXTRACTED:
		return

	carried_counts[treasure.rarity] += 1
	carried_value += treasure.value
	treasures_remaining = maxi(0, treasures_remaining - 1)
	_hud.show_message("Collected %s treasure worth %d." % [treasure.rarity, treasure.value])
	_update_status()


func _on_chest_opened(_chest: Node, rarity: String, value: int) -> void:
	if run_state == RunState.EXTRACTED:
		return

	carried_counts[rarity] += 1
	carried_value += value
	_hud.show_message("Opened chest and found %s treasure worth %d." % [rarity, value])
	_update_status()


func _on_monster_detected_player(_monster: Node, reason: String) -> void:
	handle_player_discovered(reason)


func _on_anchor_player_entered() -> void:
	player_on_anchor = true
	if run_state != RunState.EXTRACTED:
		run_state = RunState.ANCHOR_PROMPT
		_hud.show_anchor_prompt(carried_value)
		_hud.show_message("Anchor ready. Choose extraction or keep searching.")
		_update_status()


func _on_anchor_player_exited() -> void:
	player_on_anchor = false
	if run_state == RunState.ANCHOR_PROMPT:
		run_state = RunState.SEARCHING
		_hud.hide_anchor_prompt()
		_hud.show_message("Left anchor range.")
		_update_status()


func _set_gameplay_enabled(enabled: bool) -> void:
	player.control_enabled = enabled
	for monster in monsters:
		monster.set_active(enabled)


func _update_status() -> void:
	var state_text := "Searching"
	if run_state == RunState.ANCHOR_PROMPT:
		state_text = "At anchor"
	elif run_state == RunState.EXTRACTED:
		state_text = "Extracted"

	_hud.update_status(state_text, carried_value, carried_counts, warehouse_value, treasures_remaining)
