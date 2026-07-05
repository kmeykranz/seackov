extends CanvasLayer

signal spawn_anchor_selected(anchor_id: String)

const FONT_PATH := "res://assets/ZaoZiGongFangYingLiHeiGuiTi-1.otf"

@onready var _panel: Panel = $Panel
@onready var _close_button: Button = $Panel/MarginContainer/VBoxContainer/Header/CloseButton
@onready var _task_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/Content/TaskColumn/TaskList
@onready var _spawn_status_label: Label = $Panel/MarginContainer/VBoxContainer/Content/SpawnColumn/SpawnStatusLabel
@onready var _spawn_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/Content/SpawnColumn/SpawnList

var _font: FontFile
var _can_choose_spawn: bool = false
var _anchor_ids: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load(FONT_PATH)
	_close_button.pressed.connect(close_panel)
	close_panel()


func open_panel(task_items: Array, anchor_specs: Array, selected_anchor_id: String, can_choose_spawn: bool) -> void:
	_refresh_content(task_items, anchor_specs, selected_anchor_id, can_choose_spawn)
	_panel.visible = true


func close_panel() -> void:
	_panel.visible = false


func is_open() -> bool:
	return _panel.visible


func get_task_count() -> int:
	return _task_list.get_child_count()


func get_spawn_option_count() -> int:
	return _anchor_ids.size()


func choose_spawn_anchor(anchor_id: String) -> bool:
	if not _can_choose_spawn:
		return false
	if anchor_id != "" and not _anchor_ids.has(anchor_id):
		return false
	spawn_anchor_selected.emit(anchor_id)
	return true


func _refresh_content(task_items: Array, anchor_specs: Array, selected_anchor_id: String, can_choose_spawn: bool) -> void:
	_can_choose_spawn = can_choose_spawn
	_anchor_ids.clear()
	_clear_children(_task_list)
	_clear_children(_spawn_list)
	_populate_tasks(task_items)
	_populate_spawn_options(anchor_specs, selected_anchor_id)


func _populate_tasks(task_items: Array) -> void:
	if task_items.is_empty():
		_task_list.add_child(_make_label("暂无任务。", 18, Color(0.72, 0.86, 0.9, 0.86)))
		return

	for item in task_items:
		var title := String(item.get("title", "任务"))
		var detail := String(item.get("detail", ""))
		var completed := bool(item.get("completed", false))
		var active := bool(item.get("active", false))
		var marker := "✓" if completed else ("●" if active else "○")
		var color := Color(0.48, 1.0, 0.68, 0.96) if completed else (Color(0.95, 0.86, 0.42, 1.0) if active else Color(0.76, 0.9, 0.94, 0.92))
		var label := _make_label("%s %s\n%s" % [marker, title, detail], 17, color)
		label.custom_minimum_size = Vector2(0.0, 58.0)
		_task_list.add_child(label)


func _populate_spawn_options(anchor_specs: Array, selected_anchor_id: String) -> void:
	if _can_choose_spawn:
		_spawn_status_label.text = "选择本次下潜出生锚点。留空时默认从当前最深已解锁区域随机。"
	else:
		_spawn_status_label.text = "完成信号塔网络后，可在这里选择本次下潜出生锚点。"

	var default_button := _make_button("默认：最深已解锁区域随机%s" % ("（已选）" if selected_anchor_id == "" else ""))
	default_button.disabled = not _can_choose_spawn
	default_button.pressed.connect(func() -> void: choose_spawn_anchor(""))
	_spawn_list.add_child(default_button)

	for spec in anchor_specs:
		var anchor_id := String(spec.get("id", ""))
		if anchor_id == "":
			continue
		_anchor_ids.append(anchor_id)
		var label := String(spec.get("label", anchor_id))
		var region_id := int(spec.get("region_id", 1))
		var selected := "（已选）" if anchor_id == selected_anchor_id else ""
		var button := _make_button("L%d  %s%s" % [region_id, label, selected])
		button.disabled = not _can_choose_spawn
		var captured_id := anchor_id
		button.pressed.connect(func() -> void: choose_spawn_anchor(captured_id))
		_spawn_list.add_child(button)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if _font != null:
		label.add_theme_font_override("font", _font)
	return label


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 42.0)
	button.add_theme_font_size_override("font_size", 18)
	if _font != null:
		button.add_theme_font_override("font", _font)
	return button


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		child.queue_free()
