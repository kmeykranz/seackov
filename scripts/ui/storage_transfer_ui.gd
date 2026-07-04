extends CanvasLayer

signal storage_changed(message: String)

const StorageSlotScript := preload("res://scripts/ui/storage_slot.gd")
const STORAGE_BACKPACK := "backpack"
const STORAGE_WAREHOUSE := "warehouse"
const CURSOR_OFFSET := Vector2(14, 14)

var _slots := {}
var _cursor_stack := {"rarity": "", "count": 0}
var _cursor_return_storage: String = STORAGE_BACKPACK
var _cursor_preview: Control

@onready var _panel: Panel = $Panel
@onready var _status_label: Label = $Panel/MarginContainer/VBoxContainer/StatusLabel
@onready var _held_stack_label: Label = $Panel/MarginContainer/VBoxContainer/Header/HeldStackLabel
@onready var _backpack_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/StorageRows/BackpackColumn/BackpackGrid
@onready var _warehouse_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/StorageRows/WarehouseColumn/WarehouseGrid
@onready var _close_button: Button = $Panel/MarginContainer/VBoxContainer/Header/CloseButton


func _ready() -> void:
	_build_slots()
	_build_cursor_preview()
	_close_button.pressed.connect(close_panel)
	set_process(true)
	close_panel()


func open_panel(message: String = "") -> void:
	_panel.visible = true
	refresh()
	if message != "":
		_status_label.text = message


func close_panel() -> void:
	if not _return_cursor_stack():
		_status_label.text = "手上还有物品，背包和仓库都放不下。"
		_panel.visible = true
		return
	_panel.visible = false
	refresh()


func toggle_panel() -> void:
	if is_open():
		close_panel()
	else:
		open_panel("左键整组拿取/放下，右键拿一半或放一个，Shift+点击快速转移。")


func is_open() -> bool:
	return _panel.visible


func refresh() -> void:
	var inventory = _inventory()
	for index in range(inventory.get_storage_slot_count(STORAGE_BACKPACK)):
		get_slot(STORAGE_BACKPACK, index).refresh(inventory.get_slot_stack(STORAGE_BACKPACK, index))
	for index in range(inventory.get_storage_slot_count(STORAGE_WAREHOUSE)):
		get_slot(STORAGE_WAREHOUSE, index).refresh(inventory.get_slot_stack(STORAGE_WAREHOUSE, index))

	_held_stack_label.text = "手上：%s" % inventory.format_stack(_cursor_stack)
	_update_cursor_preview()


func click_slot(storage_id: String, slot_index: int, button_index: int, shift_pressed: bool = false) -> Dictionary:
	var inventory = _inventory()
	var message := ""
	if shift_pressed:
		if inventory.is_empty_stack(_cursor_stack):
			var result: Dictionary = inventory.quick_transfer_slot(storage_id, slot_index)
			message = "快速转移：%s。" % inventory.format_counts(result["counts"]) if int(result["total_count"]) > 0 else "没有可快速转移的物品。"
		else:
			message = "手上有物品时不能快速转移。"
	elif button_index == MOUSE_BUTTON_LEFT:
		message = _handle_left_click(storage_id, slot_index)
	elif button_index == MOUSE_BUTTON_RIGHT:
		message = _handle_right_click(storage_id, slot_index)
	else:
		message = "未处理的鼠标操作。"

	refresh()
	_status_label.text = message
	storage_changed.emit(message)
	return {
		"message": message,
		"cursor": _cursor_stack,
	}


func get_slot(storage_id: String, slot_index: int):
	return _slots["%s:%d" % [storage_id, slot_index]]


func get_cursor_stack() -> Dictionary:
	return {
		"rarity": String(_cursor_stack.get("rarity", "")),
		"count": int(_cursor_stack.get("count", 0)),
	}


func is_cursor_preview_visible() -> bool:
	return _cursor_preview != null and _cursor_preview.visible


func get_cursor_preview_position() -> Vector2:
	return Vector2.ZERO if _cursor_preview == null else _cursor_preview.position


func _process(_delta: float) -> void:
	_update_cursor_preview_position()


func _handle_left_click(storage_id: String, slot_index: int) -> String:
	var inventory = _inventory()
	if inventory.is_empty_stack(_cursor_stack):
		_cursor_stack = inventory.take_slot_stack(storage_id, slot_index)
		_cursor_return_storage = storage_id
		if inventory.is_empty_stack(_cursor_stack):
			return "空格。"
		return "拿起：%s。" % inventory.format_stack(_cursor_stack)

	var before: String = inventory.format_stack(_cursor_stack)
	_cursor_stack = inventory.place_stack_in_slot(storage_id, slot_index, _cursor_stack)
	if inventory.is_empty_stack(_cursor_stack):
		return "放下：%s。" % before
	return "交换/合并后手上：%s。" % inventory.format_stack(_cursor_stack)


func _handle_right_click(storage_id: String, slot_index: int) -> String:
	var inventory = _inventory()
	if inventory.is_empty_stack(_cursor_stack):
		_cursor_stack = inventory.take_half_slot_stack(storage_id, slot_index)
		_cursor_return_storage = storage_id
		if inventory.is_empty_stack(_cursor_stack):
			return "空格。"
		return "拿起一半：%s。" % inventory.format_stack(_cursor_stack)

	var before_count := int(_cursor_stack["count"])
	_cursor_stack = inventory.place_one_in_slot(storage_id, slot_index, _cursor_stack)
	if int(_cursor_stack.get("count", 0)) < before_count:
		return "放下 1 个，手上：%s。" % inventory.format_stack(_cursor_stack)
	return "这个格子不能右键放入。"


func _return_cursor_stack() -> bool:
	var inventory = _inventory()
	if inventory.is_empty_stack(_cursor_stack):
		return true

	var result: Dictionary = inventory.add_stack_to_storage(_cursor_return_storage, _cursor_stack)
	var remainder := int(result["remainder"])
	if remainder > 0:
		var fallback_storage := STORAGE_WAREHOUSE if _cursor_return_storage == STORAGE_BACKPACK else STORAGE_BACKPACK
		result = inventory.add_to_storage(fallback_storage, _cursor_stack["rarity"], remainder)
		remainder = int(result["remainder"])

	if remainder > 0:
		_cursor_stack["count"] = remainder
		refresh()
		return false

	_cursor_stack = {"rarity": "", "count": 0}
	return true


func _build_slots() -> void:
	if not _slots.is_empty():
		return
	var inventory = _inventory()
	for index in range(inventory.get_storage_slot_count(STORAGE_BACKPACK)):
		_add_slot(_backpack_grid, STORAGE_BACKPACK, index)
	for index in range(inventory.get_storage_slot_count(STORAGE_WAREHOUSE)):
		_add_slot(_warehouse_grid, STORAGE_WAREHOUSE, index)


func _build_cursor_preview() -> void:
	if _cursor_preview != null:
		return

	_cursor_preview = StorageSlotScript.new()
	_cursor_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_preview.z_index = 100
	add_child(_cursor_preview)
	_cursor_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_preview.visible = false


func _add_slot(parent: Node, storage_id: String, slot_index: int) -> void:
	var slot = StorageSlotScript.new()
	slot.configure(storage_id, slot_index)
	slot.slot_clicked.connect(_on_slot_clicked)
	parent.add_child(slot)
	_slots["%s:%d" % [storage_id, slot_index]] = slot


func _on_slot_clicked(storage_id: String, slot_index: int, button_index: int, shift_pressed: bool) -> void:
	click_slot(storage_id, slot_index, button_index, shift_pressed)


func _update_cursor_preview() -> void:
	if _cursor_preview == null:
		return

	var inventory = _inventory()
	var has_cursor_stack: bool = not inventory.is_empty_stack(_cursor_stack)
	_cursor_preview.visible = is_open() and has_cursor_stack
	_cursor_preview.refresh(_cursor_stack if has_cursor_stack else {"rarity": "", "count": 0})
	_update_cursor_preview_position()


func _update_cursor_preview_position() -> void:
	if _cursor_preview == null or not _cursor_preview.visible:
		return
	_cursor_preview.position = _cursor_preview.get_global_mouse_position() + CURSOR_OFFSET


func _inventory():
	return get_node("/root/PlayerInventory")
