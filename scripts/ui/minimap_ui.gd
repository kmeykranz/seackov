extends CanvasLayer

@onready var _panel: Panel = $Panel
@onready var _map_view: Control = $Panel/MarginContainer/VBoxContainer/MapView
@onready var _close_button: Button = $Panel/MarginContainer/VBoxContainer/Header/CloseButton


func _ready() -> void:
	_close_button.pressed.connect(close_panel)
	close_panel()


func _process(_delta: float) -> void:
	if is_open():
		refresh()


func configure(world_rect: Rect2, regions: Array) -> void:
	_map_view.configure(world_rect, regions)


func set_run_state(unlocked_region_count: int, anchors: Array, spawn_anchor_id: String, player: Node2D) -> void:
	_map_view.set_run_state(unlocked_region_count, anchors, spawn_anchor_id, player)


func set_story_targets(targets: Array) -> void:
	_map_view.set_story_targets(targets)


func open_panel() -> void:
	_panel.visible = true
	refresh()


func close_panel() -> void:
	_panel.visible = false
	refresh()


func toggle_panel() -> void:
	if is_open():
		close_panel()
	else:
		open_panel()


func is_open() -> bool:
	return _panel.visible


func refresh() -> void:
	if _map_view != null:
		_map_view.queue_redraw()


func get_visible_region_count() -> int:
	return _map_view.get_visible_region_count()


func get_story_target_count() -> int:
	return _map_view.get_story_target_count()
