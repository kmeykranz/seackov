extends Node
class_name RunStorySystem

signal message_requested(message: String)
signal terminal_requested(text: String, speaker: String)
signal targets_changed

const INTERACT_KEY := KEY_E
const INTERACT_RADIUS := 190.0
const TUNNEL_TRIGGER_RADIUS := 300.0
const FONT_PATH := "res://assets/ZaoZiGongFangYingLiHeiGuiTi-1.otf"

const STAGE_SIGNAL := "signal_tower"
const STAGE_TUNNEL := "tunnel_repair"
const STAGE_RUINS := "ruins_investigation"
const STAGE_ESCAPE := "final_escape"

const EVENT_TUNNEL_ARRIVED := "tunnel_arrived"

const PRISM_DONE_TEXT := "\
“净化装置”重组完成，能量波形稳定。近海净化率97%，安全航道已清理。干得漂亮。前方峡谷入口已开启，准许进入中部海域。下一任务坐标已同步。

第二阶段任务发布：部署信号塔。
现在领取第二阶段任务物品——信号塔。你需要将两座塔分别部署到指定坐标：沉没大桥塔顶和深海火山口。部署期间必须持续操作，松开即重置进度。完成后将解锁深部海域。任务物品已装载至你的潜水器，出发。"

const SIGNAL_DONE_TEXT := "\
信号塔网络同步成功，深部海域已解锁。你现在可自行选择下潜点。下一个调查目标——深海平原边缘的废弃隧道，那里有异常能量波动。继续前进。

第三阶段任务发布：调查并修复隧道。
隧道已抵达后，侦测内部断裂点并修复关键结构，使探索船能够通过。注意隧道内可能有未知危险，请谨慎作业。"

const TUNNEL_ARRIVAL_TEXT := "\
隧道已抵达。我们侦测到内部多处断裂，疑似人为破坏。你的任务是修复关键结构，使探索船能够通过。注意隧道内可能有未知危险，请谨慎作业。"

const TUNNEL_DONE_TEXT := "\
隧道修复完成，探索船已就位，可辅助清除断崖附近黑雾——但注意，那并非永久清除。遗迹就在前方……我们接收到的信号有些不稳定，可能是地质干扰。请保持警惕。

最终阶段任务发布：进入遗迹深处，查明黑雾源头，并尽可能带回所有研究数据。怪潮活动频繁，确保撤离路线畅通。立即执行。"

const TRUTH_TEXT := "\
（实验室数据读取中……）

你已发现异常物体活动，快跑，我们无法净化它！
不执行将视为抗命。怪潮正在逼近，你只有一次撤离机会。带回真相，或者埋葬于此。"

const TARGET_DEFS := {
	"signal_bridge": {
		"stage": STAGE_SIGNAL,
		"label": "沉没大桥信号塔",
		"hint": "按住 E 部署信号塔",
		"position": Vector2(5180, 2060),
		"duration": 2.2,
		"color": Color(0.15, 0.85, 1.0, 0.38),
		"core": Color(0.65, 0.98, 1.0, 0.95),
		"kind": "signal",
	},
	"signal_volcano": {
		"stage": STAGE_SIGNAL,
		"label": "深海火山口信号塔",
		"hint": "按住 E 部署信号塔",
		"position": Vector2(6460, 4380),
		"duration": 2.2,
		"color": Color(1.0, 0.33, 0.08, 0.36),
		"core": Color(1.0, 0.72, 0.18, 0.95),
		"kind": "signal",
	},
	"tunnel_arrival": {
		"stage": STAGE_TUNNEL,
		"label": "异常隧道信号",
		"hint": "靠近触发扫描",
		"position": Vector2(2860, 4340),
		"duration": 0.0,
		"color": Color(0.42, 0.18, 1.0, 0.34),
		"core": Color(0.78, 0.62, 1.0, 0.95),
		"kind": "scan",
	},
	"tunnel_west": {
		"stage": STAGE_TUNNEL,
		"label": "隧道西侧断裂",
		"hint": "按住 E 修复结构",
		"position": Vector2(2700, 4050),
		"duration": 1.8,
		"color": Color(0.24, 0.9, 0.72, 0.36),
		"core": Color(0.74, 1.0, 0.86, 0.95),
		"kind": "repair",
	},
	"tunnel_core": {
		"stage": STAGE_TUNNEL,
		"label": "隧道核心梁",
		"hint": "按住 E 修复结构",
		"position": Vector2(2860, 4500),
		"duration": 1.8,
		"color": Color(0.24, 0.9, 0.72, 0.36),
		"core": Color(0.74, 1.0, 0.86, 0.95),
		"kind": "repair",
	},
	"tunnel_east": {
		"stage": STAGE_TUNNEL,
		"label": "隧道东侧断裂",
		"hint": "按住 E 修复结构",
		"position": Vector2(2520, 4860),
		"duration": 1.8,
		"color": Color(0.24, 0.9, 0.72, 0.36),
		"core": Color(0.74, 1.0, 0.86, 0.95),
		"kind": "repair",
	},
	"ruins_terminal": {
		"stage": STAGE_RUINS,
		"label": "遗迹电脑",
		"hint": "按住 E 读取数据",
		"position": Vector2(820, 3180),
		"duration": 1.2,
		"color": Color(0.05, 0.9, 0.38, 0.36),
		"core": Color(0.32, 1.0, 0.56, 0.95),
		"kind": "terminal",
	},
}

var player: PlayerDiver
var effect_parent: Node2D
var hud: CanvasLayer
var progress: Node

var _active_target_id: String = ""
var _holding_target_id: String = ""
var _hold_elapsed: float = 0.0
var _target_nodes := {}
var _target_fill_nodes := {}
var _temporary_nodes: Array[Dictionary] = []
var _pulse_time: float = 0.0
var _font: FontFile


func configure(new_player: PlayerDiver, new_effect_parent: Node2D, new_hud: CanvasLayer, new_progress: Node) -> void:
	set_process(true)
	player = new_player
	effect_parent = new_effect_parent
	hud = new_hud
	progress = new_progress
	_font = load(FONT_PATH)
	if progress != null and not progress.progress_changed.is_connected(refresh_targets):
		progress.progress_changed.connect(refresh_targets)
	refresh_targets()
	_update_hud()


func handle_key_event(event: InputEventKey) -> bool:
	if event.echo or event.keycode != INTERACT_KEY:
		return false
	if event.pressed:
		return begin_interaction()
	var had_hold := _holding_target_id != ""
	release_interaction()
	return had_hold


func begin_interaction() -> bool:
	if _holding_target_id != "":
		return true
	_update_active_target()
	if _active_target_id == "":
		return false
	var spec: Dictionary = TARGET_DEFS[_active_target_id]
	var duration := float(spec.get("duration", 0.0))
	if duration <= 0.0:
		return complete_target(_active_target_id)
	_holding_target_id = _active_target_id
	_hold_elapsed = 0.0
	if player != null:
		player.set_action_movement_locked(true)
	message_requested.emit("正在处理：%s。松开 E 会重置进度。" % String(spec["label"]))
	_update_hud()
	return true


func release_interaction() -> void:
	if _holding_target_id == "":
		return
	var spec: Dictionary = TARGET_DEFS[_holding_target_id]
	message_requested.emit("%s进度已重置。" % String(spec["label"]))
	_holding_target_id = ""
	_hold_elapsed = 0.0
	_clear_player_lock()
	_update_hud()


func cancel_interaction() -> void:
	_holding_target_id = ""
	_hold_elapsed = 0.0
	_clear_player_lock()
	_update_hud()


func complete_target(target_id: String) -> bool:
	if not _is_target_available(target_id):
		return false
	var completed := false
	match target_id:
		"signal_bridge", "signal_volcano":
			completed = _complete_signal_target(target_id)
		"tunnel_west", "tunnel_core", "tunnel_east":
			completed = _complete_tunnel_target(target_id)
		"ruins_terminal":
			completed = _complete_ruins_terminal()
		"tunnel_arrival":
			completed = _trigger_tunnel_arrival()
	if completed:
		_holding_target_id = ""
		_hold_elapsed = 0.0
		_clear_player_lock()
		refresh_targets()
	_update_hud()
	return completed


func has_target(target_id: String) -> bool:
	return _target_nodes.has(target_id)


func get_target_position(target_id: String) -> Vector2:
	if TARGET_DEFS.has(target_id):
		return Vector2(TARGET_DEFS[target_id]["position"])
	return Vector2.ZERO


func get_active_target_id() -> String:
	return _active_target_id


func get_hold_progress() -> float:
	if _holding_target_id == "":
		return 0.0
	var duration := maxf(0.01, float(TARGET_DEFS[_holding_target_id].get("duration", 0.0)))
	return clampf(_hold_elapsed / duration, 0.0, 1.0)


func get_minimap_targets() -> Array:
	var result := []
	for target_id in _target_nodes.keys():
		var target_key := String(target_id)
		var node: Node2D = _target_nodes[target_id]
		if not is_instance_valid(node):
			continue
		var spec := _minimap_spec_for_target(target_key)
		var target_color := Color(0.86, 0.98, 1.0, 1.0)
		if spec.has("core"):
			target_color = spec["core"]
		result.append({
			"id": target_key,
			"label": String(spec.get("label", "剧情目标")),
			"position": node.global_position,
			"color": target_color,
			"active": target_key == _active_target_id,
		})
	return result


func get_objective_title() -> String:
	match _stage():
		STAGE_SIGNAL:
			return "部署信号塔"
		STAGE_TUNNEL:
			return "修复海洋隧道"
		STAGE_RUINS:
			return "调查遗迹电脑"
		STAGE_ESCAPE:
			return "携带真相撤离"
	return "回收棱晶"


func refresh_targets() -> void:
	_clear_target_nodes()
	if effect_parent == null:
		return
	var stage := _stage()
	if stage == STAGE_SIGNAL:
		_spawn_target_if_needed("signal_bridge")
		_spawn_target_if_needed("signal_volcano")
	elif stage == STAGE_TUNNEL:
		if not _has_story_event(EVENT_TUNNEL_ARRIVED):
			_spawn_target_if_needed("tunnel_arrival")
		else:
			_spawn_target_if_needed("tunnel_west")
			_spawn_target_if_needed("tunnel_core")
			_spawn_target_if_needed("tunnel_east")
	elif stage == STAGE_RUINS or stage == STAGE_ESCAPE:
		_spawn_black_sphere()
		if stage == STAGE_RUINS:
			_spawn_target_if_needed("ruins_terminal")
	_update_hud()
	targets_changed.emit()


func _process(delta: float) -> void:
	_pulse_time += delta
	_update_tunnel_trigger()
	_update_active_target()
	_update_hold(delta)
	_update_target_visuals()
	_update_temporary_nodes(delta)
	_update_hud()


func _update_active_target() -> void:
	_active_target_id = ""
	if player == null:
		return
	var best_distance := INF
	for target_id in _target_nodes.keys():
		if target_id == "black_sphere":
			continue
		if not _is_target_available(String(target_id)):
			continue
		var position := get_target_position(String(target_id))
		var distance := player.global_position.distance_to(position)
		if distance <= INTERACT_RADIUS and distance < best_distance:
			best_distance = distance
			_active_target_id = String(target_id)


func _update_tunnel_trigger() -> void:
	if _stage() != STAGE_TUNNEL or _has_story_event(EVENT_TUNNEL_ARRIVED) or player == null:
		return
	var trigger_pos := get_target_position("tunnel_arrival")
	if player.global_position.distance_to(trigger_pos) <= TUNNEL_TRIGGER_RADIUS:
		complete_target("tunnel_arrival")


func _update_hold(delta: float) -> void:
	if _holding_target_id == "":
		return
	if _active_target_id != _holding_target_id:
		release_interaction()
		return
	_hold_elapsed += delta
	var duration := float(TARGET_DEFS[_holding_target_id].get("duration", 0.0))
	if _hold_elapsed >= duration:
		complete_target(_holding_target_id)


func _complete_signal_target(target_id: String) -> bool:
	if progress == null:
		return false
	var result: Dictionary = progress.deploy_signal_site(target_id)
	if not bool(result.get("changed", false)):
		return false
	message_requested.emit("%s部署完成。" % String(TARGET_DEFS[target_id]["label"]))
	_spawn_completion_burst(get_target_position(target_id), Color(0.3, 0.9, 1.0, 0.42))
	if bool(result.get("completed_stage", false)):
		terminal_requested.emit(SIGNAL_DONE_TEXT, "终端（总部）")
	return true


func _complete_tunnel_target(target_id: String) -> bool:
	if progress == null:
		return false
	var result: Dictionary = progress.repair_tunnel_site(target_id)
	if not bool(result.get("changed", false)):
		return false
	message_requested.emit("%s修复完成。" % String(TARGET_DEFS[target_id]["label"]))
	_spawn_completion_burst(get_target_position(target_id), Color(0.3, 1.0, 0.62, 0.42))
	if bool(result.get("completed_stage", false)):
		_spawn_clearing_beam()
		terminal_requested.emit(TUNNEL_DONE_TEXT, "终端（总部）")
	return true


func _complete_ruins_terminal() -> bool:
	if progress == null:
		return false
	var result: Dictionary = progress.start_final_escape()
	if not bool(result.get("changed", false)):
		return false
	_spawn_completion_burst(get_target_position("ruins_terminal"), Color(0.1, 1.0, 0.35, 0.46))
	terminal_requested.emit(TRUTH_TEXT, "终端")
	return true


func _trigger_tunnel_arrival() -> bool:
	if progress == null:
		return false
	progress.mark_story_event(EVENT_TUNNEL_ARRIVED)
	_spawn_completion_burst(get_target_position("tunnel_arrival"), Color(0.6, 0.45, 1.0, 0.42))
	terminal_requested.emit(TUNNEL_ARRIVAL_TEXT, "终端（总部）")
	return true


func _spawn_target_if_needed(target_id: String) -> void:
	if not _is_target_available(target_id):
		return
	_spawn_target_marker(target_id)


func _is_target_available(target_id: String) -> bool:
	if not TARGET_DEFS.has(target_id):
		return false
	var spec: Dictionary = TARGET_DEFS[target_id]
	if _stage() != String(spec["stage"]):
		return false
	if target_id == "signal_bridge" or target_id == "signal_volcano":
		return progress == null or not progress.is_signal_site_deployed(target_id)
	if target_id == "tunnel_arrival":
		return not _has_story_event(EVENT_TUNNEL_ARRIVED)
	if target_id == "tunnel_west" or target_id == "tunnel_core" or target_id == "tunnel_east":
		return _has_story_event(EVENT_TUNNEL_ARRIVED) and (progress == null or not progress.is_tunnel_site_repaired(target_id))
	if target_id == "ruins_terminal":
		return _stage() == STAGE_RUINS
	return true


func _spawn_target_marker(target_id: String) -> void:
	var spec: Dictionary = TARGET_DEFS[target_id]
	var marker := Node2D.new()
	marker.name = "StoryTarget_%s" % target_id
	marker.position = Vector2(spec["position"])
	marker.set_meta("story_target_id", target_id)
	effect_parent.add_child(marker)
	_target_nodes[target_id] = marker

	var ring := Polygon2D.new()
	ring.name = "Range"
	ring.color = Color(spec["color"])
	ring.polygon = _circle_points(96.0, 32)
	marker.add_child(ring)

	var core := Polygon2D.new()
	core.name = "Core"
	core.color = Color(spec["core"])
	core.polygon = _shape_points(String(spec.get("kind", "")))
	marker.add_child(core)

	var label := Label.new()
	label.name = "Label"
	label.position = Vector2(-155.0, -132.0)
	label.size = Vector2(310.0, 66.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = "%s\n%s" % [String(spec["label"]), String(spec["hint"])]
	label.add_theme_font_size_override("font_size", 22)
	if _font != null:
		label.add_theme_font_override("font", _font)
	marker.add_child(label)

	if float(spec.get("duration", 0.0)) > 0.0:
		var back := Polygon2D.new()
		back.name = "ProgressBack"
		back.position = Vector2(0.0, 74.0)
		back.color = Color(0.0, 0.0, 0.0, 0.62)
		back.polygon = _rect_points(Vector2(128.0, 14.0))
		marker.add_child(back)

		var fill := Polygon2D.new()
		fill.name = "ProgressFill"
		fill.position = Vector2(0.0, 74.0)
		fill.color = Color(0.7, 1.0, 0.86, 0.95)
		fill.polygon = _progress_rect_points(0.0)
		marker.add_child(fill)
		_target_fill_nodes[target_id] = fill


func _spawn_black_sphere() -> void:
	var marker := Node2D.new()
	marker.name = "StoryTarget_black_sphere"
	marker.position = Vector2(820, 2860)
	effect_parent.add_child(marker)
	_target_nodes["black_sphere"] = marker

	var halo := Polygon2D.new()
	halo.name = "BlackFogHalo"
	halo.color = Color(0.0, 0.0, 0.0, 0.54)
	halo.polygon = _circle_points(190.0, 40)
	marker.add_child(halo)

	var sphere := Polygon2D.new()
	sphere.name = "Cocoon"
	sphere.color = Color(0.015, 0.0, 0.025, 1.0)
	sphere.polygon = _circle_points(76.0, 32)
	marker.add_child(sphere)

	var label := Label.new()
	label.name = "Label"
	label.position = Vector2(-110.0, -150.0)
	label.size = Vector2(220.0, 42.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = "茧"
	label.add_theme_font_size_override("font_size", 30)
	if _font != null:
		label.add_theme_font_override("font", _font)
	marker.add_child(label)


func _update_target_visuals() -> void:
	for target_id in _target_nodes.keys():
		var node: Node2D = _target_nodes[target_id]
		if not is_instance_valid(node):
			continue
		var pulse := 1.0 + sin(_pulse_time * 3.0) * 0.035
		if String(target_id) == _active_target_id:
			pulse += 0.08
		node.scale = Vector2.ONE * pulse
	for target_id in _target_fill_nodes.keys():
		var fill: Polygon2D = _target_fill_nodes[target_id]
		if not is_instance_valid(fill):
			continue
		var progress_value := get_hold_progress() if String(target_id) == _holding_target_id else 0.0
		fill.polygon = _progress_rect_points(progress_value)


func _update_temporary_nodes(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	for item in _temporary_nodes:
		var node: Node = item["node"]
		if not is_instance_valid(node):
			continue
		var time_left := float(item["time"]) - delta
		if time_left <= 0.0:
			node.queue_free()
			continue
		item["time"] = time_left
		remaining.append(item)
	_temporary_nodes = remaining


func _spawn_completion_burst(position: Vector2, color: Color) -> void:
	if effect_parent == null:
		return
	var burst := Polygon2D.new()
	burst.name = "StoryCompletionBurst"
	burst.position = position
	burst.color = color
	burst.polygon = _circle_points(180.0, 32)
	effect_parent.add_child(burst)
	_temporary_nodes.append({"node": burst, "time": 0.65})


func _spawn_clearing_beam() -> void:
	if effect_parent == null:
		return
	var beam := Line2D.new()
	beam.name = "ExplorerClearingBeam"
	beam.width = 26.0
	beam.default_color = Color(0.55, 0.95, 1.0, 0.52)
	beam.points = PackedVector2Array([Vector2(1880, -120), Vector2(1880, 5980)])
	effect_parent.add_child(beam)
	_temporary_nodes.append({"node": beam, "time": 2.6})


func _update_hud() -> void:
	if hud == null or not hud.has_method("update_objective_status"):
		return
	var stage := _stage()
	var title := get_objective_title()
	var hint := ""
	var progress_value := -1.0
	if stage == "prism_recovery":
		hint = "回收并上传 2 个紫色历史遗物，修复净化装置。"
	elif stage == STAGE_SIGNAL:
		hint = "寻找蓝色/橙色标记，按住 E 部署两座信号塔。"
	elif stage == STAGE_TUNNEL:
		if not _has_story_event(EVENT_TUNNEL_ARRIVED):
			hint = "前往紫色异常隧道信号。"
		else:
			hint = "修复所有绿色隧道断裂标记。"
	elif stage == STAGE_RUINS:
		hint = "进入最深处，读取遗迹电脑。"
	elif stage == STAGE_ESCAPE:
		hint = "怪潮逼近，前往任意可用锚点撤离。"
	elif stage == "ending_success":
		hint = "真相已上传。"
	elif stage == "ending_failure":
		hint = "最终通讯已中断。"

	if _active_target_id != "":
		var spec: Dictionary = TARGET_DEFS[_active_target_id]
		hint = "%s：%s" % [String(spec["label"]), String(spec["hint"])]
	if _holding_target_id != "":
		progress_value = get_hold_progress()
	hud.update_objective_status(title, hint, progress_value)


func _clear_target_nodes() -> void:
	for node in _target_nodes.values():
		if is_instance_valid(node):
			node.queue_free()
	_target_nodes.clear()
	_target_fill_nodes.clear()
	_active_target_id = ""


func _clear_player_lock() -> void:
	if player != null:
		player.clear_action_movement_modifier()


func _minimap_spec_for_target(target_id: String) -> Dictionary:
	if target_id == "black_sphere":
		return {
			"label": "黑雾源头",
			"core": Color(0.42, 0.18, 0.58, 1.0),
		}
	if TARGET_DEFS.has(target_id):
		return TARGET_DEFS[target_id]
	return {
		"label": "剧情目标",
		"core": Color(0.86, 0.98, 1.0, 1.0),
	}


func _has_story_event(event_id: String) -> bool:
	return progress != null and progress.has_story_event(event_id)


func _stage() -> String:
	if progress == null or not progress.has_method("get_story_stage"):
		return "prism_recovery"
	return String(progress.get_story_stage())


func _circle_points(radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(count):
		var angle := TAU * float(index) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _shape_points(kind: String) -> PackedVector2Array:
	if kind == "signal":
		return PackedVector2Array([
			Vector2(-14, 54), Vector2(14, 54), Vector2(14, -24), Vector2(42, -24),
			Vector2(0, -70), Vector2(-42, -24), Vector2(-14, -24),
		])
	if kind == "repair":
		return PackedVector2Array([
			Vector2(-58, -12), Vector2(-12, -12), Vector2(-12, -58), Vector2(12, -58),
			Vector2(12, -12), Vector2(58, -12), Vector2(58, 12), Vector2(12, 12),
			Vector2(12, 58), Vector2(-12, 58), Vector2(-12, 12), Vector2(-58, 12),
		])
	if kind == "terminal":
		return PackedVector2Array([
			Vector2(-56, -38), Vector2(56, -38), Vector2(56, 34), Vector2(20, 34),
			Vector2(20, 58), Vector2(-20, 58), Vector2(-20, 34), Vector2(-56, 34),
		])
	return PackedVector2Array([Vector2(0, -62), Vector2(62, 0), Vector2(0, 62), Vector2(-62, 0)])


func _rect_points(size: Vector2) -> PackedVector2Array:
	var half := size * 0.5
	return PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])


func _progress_rect_points(value: float) -> PackedVector2Array:
	var width := 128.0
	var height := 14.0
	var clamped := clampf(value, 0.0, 1.0)
	var left := -width * 0.5
	var right := left + width * clamped
	var half_h := height * 0.5
	return PackedVector2Array([
		Vector2(left, -half_h),
		Vector2(right, -half_h),
		Vector2(right, half_h),
		Vector2(left, half_h),
	])
