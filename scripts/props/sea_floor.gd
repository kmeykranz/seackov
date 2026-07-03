extends Node2D

@onready var base: ColorRect = $Base
@onready var grid: Node2D = $Grid
@onready var decoration: Node2D = $Decoration


func configure(world_rect: Rect2) -> void:
	base.size = world_rect.size
	_draw_grid(world_rect.size)
	_draw_currents(world_rect.size)


func _draw_grid(size: Vector2) -> void:
	for x in range(0, int(size.x), 160):
		var line := ColorRect.new()
		line.color = Color(0.12, 0.42, 0.49, 0.20)
		line.position = Vector2(x, 0)
		line.size = Vector2(2, size.y)
		grid.add_child(line)

	for y in range(0, int(size.y), 160):
		var line := ColorRect.new()
		line.color = Color(0.12, 0.42, 0.49, 0.20)
		line.position = Vector2(0, y)
		line.size = Vector2(size.x, 2)
		grid.add_child(line)


func _draw_currents(size: Vector2) -> void:
	for i in range(26):
		var current := Polygon2D.new()
		current.name = "Current%02d" % i
		current.position = Vector2(90.0 + float((i * 257) % int(size.x - 180.0)), 80.0 + float((i * 151) % int(size.y - 160.0)))
		current.color = Color(0.42, 0.78, 0.88, 0.23)
		current.polygon = PackedVector2Array([
			Vector2(-46, -6),
			Vector2(20, -14),
			Vector2(54, 1),
			Vector2(18, 15),
			Vector2(-52, 8),
		])
		decoration.add_child(current)
