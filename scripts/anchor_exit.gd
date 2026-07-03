extends Area2D
class_name AnchorExit

signal player_entered
signal player_exited

@export var activation_radius: float = 62.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func contains_body(body: Node2D) -> bool:
	if body == null:
		return false
	return global_position.distance_to(body.global_position) <= activation_radius


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_entered.emit()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_exited.emit()
