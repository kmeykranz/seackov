extends Area2D

const SEAWEED_TEXTURE_PATH := "res://assets/grass1.png"
const BASE_TEXTURE_SIZE := Vector2(800.0, 800.0)

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_load_sprite_texture()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


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


func _load_sprite_texture() -> void:
	if sprite == null:
		return
	if DisplayServer.get_name() == "headless":
		return
	var texture := load(SEAWEED_TEXTURE_PATH)
	if texture is Texture2D:
		sprite.texture = texture


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("enter_cover"):
		body.enter_cover()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("exit_cover"):
		body.exit_cover()
