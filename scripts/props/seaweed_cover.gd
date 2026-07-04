extends Area2D

@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func configure(size: Vector2, display_name: String) -> void:
	return

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("enter_cover"):
		body.enter_cover()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("exit_cover"):
		body.exit_cover()
