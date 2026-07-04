extends CanvasLayer

signal resume_pressed
signal settings_pressed
signal exit_to_menu_pressed

@onready var _panel: PanelContainer = $Panel
@onready var _status_label: Label = $Panel/MarginContainer/VBoxContainer/StatusLabel
@onready var _resume_button: Button = $Panel/MarginContainer/VBoxContainer/ResumeButton
@onready var _settings_button: Button = $Panel/MarginContainer/VBoxContainer/SettingsButton
@onready var _exit_menu_button: Button = $Panel/MarginContainer/VBoxContainer/ExitMenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resume_button.pressed.connect(func() -> void: resume_pressed.emit())
	_settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	_exit_menu_button.pressed.connect(func() -> void: exit_to_menu_pressed.emit())
	close_panel()


func open_panel() -> void:
	_status_label.text = "游戏已暂停"
	_panel.visible = true


func close_panel() -> void:
	_panel.visible = false


func is_open() -> bool:
	return _panel.visible


func show_settings_message() -> void:
	_status_label.text = "设置入口已预留。"
