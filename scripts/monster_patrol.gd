extends CharacterBody2D
class_name MonsterPatrol

signal player_detected(monster: Node, reason: String)

enum State {PATROL, CHASE}

@export var patrol_speed: float = 125.0
@export var chase_speed: float = 205.0
@export var vision_range: float = 310.0
@export var vision_angle_degrees: float = 72.0
@export var lost_sight_grace: float = 1.2
@export var monster_label: String = "章鱼"

var state: State = State.PATROL
var patrol_points: Array[Vector2] = []
var target: Node2D
var wall_mask: int = 0
var facing: Vector2 = Vector2.RIGHT

var _active: bool = true
var _patrol_index: int = 0
var _lost_sight_timer: float = 0.0
var _stun_timer: float = 0.0
var _disarm_timer: float = 0.0
var _knockback_timer: float = 0.0

## —— 巡逻卡住检测 / 避障 ——
var _last_waypoint_distance: float = 0.0
var _stuck_counter: int = 0
var _sidestep_dir: Vector2 = Vector2.ZERO
var _sidestep_timer: float = 0.0

const STUCK_FRAMES: int = 30
const SIDESTEP_DURATION: float = 0.55
const SIDESTEP_SPEED: float = 130.0

@onready var vision_cone: Polygon2D = $VisionCone
@onready var body_pivot: Node2D = $BodyPivot
@onready var body_sprite: AnimatedSprite2D = $BodyPivot/AnimatedSprite2D
@onready var catch_area: Area2D = $CatchArea
@onready var name_label: Label = $NameLabel


func _ready() -> void:
	catch_area.body_entered.connect(_on_catch_area_body_entered)
	_update_visuals()


func configure(points: Array, player: Node2D, blocker_mask: int) -> void:
	patrol_points.clear()
	for point in points:
		patrol_points.append(point)
	target = player
	wall_mask = blocker_mask
	if not patrol_points.is_empty():
		global_position = patrol_points[0]
		_patrol_index = 1 % patrol_points.size()


func configure_collision(body_layer: int, body_mask: int, catch_mask: int) -> void:
	collision_layer = body_layer
	collision_mask = body_mask
	catch_area.collision_mask = catch_mask


func set_active(is_active: bool) -> void:
	_active = is_active
	set_physics_process(is_active)
	if not is_active:
		velocity = Vector2.ZERO


func apply_stun(duration: float) -> void:
	_stun_timer = maxf(_stun_timer, duration)
	velocity = Vector2.ZERO


func apply_disarm(duration: float) -> void:
	_disarm_timer = maxf(_disarm_timer, duration)


func apply_knockback(source_position: Vector2, impulse: float) -> void:
	var direction := global_position - source_position
	if direction == Vector2.ZERO:
		direction = - facing
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	velocity = direction.normalized() * impulse
	_knockback_timer = 0.28


func defeat() -> void:
	set_active(false)
	collision_layer = 0
	collision_mask = 0
	catch_area.collision_layer = 0
	catch_area.collision_mask = 0
	visible = false
	queue_free()


func can_attack_player() -> bool:
	return _active and _stun_timer <= 0.0 and _disarm_timer <= 0.0


func is_stunned() -> bool:
	return _stun_timer > 0.0


func is_disarmed() -> bool:
	return _disarm_timer > 0.0


func can_see_player(candidate: Node2D) -> bool:
	if candidate == null:
		return false
	if candidate.has_method("is_hidden") and candidate.is_hidden():
		return false

	var to_player := candidate.global_position - global_position
	var distance := to_player.length()
	if distance <= 0.01:
		return true
	if distance > vision_range:
		return false

	var forward := facing.normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.RIGHT

	var direction_to_player := to_player.normalized()
	var half_angle := deg_to_rad(vision_angle_degrees * 0.5)
	if absf(forward.angle_to(direction_to_player)) > half_angle:
		return false

	if wall_mask != 0:
		var query := PhysicsRayQueryParameters2D.create(global_position, candidate.global_position, wall_mask, [get_rid()])
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var result := get_world_2d().direct_space_state.intersect_ray(query)
		if not result.is_empty():
			return false

	return true


func _physics_process(delta: float) -> void:
	if not _active:
		return

	_update_effect_timers(delta)
	if _stun_timer > 0.0:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_visuals()
		return
	if _knockback_timer > 0.0:
		_knockback_timer = maxf(0.0, _knockback_timer - delta)
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		_update_visuals()
		return

	var sees_player := can_see_player(target)
	if sees_player:
		if state != State.CHASE and can_attack_player():
			player_detected.emit(self, "sight")
		state = State.CHASE
		_lost_sight_timer = lost_sight_grace

	match state:
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta, sees_player)

	move_and_slide()
	_update_visuals()


func _process_patrol(delta: float) -> void:
	if patrol_points.is_empty():
		velocity = Vector2.ZERO
		return

	var waypoint := patrol_points[_patrol_index]

	# —— 侧移绕路模式 ——
	if _sidestep_timer > 0.0:
		_sidestep_timer = maxf(0.0, _sidestep_timer - delta)
		velocity = _sidestep_dir * SIDESTEP_SPEED
		facing = _sidestep_dir
		return

	var distance := global_position.distance_to(waypoint)

	if distance <= 14.0:
		_patrol_index = (_patrol_index + 1) % patrol_points.size()
		_last_waypoint_distance = 0.0
		_stuck_counter = 0
		return

	var direction := waypoint - global_position
	if direction.length() <= 0.01:
		velocity = Vector2.ZERO
		return

	# —— 卡住检测：连续 STUCK_FRAMES 帧没有明显靠近 ——
	if _last_waypoint_distance > 0.0 and distance >= _last_waypoint_distance - 2.0:
		_stuck_counter += 1
	else:
		_stuck_counter = 0

	if _stuck_counter >= STUCK_FRAMES:
		# 选一个垂直于目标方向的方向绕路
		var perp := Vector2(direction.y, -direction.x).normalized()
		if randi() % 2 == 0:
			perp = -perp
		_sidestep_dir = perp
		_sidestep_timer = SIDESTEP_DURATION
		_stuck_counter = 0
		_last_waypoint_distance = 0.0
		velocity = perp * SIDESTEP_SPEED
		facing = perp
		return

	_last_waypoint_distance = distance
	facing = direction.normalized()
	velocity = facing * patrol_speed


func _process_chase(delta: float, sees_player: bool) -> void:
	if target == null:
		state = State.PATROL
		return

	if sees_player:
		_lost_sight_timer = lost_sight_grace
	else:
		_lost_sight_timer -= delta
		if _lost_sight_timer <= 0.0:
			state = State.PATROL

	var direction := target.global_position - global_position
	if direction.length() <= 0.01:
		velocity = Vector2.ZERO
		return

	facing = direction.normalized()
	velocity = facing * chase_speed


func _update_visuals() -> void:
	body_pivot.rotation = 0.0
	body_sprite.flip_h = facing.x > 0.0
	if _stun_timer > 0.0:
		body_pivot.modulate = Color(0.44, 0.82, 1.0, 1.0)
	elif _disarm_timer > 0.0:
		body_pivot.modulate = Color(0.64, 1.0, 0.46, 1.0)
	else:
		body_pivot.modulate = Color(1.0, 0.48, 0.28, 1.0) if state == State.CHASE else Color.WHITE

	var half_width := tan(deg_to_rad(vision_angle_degrees * 0.5)) * vision_range
	vision_cone.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(vision_range, -half_width),
		Vector2(vision_range, half_width),
	])
	vision_cone.rotation = facing.angle()


func _on_catch_area_body_entered(body: Node) -> void:
	if body == target and can_attack_player():
		state = State.CHASE
		_lost_sight_timer = lost_sight_grace
		player_detected.emit(self, "collision")


func _update_effect_timers(delta: float) -> void:
	_stun_timer = maxf(0.0, _stun_timer - delta)
	_disarm_timer = maxf(0.0, _disarm_timer - delta)
