extends CanvasLayer
class_name TerminalIntro

## 终端风格开场独白 —— 打字机逐字输出
## 点击或按任意键可跳过 / 快进

signal intro_finished

const FULL_TEXT := "\
欢迎回来，希望你没有被撞失忆。
几百年前，我们的母星因资源滥用和环境崩溃，所有陆地沉入海底，人类被迫移居太空。
如今我们回来了，但地球已被一种名为“黑雾”的未知物质笼罩——海洋表面和海底都受其侵蚀。
降落冲击导致“净化器装置，两块棱晶零件散落在附近海底。
你的首要任务：回收棱晶，修复装置。附近浅海已部分净化，搜索范围已标记。立即出发。
哦对了，进入新的区域或者遇到奇怪的生物会自动扫描并获取知识，上传可进行研究。"

const CHAR_INTERVAL: float = 0.06         # 每字间隔（秒）
const PUNCTUATION_PAUSE: float = 0.28      # 标点后额外停顿
const LINE_PAUSE: float = 0.35             # 换行后额外停顿

var _displayed_count: int = 0
var _timer: float = 0.0
var _finished: bool = false
var _can_dismiss: bool = false
var _dismiss_cooldown: float = 0.0
var _cursor_visible: bool = true
var _cursor_timer: float = 0.0

var _text_label: RichTextLabel
var _click_hint: Label


func _init() -> void:
	layer = 256
	_build_ui()


func _ready() -> void:
	_text_label.text = ""
	_click_hint.visible = false
	_timer = 0.3


func _build_ui() -> void:
	# 深色遮罩
	var overlay := ColorRect.new()
	overlay.name = "Overlay"
	overlay.offset_right = 1920.0
	overlay.offset_bottom = 1080.0
	overlay.color = Color(0.02, 0.06, 0.08, 0.92)
	add_child(overlay)

	# 终端面板
	var panel := Panel.new()
	panel.name = "Panel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -380.0
	panel.offset_top = -280.0
	panel.offset_right = 380.0
	panel.offset_bottom = 280.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.09, 0.05, 0.96)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.13, 0.95, 0.33, 0.45)
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	# 边距容器
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	# 文字标签
	_text_label = RichTextLabel.new()
	_text_label.name = "TextLabel"
	_text_label.bbcode_enabled = true
	_text_label.fit_content = true
	_text_label.scroll_active = false
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_color_override("font_color", Color(0.13, 0.95, 0.33, 1))
	_text_label.add_theme_font_size_override("normal_font_size", 18)
	var font: FontFile = load("res://assets/ZaoZiGongFangYingLiHeiGuiTi-1.otf")
	if font != null:
		_text_label.add_theme_font_override("normal_font", font)
	margin.add_child(_text_label)

	# "点击继续" 提示
	_click_hint = Label.new()
	_click_hint.name = "ClickHint"
	_click_hint.visible = false
	_click_hint.anchor_left = 0.5
	_click_hint.anchor_right = 0.5
	_click_hint.anchor_bottom = 1.0
	_click_hint.offset_left = -120.0
	_click_hint.offset_top = -52.0
	_click_hint.offset_right = 120.0
	_click_hint.offset_bottom = -28.0
	_click_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_click_hint.text = "点击任意位置继续..."
	_click_hint.add_theme_color_override("font_color", Color(0.13, 0.95, 0.33, 0.6))
	_click_hint.add_theme_font_size_override("font_size", 16)
	if font != null:
		_click_hint.add_theme_font_override("font", font)
	add_child(_click_hint)


func _process(delta: float) -> void:
	if _finished:
		# 闪烁光标 + 等待点击关闭
		_cursor_timer += delta
		if _cursor_timer >= 0.5:
			_cursor_timer = 0.0
			_cursor_visible = not _cursor_visible
			_append_cursor()
		_dismiss_cooldown = maxf(0.0, _dismiss_cooldown - delta)
		if _can_dismiss and _dismiss_cooldown <= 0.0:
			_click_hint.visible = true
		return

	_timer -= delta
	if _timer > 0.0:
		return

	if _displayed_count >= FULL_TEXT.length():
		_finish_typewriter()
		return

	_displayed_count += 1
	var shown := FULL_TEXT.substr(0, _displayed_count)
	_text_label.text = shown + "[color=#00ff4488]█[/color]"

	# 计算下一字间隔
	var next_char := FULL_TEXT[_displayed_count] if _displayed_count < FULL_TEXT.length() else ""
	var wait := CHAR_INTERVAL
	if next_char in "，。！？、；：\n":
		wait += PUNCTUATION_PAUSE
	if next_char == "\n":
		wait += LINE_PAUSE
	_timer = wait


func _input(event: InputEvent) -> void:
	if _finished:
		if event is InputEventMouseButton and event.pressed:
			_dismiss()
		elif event is InputEventKey and event.pressed:
			_dismiss()
		return

	if event is InputEventMouseButton and event.pressed:
		_skip_to_end()
	elif event is InputEventKey and event.pressed:
		_skip_to_end()


func _skip_to_end() -> void:
	_displayed_count = FULL_TEXT.length()
	_text_label.text = FULL_TEXT
	_finish_typewriter()


func _finish_typewriter() -> void:
	_finished = true
	_can_dismiss = true
	_dismiss_cooldown = 0.6
	_text_label.text = FULL_TEXT
	# 不附加光标，等待 _process 中闪烁


func _append_cursor() -> void:
	if _cursor_visible:
		_text_label.text = FULL_TEXT + "[color=#00ff4488]█[/color]"
	else:
		_text_label.text = FULL_TEXT + " "


func _dismiss() -> void:
	if not _can_dismiss:
		return
	# 淡出动画
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.35)
	tween.tween_callback(func() -> void:
		intro_finished.emit()
		queue_free()
	)
