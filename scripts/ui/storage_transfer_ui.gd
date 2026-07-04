extends CanvasLayer

signal storage_changed(message: String)

const StorageSlotScript := preload("res://scripts/ui/storage_slot.gd")
const STORAGE_BACKPACK := "backpack"
const STORAGE_WAREHOUSE := "warehouse"
const CURSOR_OFFSET := Vector2(14, 14)
const PANEL_FULL_WIDTH := 880.0
const PANEL_BACKPACK_WIDTH := 500.0
const PANEL_HEIGHT := 660.0
const PANEL_SIDE_MARGIN := 24.0
const PANEL_TOP_MARGIN := 22.0
const PANEL_BOTTOM_MARGIN := 24.0

var _slots := {}
var _cursor_stack := {"rarity": "", "count": 0}
var _cursor_return_storage: String = STORAGE_BACKPACK
var _cursor_preview: Control
var _backpack_only: bool = false

@onready var _panel: Panel = $Panel
@onready var _margin_container: MarginContainer = $Panel/MarginContainer
@onready var _status_label: Label = $Panel/MarginContainer/VBoxContainer/StatusLabel
@onready var _title_label: Label = $Panel/MarginContainer/VBoxContainer/Header/TitleLabel
@onready var _held_stack_label: Label = $Panel/MarginContainer/VBoxContainer/Header/HeldStackLabel
@onready var _backpack_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/StorageRows/BackpackColumn/BackpackGrid
@onready var _warehouse_column: VBoxContainer = $Panel/MarginContainer/VBoxContainer/StorageRows/WarehouseColumn
@onready var _warehouse_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/StorageRows/WarehouseColumn/WarehouseGrid
@onready var _close_button: Button = $Panel/MarginContainer/VBoxContainer/Header/CloseButton


func _ready() -> void:
	_build_slots()
	_build_cursor_preview()
	_close_button.pressed.connect(close_panel)
	set_process(true)
	_apply_mode()
	close_panel()


func open_panel(message: String = "") -> void:
	_layout_panel()
	_panel.visible = true
	refresh()
	if message != "":
		_status_label.text = message


func close_panel() -> void:
	if not _return_cursor_stack():
		_status_label.text = "手上还有物品，当前背包放不下。" if _backpack_only else "手上还有物品，背包和仓库都放不下。"
		_panel.visible = true
		return
	_panel.visible = false
	refresh()


func toggle_panel() -> void:
	if is_open():
		close_panel()
	else:
		open_panel(_help_text())


func is_open() -> bool:
	return _panel.visible


func set_backpack_only(enabled: bool) -> void:
	_backpack_only = enabled
	if _panel != null:
		_apply_mode()
		refresh()


func is_backpack_only() -> bool:
	return _backpack_only


func is_warehouse_visible() -> bool:
	return _warehouse_column != null and _warehouse_column.visible


func refresh() -> void:
	var inventory = _inventory()
	for index in range(inventory.get_storage_slot_count(STORAGE_BACKPACK)):
		get_slot(STORAGE_BACKPACK, index).refresh(inventory.get_slot_stack(STORAGE_BACKPACK, index))
	if not _backpack_only:
		for index in range(inventory.get_storage_slot_count(STORAGE_WAREHOUSE)):
			get_slot(STORAGE_WAREHOUSE, index).refresh(inventory.get_slot_stack(STORAGE_WAREHOUSE, index))

	_held_stack_label.text = "手上：%s" % inventory.format_stack(_cursor_stack)
	_update_cursor_preview()


func click_slot(storage_id: String, slot_index: int, button_index: int, shift_pressed: bool = false) -> Dictionary:
	var inventory = _inventory()
	var message := ""
	if not _can_access_storage(storage_id):
		message = "局内只能操作背包。"
	elif shift_pressed:
		if inventory.is_empty_stack(_cursor_stack):
			if _backpack_only:
				message = "局内背包不能快速转移到仓库。"
			else:
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


func return_cursor_stack_to_storage() -> bool:
	var returned := _return_cursor_stack()
	refresh()
	return returned


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
	if remainder > 0 and not _backpack_only:
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


func _apply_mode() -> void:
	_warehouse_column.visible = not _backpack_only
	_title_label.text = "背包" if _backpack_only else "背包 / 仓库"
	_status_label.text = _help_text()

	var panel_width := PANEL_BACKPACK_WIDTH if _backpack_only else PANEL_FULL_WIDTH
	_margin_container.offset_right = panel_width - PANEL_SIDE_MARGIN
	_layout_panel()


func _layout_panel() -> void:
	if _panel == null or _margin_container == null:
		return

	var panel_width := PANEL_BACKPACK_WIDTH if _backpack_only else PANEL_FULL_WIDTH
	var viewport_size := Vector2(1920.0, 1080.0)
	var viewport := get_viewport()
	if viewport != null:
		viewport_size = viewport.get_visible_rect().size

	_panel.offset_left = floorf((viewport_size.x - panel_width) * 0.5)
	_panel.offset_top = floorf((viewport_size.y - PANEL_HEIGHT) * 0.5)
	_panel.offset_right = _panel.offset_left + panel_width
	_panel.offset_bottom = _panel.offset_top + PANEL_HEIGHT
	_margin_container.offset_left = PANEL_SIDE_MARGIN
	_margin_container.offset_top = PANEL_TOP_MARGIN
	_margin_container.offset_right = panel_width - PANEL_SIDE_MARGIN
	_margin_container.offset_bottom = PANEL_HEIGHT - PANEL_BOTTOM_MARGIN


func _help_text() -> String:
	if _backpack_only:
		return "局内背包：左键整组拿取/放下，右键拿一半或放一个。"
	return "左键整组拿取/放下，右键拿一半或放一个，按住换挡键点击快速转移。"


func _can_access_storage(storage_id: String) -> bool:
	return storage_id == STORAGE_BACKPACK or (not _backpack_only and storage_id == STORAGE_WAREHOUSE)


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
