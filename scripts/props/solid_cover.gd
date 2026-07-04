extends StaticBody2D

const COLORS := {
	"reef": Color(0.23, 0.55, 0.46, 0.9),
	"wreck": Color(0.48, 0.39, 0.30, 0.9),
	"wall": Color(0.07, 0.28, 0.34, 0.95),
}

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var visual: ColorRect = $ColorRect


func configure(size: Vector2, kind: String, _display_name: String) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	visual.size = size
	visual.position = -size * 0.5
	visual.color = COLORS.get(kind, COLORS.reef)
	return
