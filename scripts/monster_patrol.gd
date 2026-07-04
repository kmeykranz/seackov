extends CharacterBody2D
class_name MonsterPatrol

signal player_detected(monster: Node, reason: String)

enum State {PATROL, CHASE}

@export var patrol_speed: float = 125.0
@export var chase_speed: float = 205.0
@export var vision_range: float = 310.0
@export var vision_angle_degrees: float = 72.0
@export var lost_sight_grace: float = 1.2

var state: State = State.PATROL
var patrol_points: Array[Vector2] = []
var target: Node2D
var wall_mask: int = 0
var facing: Vector2 = Vector2.RIGHT

var _active: bool = true
var _patrol_index: int = 0
var _lost_sight_timer: float = 0.0

@onready var vision_cone: Polygon2D = $VisionCone
@onready var body_pivot: Node2D = $BodyPivot
@onready var body_sprite: AnimatedSprite2D = $BodyPivot/AnimatedSprite2D
@onready var catch_area: Area2D = $CatchArea


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

	var sees_player := can_see_player(target)
	if sees_player:
		if state != State.CHASE:
			player_detected.emit(self, "sight")
		state = State.CHASE
		_lost_sight_timer = lost_sight_grace

	match state:
		State.PATROL:
			_process_patrol()
		State.CHASE:
			_process_chase(delta, sees_player)

	move_and_slide()
	_update_visuals()


func _process_patrol() -> void:
	if patrol_points.is_empty():
		velocity = Vector2.ZERO
		return

	var waypoint := patrol_points[_patrol_index]
	if global_position.distance_to(waypoint) <= 14.0:
		_patrol_index = (_patrol_index + 1) % patrol_points.size()
		waypoint = patrol_points[_patrol_index]

	var direction := waypoint - global_position
	if direction.length() <= 0.01:
		velocity = Vector2.ZERO
		return

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
	body_pivot.modulate = Color(1.0, 0.48, 0.28, 1.0) if state == State.CHASE else Color.WHITE

	var half_width := tan(deg_to_rad(vision_angle_degrees * 0.5)) * vision_range
	vision_cone.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(vision_range, -half_width),
		Vector2(vision_range, half_width),
	])
	vision_cone.rotation = facing.angle()


func _on_catch_area_body_entered(body: Node) -> void:
	if body == target:
		state = State.CHASE
		_lost_sight_timer = lost_sight_grace
		player_detected.emit(self, "collision")
