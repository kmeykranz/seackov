extends StaticBody2D

const COLORS := {
	"reef": Color(0.23, 0.55, 0.46, 1.0),
	"wreck": Color(0.48, 0.39, 0.30, 1.0),
	"wall": Color(0.10, 0.38, 0.43, 1.0),
}

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var visual: ColorRect = $Visual
@onready var label: Label = $Label


func configure(size: Vector2, kind: String, display_name: String) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape

	visual.size = size
	visual.position = -size * 0.5
	visual.color = COLORS.get(kind, COLORS.reef)
	visual.visible = kind != "wall"

	label.text = display_name
	label.position = Vector2(-size.x * 0.5 + 10.0, -10.0)
	label.visible = kind != "wall"
