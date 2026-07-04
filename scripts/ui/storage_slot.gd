extends Control

signal slot_clicked(storage_id: String, slot_index: int, button_index: int, shift_pressed: bool)

const CjkFont := preload("res://assets/SourceHanSerifCN-Heavy.otf")
const SLOT_SIZE := Vector2(64, 64)

var storage_id: String = ""
var slot_index: int = -1
var stack: Dictionary = {"rarity": "", "count": 0}

var _count_label: Label


func _ready() -> void:
	custom_minimum_size = SLOT_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_count_label = Label.new()
	_count_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_count_label.add_theme_font_override("font", CjkFont)
	_count_label.add_theme_font_size_override("font_size", 15)
	_count_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(_count_label)
	_refresh()


func configure(new_storage_id: String, new_slot_index: int) -> void:
	storage_id = new_storage_id
	slot_index = new_slot_index


func refresh(new_stack: Dictionary) -> void:
	stack = {
		"rarity": String(new_stack.get("rarity", "")),
		"count": maxi(0, int(new_stack.get("count", 0))),
	}
	_refresh()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT and event.button_index != MOUSE_BUTTON_RIGHT:
		return

	slot_clicked.emit(storage_id, slot_index, event.button_index, event.shift_pressed)
	accept_event()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.09, 0.12, 0.14, 0.96), true)
	draw_rect(rect, Color(0.52, 0.64, 0.68, 1.0), false, 2.0)

	if _is_empty():
		return

	var icon_color := _item_color(stack["rarity"])
	var center := size * 0.5 + Vector2(0, -4)
	var radius := minf(size.x, size.y) * 0.28
	var points := PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius, 0),
		center + Vector2(0, radius),
		center + Vector2(-radius, 0),
	])
	draw_colored_polygon(points, icon_color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color(0.95, 1.0, 1.0, 0.9), 2.0)


func _refresh() -> void:
	if _count_label != null:
		_count_label.text = "" if _is_empty() else str(stack["count"])
		_count_label.tooltip_text = _tooltip_text()
	tooltip_text = _tooltip_text()
	queue_redraw()


func _tooltip_text() -> String:
	if _is_empty():
		return "空格"
	return "%s x%d" % [_rarity_label(stack["rarity"]), stack["count"]]


func _is_empty() -> bool:
	return String(stack.get("rarity", "")) == "" or int(stack.get("count", 0)) <= 0


func _rarity_label(rarity: String) -> String:
	match rarity:
		"common":
			return "沉积样本"
		"rare":
			return "装置碎片"
		"legendary":
			return "历史遗物"
	return rarity


func _item_color(rarity: String) -> Color:
	match rarity:
		"common":
			return Color(1.0, 0.82, 0.18, 1.0)
		"rare":
			return Color(0.18, 0.72, 1.0, 1.0)
		"legendary":
			return Color(1.0, 0.28, 0.86, 1.0)
	return Color(0.8, 0.86, 0.88, 1.0)
