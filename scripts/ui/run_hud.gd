extends CanvasLayer

signal extract_pressed

@onready var status_label: Label = $StatusPanel/MarginContainer/StatusLabel
@onready var message_label: Label = $MessagePanel/MarginContainer/MessageLabel
@onready var anchor_prompt: PanelContainer = $AnchorPrompt
@onready var prompt_label: Label = $AnchorPrompt/MarginContainer/VBoxContainer/PromptLabel
@onready var extract_button: Button = $AnchorPrompt/MarginContainer/VBoxContainer/ExtractButton
@onready var end_panel: PanelContainer = $EndPanel
@onready var end_label: Label = $EndPanel/MarginContainer/EndLabel


func _ready() -> void:
	anchor_prompt.visible = false
	end_panel.visible = false
	extract_button.visible = false
	extract_button.pressed.connect(func() -> void: extract_pressed.emit())


func update_status(state_text: String, carried_value: int, carried_counts: Dictionary, warehouse_value: int, treasures_remaining: int) -> void:
	status_label.text = "State: %s\nCarried: %d  C/R/L: %d/%d/%d\nBanked: %d  Remaining: %d" % [
		state_text,
		carried_value,
		carried_counts.common,
		carried_counts.rare,
		carried_counts.legendary,
		warehouse_value,
		treasures_remaining,
	]


func show_message(text: String) -> void:
	message_label.text = text


func show_anchor_prompt(carried_value: int) -> void:
	prompt_label.text = "Press F to return to ship and settle.\nCarried value: %d" % carried_value
	anchor_prompt.visible = true


func hide_anchor_prompt() -> void:
	anchor_prompt.visible = false


func show_end(warehouse_value: int) -> void:
	end_label.text = "Run extracted\nBanked value: %d" % warehouse_value
	end_panel.visible = true


func is_anchor_prompt_visible() -> bool:
	return anchor_prompt.visible
