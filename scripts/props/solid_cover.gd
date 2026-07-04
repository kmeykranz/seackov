extends StaticBody2D


@onready var collision: CollisionShape2D = $CollisionShape2D


func configure(size: Vector2, kind: String, display_name: String) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	return
