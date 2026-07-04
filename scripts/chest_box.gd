extends Area2D
class_name TreasureChest

signal opened(chest: Node, rarity: String, value: int)

const LOOT_TABLE := [
	{"rarity": "common", "value": 25, "weight": 70},
	{"rarity": "rare", "value": 75, "weight": 25},
	{"rarity": "legendary", "value": 200, "weight": 5},
]

var _player_in_range: bool = false
var _opened: bool = false
var _rng := RandomNumberGenerator.new()

@onready var _base: Polygon2D = $Base
@onready var _lid: Polygon2D = $Lid
@onready var _prompt_label: Label = $PromptLabel


func _ready() -> void:
	_rng.randomize()
	set_process_unhandled_input(true)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_refresh_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if _opened or not _player_in_range:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		_open()
		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node) -> void:
	if _opened or not body.is_in_group("player"):
		return
	_player_in_range = true
	_refresh_prompt()


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_range = false
	_refresh_prompt()


func _open() -> void:
	if _opened:
		return

	_opened = true
	monitoring = false
	collision_mask = 0
	_player_in_range = false

	var reward := _pick_reward()
	_base.modulate = Color(0.82, 0.72, 0.36, 1.0)
	_lid.modulate = Color(0.68, 0.58, 0.22, 1.0)
	_prompt_label.text = "已开启"
	_refresh_prompt()
	opened.emit(self, reward["rarity"], reward["value"])


func _pick_reward() -> Dictionary:
	var total_weight := 0
	for entry in LOOT_TABLE:
		total_weight += entry["weight"]

	var roll := _rng.randi_range(1, total_weight)
	var accumulated := 0
	for entry in LOOT_TABLE:
		accumulated += entry["weight"]
		if roll <= accumulated:
			return entry

	return LOOT_TABLE[0]


func _refresh_prompt() -> void:
	if _prompt_label == null:
		return
	_prompt_label.visible = _player_in_range and not _opened
	if _prompt_label.visible:
		_prompt_label.text = "F 拾取"