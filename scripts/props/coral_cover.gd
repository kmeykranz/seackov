extends StaticBody2D

const BASE_TEXTURE_SIZE := Vector2(900.0, 900.0)

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D


func configure(size: Vector2, _display_name: String) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.position = Vector2.ZERO
	sprite.scale = Vector2(
		maxf(0.05, size.x / BASE_TEXTURE_SIZE.x),
		maxf(0.05, size.y / BASE_TEXTURE_SIZE.y)
	)
	sprite.position = Vector2.ZERO
