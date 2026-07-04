extends Control

@onready var _title_sprite: Sprite2D = $Title

# —— 沉重呼吸浮动参数 ——
var _base_position: Vector2
var _breath_time: float = 0.0
var _breath_period: float = 3.8          # 一次完整呼吸的秒数
var _breath_amplitude: float = 7.0        # 上下浮动像素幅度

# —— 剧烈震动参数 ——
var _is_shaking: bool = false
var _shake_time: float = 0.0
var _shake_duration: float = 0.35
var _shake_intensity: float = 16.0
var _shake_frequency: float = 28.0        # 每秒震动次数
var _time_until_next_shake: float = 0.0


func _ready() -> void:
	_base_position = _title_sprite.position
	# 初次震动在 6~14 秒后随机触发
	_time_until_next_shake = randf_range(6.0, 14.0)


func _process(delta: float) -> void:
	# —— 1. 呼吸浮动 ——
	_breath_time += delta
	var phase := sin(_breath_time * TAU / _breath_period)
	# 略微不对称：吸入慢、呼出快，用一个小偏移模拟沉重感
	var breath_y := _breath_amplitude * (phase + 0.15 * sin(phase * TAU))
	var offset := Vector2(0.0, breath_y)

	# —— 2. 随机剧烈震动 ——
	_time_until_next_shake -= delta
	if _time_until_next_shake <= 0.0 and not _is_shaking:
		# 触发震动
		_is_shaking = true
		_shake_time = 0.0
		_shake_duration = randf_range(0.2, 0.5)
		_shake_intensity = randf_range(12.0, 24.0)

	if _is_shaking:
		_shake_time += delta
		if _shake_time >= _shake_duration:
			# 震动结束，设置下一次触发时间
			_is_shaking = false
			_time_until_next_shake = randf_range(5.0, 16.0)
		else:
			# 震动随剩余时间衰减
			var decay := 1.0 - (_shake_time / _shake_duration)
			var sx := sin(_shake_time * _shake_frequency * TAU) * _shake_intensity * decay
			var sy := cos(_shake_time * _shake_frequency * 1.3 * TAU) * _shake_intensity * decay
			offset += Vector2(sx, sy)

	_title_sprite.position = _base_position + offset
