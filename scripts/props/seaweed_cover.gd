extends Area2D

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var visual: ColorRect = $Visual
@onready var label: Label = $Label


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func configure(size: Vector2, display_name: String) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape

	visual.size = size
	visual.position = -size * 0.5
	label.text = display_name
	label.position = Vector2(-size.x * 0.5 + 10.0, -size.y * 0.5 + 8.0)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("enter_cover"):
		body.enter_cover()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("exit_cover"):
		body.exit_cover()
