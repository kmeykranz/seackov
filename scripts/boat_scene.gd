extends Node2D

const CollisionLayers := preload("res://scripts/support/collision_layers.gd")
const RunScenePath := "res://scenes/run_scene.tscn"

var _player_in_hatch_range: bool = false
var _transitioning: bool = false

@onready var _manhole: Area2D = $World/Manhole
@onready var _manhole_prompt: Label = $World/Manhole/PromptLabel


func _ready() -> void:
	set_process_unhandled_input(true)
	_manhole.body_entered.connect(_on_manhole_body_entered)
	_manhole.body_exited.connect(_on_manhole_body_exited)
	_refresh_manhole_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if _transitioning or not _player_in_hatch_range:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		_transitioning = true
		get_tree().change_scene_to_file(RunScenePath)
		# get_viewport().set_input_as_handled()


func _on_manhole_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_hatch_range = true
		_refresh_manhole_prompt()


func _on_manhole_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_hatch_range = false
		_refresh_manhole_prompt()


func _refresh_manhole_prompt() -> void:
	if _manhole_prompt == null:
		return
	_manhole_prompt.visible = _player_in_hatch_range and not _transitioning
