extends Control

@onready var _title_sprite: Sprite2D = $Title
@onready var _debug_panel: Panel = $DebugPanel
@onready var _progress_label: Label = $DebugPanel/ProgressLabel

# —— 沉重呼吸浮动参数 ——
var _base_position: Vector2
var _breath_time: float = 0.0
var _breath_period: float = 3.8          # 一次完整呼吸的秒数
var _breath_amplitude: float = 7.0        # 上下浮动像素幅度

# —— 深海沉重冲击参数 ——
# 震动分为三个阶段：
#   1. 冲击（~0.1s）  — 急速下坠 + 高频微颤，模拟被重物撞击
#   2. 深涌（~0.6s）  — 低频大幅度起伏，模拟水下冲击波传递
#   3. 余荡（~1.5s）  — 缓慢衰减摆动，模拟重物沉入深海后水体的回稳
var _is_shaking: bool = false
var _shake_time: float = 0.0
var _shake_duration: float = 1.5                    # 总持续时间
var _shake_impulse: float = 22.0                    # 首击下沉像素
var _shake_rumble_freq: float = 3.8                 # 深涌频率 (Hz)
var _shake_jitter_freq: float = 22.0                # 冲击微颤频率 (Hz)
var _shake_rotation_amp: float = 0.04               # 最大旋转弧度
var _time_until_next_shake: float = 0.0


func _ready() -> void:
	_base_position = _title_sprite.position
	# 初次震动在 6~14 秒后随机触发
	_time_until_next_shake = randf_range(3.0, 8.0)

	# —— 背景音乐（autoload 单例，场景切换不中断） ——
	var music_manager = _music_manager()
	if music_manager != null:
		music_manager.play_lobby_music()

	# —— 按钮信号连接 ——
	$start.pressed.connect(_on_start_pressed)
	$boat_debug.pressed.connect(_on_boat_debug_pressed)
	$save_debug.pressed.connect(_on_save_debug_pressed)
	$reset.pressed.connect(func() -> void: perform_debug_save_action("reset"))
	$DebugPanel/ResetSaveButton.pressed.connect(func() -> void: perform_debug_save_action("reset"))
	$DebugPanel/AddLegendaryButton.pressed.connect(func() -> void: perform_debug_save_action("add_uploaded_legendary"))
	$DebugPanel/UnlockNextButton.pressed.connect(func() -> void: perform_debug_save_action("unlock_next"))
	$DebugPanel/LockStartButton.pressed.connect(func() -> void: perform_debug_save_action("lock_start"))
	$about.pressed.connect(_on_about_pressed)
	$quit.pressed.connect(_on_quit_pressed)
	var progress = _progress()
	if progress != null and not progress.progress_changed.is_connected(_update_progress_debug):
		progress.progress_changed.connect(_update_progress_debug)
	_update_progress_debug()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/boat_scene.tscn")


func _on_boat_debug_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/boat_scene.tscn")


func _on_save_debug_pressed() -> void:
	_debug_panel.visible = not _debug_panel.visible
	_update_progress_debug()


func perform_debug_save_action(action: String) -> bool:
	var progress = _progress()
	if progress == null:
		return false

	match action:
		"reset":
			progress.reset_save()
			var inventory: Node = get_node_or_null("/root/PlayerInventory")
			if inventory != null and inventory.has_method("reset_runtime_state"):
				inventory.reset_runtime_state()
		"add_uploaded_legendary":
			progress.add_uploaded_legendary_progress(1)
		"unlock_next":
			progress.unlock_next_region()
		"lock_start":
			progress.lock_to_start_region()
		_:
			return false

	_update_progress_debug()
	return true


func is_debug_panel_visible() -> bool:
	return _debug_panel.visible


func _on_about_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/about.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _process(delta: float) -> void:
	# —— 1. 呼吸浮动 ——
	_breath_time += delta
	var phase := sin(_breath_time * TAU / _breath_period)
	# 略微不对称：吸入慢、呼出快，用一个小偏移模拟沉重感
	var breath_y := _breath_amplitude * (phase + 0.15 * sin(phase * TAU))
	var offset := Vector2(0.0, breath_y)

	# —— 2. 随机深海冲击 ——
	_time_until_next_shake -= delta
	if _time_until_next_shake <= 0.0 and not _is_shaking:
		_is_shaking = true
		_shake_time = 0.0
		_shake_duration = randf_range(1.2, 2.0)
		_shake_impulse = randf_range(18.0, 32.0)

	if _is_shaking:
		_shake_time += delta
		if _shake_time >= _shake_duration:
			_is_shaking = false
			_time_until_next_shake = randf_range(4.0, 10.0)
		else:
			var t := _shake_time / _shake_duration  # 0→1 归一化时间

			# —— 阶段 1：冲击微颤（前 12% 时间，快速衰减） ——
			var jitter_decay := exp(-t * 28.0)       # 极快衰减
			var jitter_x := sin(_shake_time * _shake_jitter_freq * TAU) * _shake_impulse * 0.4 * jitter_decay
			var jitter_y := cos(_shake_time * _shake_jitter_freq * 1.7 * TAU) * _shake_impulse * 0.6 * jitter_decay

			# —— 阶段 2：深涌（全程，慢衰减） ——
			var rumble_decay := exp(-t * 1.8)
			var rumble_x := sin(_shake_time * _shake_rumble_freq * TAU + 1.2) * _shake_impulse * 0.35 * rumble_decay
			var rumble_y := cos(_shake_time * _shake_rumble_freq * 0.7 * TAU) * _shake_impulse * 0.7 * rumble_decay

			# —— 阶段 3：重力下坠偏移 ——
			# 冲击瞬间向下沉，然后缓慢浮回（非对称，模拟深海重压）
			var sink := -_shake_impulse * 0.5 * exp(-t * 3.5) * (1.0 - t * 0.7)

			# —— 旋转：冲击时歪斜，之后缓慢摆正 ——
			var rot := sin(_shake_time * _shake_rumble_freq * 0.55 * TAU) * _shake_rotation_amp * rumble_decay

			offset += Vector2(jitter_x + rumble_x, jitter_y + rumble_y + sink)
			_title_sprite.rotation = rot
			_title_sprite.position = _base_position + offset
			return  # 跳过下面的统一赋值，因为震动帧已单独处理

	_title_sprite.rotation = 0.0
	_title_sprite.position = _base_position + offset


func _update_progress_debug() -> void:
	var progress = _progress()
	if progress == null:
		_progress_label.text = "进度存档不可用"
		return
	_progress_label.text = progress.get_summary_text()


func _music_manager():
	return get_node_or_null("/root/MusicManager")


func _progress():
	return get_node_or_null("/root/ProgressState")
