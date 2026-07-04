extends CharacterBody2D
class_name PlayerDiver

const BODY_LENGTH := 48.0
const SOFT_BOUNDARY_REBOUND_DISTANCE := BODY_LENGTH * 2.0
const BASE_MAX_SPEED := 560.0
const DASH_MAX_SPEED := 1120.0
const ACCELERATION := 1800.0
const TURN_ACCELERATION := 2600.0
const DECELERATION := 2200.0
const DASH_IMPULSE := 360.0
const DASH_DURATION := 0.34
const DASH_COOLDOWN := 0.72
const WORLD_BOUNDARY_MARGIN := 260.0
const WORLD_BOUNDARY_REBOUND_DISTANCE := BODY_LENGTH * 2.0

@export var speed: float = BASE_MAX_SPEED
var control_enabled: bool = true
var facing: Vector2 = Vector2.RIGHT
var cover_depth: int = 0
var _last_horizontal_facing_right: bool = true
var _soft_left_boundary_enabled: bool = false
var _soft_left_boundary_x: float = 0.0
var _soft_boundary_margin: float = 520.0
var _soft_world_bounds_enabled: bool = false
var _soft_world_bounds: Rect2
var _world_boundary_margin: float = WORLD_BOUNDARY_MARGIN
var _world_boundary_rebound_distance: float = WORLD_BOUNDARY_REBOUND_DISTANCE
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _space_was_pressed: bool = false

@onready var body_pivot: Node2D = $BodyPivot
@onready var body_sprite: AnimatedSprite2D = $BodyPivot/AnimatedSprite2D
@onready var hidden_ring: Polygon2D = $HiddenRing
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group("player")
	_update_movement_visuals(Vector2.ZERO)
	_update_hidden_visual()


func configure_camera(bounds: Rect2) -> void:
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)
	camera.zoom = Vector2(1.4, 1.4)
	camera.make_current()


func configure_soft_left_boundary(boundary_x: float, margin: float) -> void:
	_soft_left_boundary_enabled = boundary_x >= 0.0
	_soft_left_boundary_x = boundary_x
	_soft_boundary_margin = maxf(1.0, margin)


func clear_soft_left_boundary() -> void:
	_soft_left_boundary_enabled = false


func configure_soft_world_bounds(bounds: Rect2, margin: float = WORLD_BOUNDARY_MARGIN, rebound_distance: float = WORLD_BOUNDARY_REBOUND_DISTANCE) -> void:
	_soft_world_bounds_enabled = true
	_soft_world_bounds = bounds
	_world_boundary_margin = maxf(1.0, margin)
	_world_boundary_rebound_distance = maxf(1.0, rebound_distance)


func clear_soft_world_bounds() -> void:
	_soft_world_bounds_enabled = false


func is_soft_left_boundary_enabled() -> bool:
	return _soft_left_boundary_enabled


func get_soft_left_boundary_x() -> float:
	return _soft_left_boundary_x


func get_soft_left_boundary_rebound_distance() -> float:
	return SOFT_BOUNDARY_REBOUND_DISTANCE


func get_base_max_speed() -> float:
	return speed


func get_dash_max_speed() -> float:
	return DASH_MAX_SPEED


func get_current_speed_cap() -> float:
	return lerpf(get_base_max_speed(), get_dash_max_speed(), _dash_boost_weight())


func get_world_boundary_rebound_distance() -> float:
	return _world_boundary_rebound_distance


func is_dash_active() -> bool:
	return _dash_timer > 0.0


func trigger_dash(direction: Vector2 = Vector2.ZERO) -> bool:
	if _dash_cooldown_timer > 0.0:
		return false

	var dash_vector := direction
	if dash_vector == Vector2.ZERO:
		dash_vector = facing
	if dash_vector == Vector2.ZERO:
		dash_vector = Vector2.RIGHT

	_dash_timer = DASH_DURATION
	_dash_cooldown_timer = DASH_COOLDOWN
	velocity += dash_vector.normalized() * DASH_IMPULSE
	return true


func _physics_process(_delta: float) -> void:
	if not control_enabled:
		velocity = Vector2.ZERO
		_dash_timer = 0.0
		_update_movement_visuals(Vector2.ZERO)
		move_and_slide()
		return

	var input_vector := _movement_input()
	_update_dash_timers(_delta)
	_handle_dash_input(input_vector)
	_update_velocity(input_vector, _delta)
	if input_vector != Vector2.ZERO:
		facing = input_vector.normalized()
		if absf(input_vector.x) > 0.01:
			_last_horizontal_facing_right = input_vector.x > 0.0
	_apply_soft_world_boundary()
	_apply_soft_left_boundary()
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


func _update_dash_timers(delta: float) -> void:
	_dash_timer = maxf(0.0, _dash_timer - delta)
	_dash_cooldown_timer = maxf(0.0, _dash_cooldown_timer - delta)


func _handle_dash_input(input_vector: Vector2) -> void:
	var space_pressed := Input.is_key_pressed(KEY_SPACE)
	if space_pressed and not _space_was_pressed:
		trigger_dash(input_vector)
	_space_was_pressed = space_pressed


func _update_velocity(input_vector: Vector2, delta: float) -> void:
	var target_velocity := input_vector * get_current_speed_cap()
	var acceleration := DECELERATION
	if input_vector != Vector2.ZERO:
		acceleration = TURN_ACCELERATION if velocity != Vector2.ZERO and velocity.dot(target_velocity) < 0.0 else ACCELERATION
		if is_dash_active():
			acceleration = TURN_ACCELERATION

	velocity = velocity.move_toward(target_velocity, acceleration * delta)
	var speed_cap := get_current_speed_cap()
	if velocity.length() > speed_cap:
		velocity = velocity.normalized() * speed_cap


func _dash_boost_weight() -> float:
	if _dash_timer <= 0.0:
		return 0.0
	var t := clampf(_dash_timer / DASH_DURATION, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _apply_soft_world_boundary() -> void:
	if not _soft_world_bounds_enabled:
		return

	_apply_world_boundary_axis(
		global_position.x - _soft_world_bounds.position.x,
		Vector2.RIGHT,
		velocity.x < -0.01
	)
	_apply_world_boundary_axis(
		_soft_world_bounds.end.x - global_position.x,
		Vector2.LEFT,
		velocity.x > 0.01
	)
	_apply_world_boundary_axis(
		global_position.y - _soft_world_bounds.position.y,
		Vector2.DOWN,
		velocity.y < -0.01
	)
	_apply_world_boundary_axis(
		_soft_world_bounds.end.y - global_position.y,
		Vector2.UP,
		velocity.y > 0.01
	)


func _apply_world_boundary_axis(distance_from_edge: float, inward_direction: Vector2, pressing_into_edge: bool) -> void:
	if distance_from_edge >= _world_boundary_margin:
		return

	var depth := clampf((_world_boundary_margin - distance_from_edge) / _world_boundary_margin, 0.0, 1.0)
	if pressing_into_edge:
		if absf(inward_direction.x) > 0.0:
			velocity.x *= 1.0 - depth * 0.86
		else:
			velocity.y *= 1.0 - depth * 0.86

	var rebound_distance := minf(_world_boundary_margin, _world_boundary_rebound_distance)
	if distance_from_edge < 0.0:
		velocity += inward_direction * (760.0 + -distance_from_edge * 7.5)
	elif distance_from_edge < rebound_distance:
		var rebound_depth := (rebound_distance - distance_from_edge) / rebound_distance
		velocity += inward_direction * 320.0 * rebound_depth * rebound_depth


func _apply_soft_left_boundary() -> void:
	if not _soft_left_boundary_enabled:
		return

	var distance_from_boundary := global_position.x - _soft_left_boundary_x
	if distance_from_boundary >= _soft_boundary_margin:
		return

	var depth := clampf((_soft_boundary_margin - distance_from_boundary) / _soft_boundary_margin, 0.0, 1.0)
	var pressing_into_boundary := velocity.x < -0.01
	if velocity.x < 0.0:
		velocity.x *= 1.0 - depth * 0.9

	var rebound_distance := minf(_soft_boundary_margin, SOFT_BOUNDARY_REBOUND_DISTANCE)
	if distance_from_boundary < 0.0:
		var penetration := -distance_from_boundary
		velocity.x += 620.0 + penetration * 7.5
		velocity.y *= maxf(0.22, 1.0 - depth * 0.4)
	elif not pressing_into_boundary and distance_from_boundary < rebound_distance:
		var rebound_depth := (rebound_distance - distance_from_boundary) / rebound_distance
		velocity.x += 280.0 * rebound_depth * rebound_depth


func _update_hidden_visual() -> void:
	if hidden_ring == null:
		return
	hidden_ring.visible = is_hidden()
	modulate = Color(0.72, 1.0, 0.78, 0.82) if is_hidden() else Color.WHITE


func _update_movement_visuals(input_vector: Vector2) -> void:
	body_pivot.rotation = 0.0
	body_sprite.flip_h = _last_horizontal_facing_right

	var desired_animation := &"default"
	body_sprite.flip_v = false
	if input_vector != Vector2.ZERO:
		if absf(input_vector.y) > absf(input_vector.x):
			desired_animation = &"down" if input_vector.y > 0.0 else &"up"
		else:
			desired_animation = &"walk"

	if body_sprite.animation != desired_animation:
		body_sprite.play(desired_animation)
