extends CanvasLayer

signal extract_pressed

@onready var status_label: Label = $StatusPanel/MarginContainer/StatusLabel
@onready var message_label: Label = $MessagePanel/MarginContainer/MessageLabel
@onready var tool_label: Label = $ToolPanel/MarginContainer/VBoxContainer/ToolLabel
@onready var tool_hint_label: Label = $ToolPanel/MarginContainer/VBoxContainer/ToolHintLabel
@onready var objective_label: Label = $ObjectivePanel/MarginContainer/VBoxContainer/ObjectiveLabel
@onready var objective_hint_label: Label = $ObjectivePanel/MarginContainer/VBoxContainer/ObjectiveHintLabel
@onready var objective_progress: ProgressBar = $ObjectivePanel/MarginContainer/VBoxContainer/ObjectiveProgress
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
	status_label.text = "状态：%s\n携带：%d  普/稀/传：%d/%d/%d\n已存：%d  剩余：%d" % [
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


func update_tool_status(title: String, hint: String) -> void:
	tool_label.text = title
	tool_hint_label.text = hint


func update_objective_status(title: String, hint: String, progress_value: float = -1.0) -> void:
	objective_label.text = "目标：%s" % title
	objective_hint_label.text = hint
	objective_progress.visible = progress_value >= 0.0
	if objective_progress.visible:
		objective_progress.value = clampf(progress_value, 0.0, 1.0) * 100.0


func show_anchor_prompt(carried_value: int) -> void:
	prompt_label.text = "按 F 返回船上并结算。\n携带价值：%d" % carried_value
	anchor_prompt.visible = true


func hide_anchor_prompt() -> void:
	anchor_prompt.visible = false


func show_end(warehouse_value: int) -> void:
	end_label.text = "本轮已撤离\n结算价值：%d" % warehouse_value
	end_panel.visible = true


func is_anchor_prompt_visible() -> bool:
	return anchor_prompt.visible
