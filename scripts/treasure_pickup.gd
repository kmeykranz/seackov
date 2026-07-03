extends Area2D
class_name TreasurePickup

signal collected(treasure: Node)

const RARITY_VALUES := {
	"common": 25,
	"rare": 75,
	"legendary": 200,
}

const RARITY_COLORS := {
	"common": Color(1.0, 0.86, 0.22, 1.0),
	"rare": Color(0.22, 0.72, 1.0, 1.0),
	"legendary": Color(1.0, 0.30, 0.92, 1.0),
}

@export_enum("common", "rare", "legendary") var rarity: String = "common"

var value: int = RARITY_VALUES.common
var collected_flag: bool = false

@onready var gem: Polygon2D = $Gem
@onready var ring: Polygon2D = $Ring
@onready var label: Label = $ValueLabel


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_rarity()


func configure(new_rarity: String) -> void:
	rarity = new_rarity if RARITY_VALUES.has(new_rarity) else "common"
	value = RARITY_VALUES[rarity]
	if is_inside_tree():
		_apply_rarity()


func collect(_collector: Node = null) -> void:
	if collected_flag:
		return

	collected_flag = true
	monitoring = false
	visible = false
	collected.emit(self)
	queue_free()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		collect(body)


func _apply_rarity() -> void:
	value = RARITY_VALUES[rarity]
	var color: Color = RARITY_COLORS[rarity]
	gem.color = color
	ring.color = Color(color.r, color.g, color.b, 0.30)
	label.text = str(value)
