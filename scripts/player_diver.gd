extends CharacterBody2D
class_name PlayerDiver

@export var speed: float = 260.0

var control_enabled: bool = true
var facing: Vector2 = Vector2.RIGHT
var cover_depth: int = 0

@onready var body_pivot: Node2D = $BodyPivot
@onready var body_sprite: AnimatedSprite2D = $BodyPivot/AnimatedSprite2D
@onready var hidden_ring: Polygon2D = $HiddenRing
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group("player")
	_update_movement_visuals(Vector2.ZERO)
	_update_hidden_visual()


func configure_camera(bounds: Rect2) -> void:
	#camera.limit_left = int(bounds.position.x)
	#camera.limit_top = int(bounds.position.y)
	#camera.limit_right = int(bounds.end.x)
	#camera.limit_bottom = int(bounds.end.y)
	camera.zoom = Vector2(1.2, 1.2)
	camera.make_current()


func _physics_process(_delta: float) -> void:
	if not control_enabled:
		velocity = Vector2.ZERO
		_update_movement_visuals(Vector2.ZERO)
		move_and_slide()
		return

	var input_vector := _movement_input()
	velocity = input_vector * speed
	if input_vector != Vector2.ZERO:
		facing = input_vector.normalized()
	_update_movement_visuals(input_vector)

	move_and_slide()


func enter_cover() -> void:
	cover_depth += 1
	_update_hidden_visual()


func exit_cover() -> void:
	cover_depth = maxi(0, cover_depth - 1)
	_update_hidden_visual()


func is_hidden() -> bool:
	return cover_depth > 0


func _movement_input() -> Vector2:
	var input_vector := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	if Input.is_key_pressed(KEY_A):
		input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_vector.x += 1.0
	if Input.is_key_pressed(KEY_W):
		input_vector.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_vector.y += 1.0

	return input_vector.normalized() if input_vector.length() > 1.0 else input_vector


func _update_hidden_visual() -> void:
	if hidden_ring == null:
		return
	hidden_ring.visible = is_hidden()
	modulate = Color(0.72, 1.0, 0.78, 0.82) if is_hidden() else Color.WHITE


func _update_movement_visuals(input_vector: Vector2) -> void:
	body_pivot.rotation = 0.0
	body_sprite.flip_h = facing.x > 0.0
	if input_vector != Vector2.ZERO:
		if body_sprite.animation != &"walk":
			body_sprite.play("walk")
	elif body_sprite.animation != &"default":
		body_sprite.play("default")
