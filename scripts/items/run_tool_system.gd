extends Node
class_name RunToolSystem

signal message_requested(message: String)

const USE_KEY := KEY_Q
const PREPARE_SPEED_MULTIPLIER := 0.42
const INFINITE_USES := -1
const TOOL_ORDER := [
	"toxin_net",
	"turtle_armor",
	"propeller",
	"freeze_trap",
	"magma_bomb",
	"electric_whip",
]
const TOOL_DEFS := {
	"toxin_net": {"label": "毒素网", "uses": 1, "prepare": 0.55, "cooldown": 0.0, "mode": "release"},
	"turtle_armor": {"label": "海龟盔甲", "uses": 1, "prepare": 0.0, "cooldown": 0.0, "mode": "instant"},
	"propeller": {"label": "螺旋桨推进器", "uses": INFINITE_USES, "prepare": 0.35, "cooldown": 3.0, "mode": "release"},
	"freeze_trap": {"label": "急冻陷阱", "uses": 1, "prepare": 1.0, "cooldown": 0.0, "mode": "deploy"},
	"magma_bomb": {"label": "岩浆炸弹", "uses": 1, "prepare": 0.5, "cooldown": 0.0, "mode": "release"},
	"electric_whip": {"label": "电鞭", "uses": INFINITE_USES, "prepare": 0.45, "cooldown": 5.0, "mode": "release"},
}
const REGION_KNOWLEDGE := {
	1: ["mangrove_toxins"],
	2: ["shipwreck_drive"],
	3: ["cold_current", "volcano_heat"],
	4: ["turtle_shell", "electric_eel"],
}
const KNOWLEDGE_LABELS := {
	"mangrove_toxins": "红树林毒素知识",
	"shipwreck_drive": "沉船推进结构知识",
	"cold_current": "寒冷海域结晶知识",
	"volcano_heat": "海底火山热流知识",
	"turtle_shell": "海龟甲壳结构知识",
	"electric_eel": "电鳗放电知识",
}

var player: PlayerDiver
var monsters: Array = []
var regions: Array = []
var effect_parent: Node2D
var hud: CanvasLayer
var progress: Node

var _unlocked_tool_ids: Array[String] = []
var _run_knowledge_ids: Array[String] = []
var _tool_counts := {}
var _cooldowns := {}
var _selected_index: int = 0
var _using_tool_id: String = ""
var _use_elapsed: float = 0.0
var _armor_active: bool = false
var _active_traps: Array = []
var _markers: Array = []


func configure(new_player: PlayerDiver, new_monsters: Array, new_regions: Array, new_effect_parent: Node2D, new_hud: CanvasLayer, new_progress: Node) -> void:
	player = new_player
	monsters = new_monsters
	regions = new_regions
	effect_parent = new_effect_parent
	hud = new_hud
	progress = new_progress
	sync_unlocked_tools()
	_update_hud()


func sync_unlocked_tools() -> void:
	_unlocked_tool_ids.clear()
	if progress != null and progress.has_method("get_unlocked_tool_ids"):
		for id in progress.get_unlocked_tool_ids():
			var tool_id := String(id)
			if TOOL_DEFS.has(tool_id):
				_unlocked_tool_ids.append(tool_id)

	for tool_id in _unlocked_tool_ids:
		if not _tool_counts.has(tool_id):
			_tool_counts[tool_id] = int(TOOL_DEFS[tool_id]["uses"])
		if not _cooldowns.has(tool_id):
			_cooldowns[tool_id] = 0.0

	if _selected_index >= _unlocked_tool_ids.size():
		_selected_index = maxi(0, _unlocked_tool_ids.size() - 1)
	_update_hud()


func handle_key_event(event: InputEventKey) -> bool:
	if event.echo:
		return false

	if event.pressed:
		var number_index := _number_key_index(event.keycode)
		if number_index >= 0:
			select_tool_index(number_index)
			return true

	if event.keycode == USE_KEY:
		if event.pressed:
			begin_use()
		else:
			release_use()
		return true

	return false


func select_tool_index(index: int) -> bool:
	if index < 0 or index >= _unlocked_tool_ids.size():
		return false
	_selected_index = index
	_update_hud()
	_emit_message("已选择%s。" % _tool_label(get_selected_tool_id()))
	return true


func select_tool_by_id(tool_id: String) -> bool:
	var index := _unlocked_tool_ids.find(tool_id)
	return select_tool_index(index)


func get_selected_tool_id() -> String:
	if _unlocked_tool_ids.is_empty():
		return ""
	return _unlocked_tool_ids[clampi(_selected_index, 0, _unlocked_tool_ids.size() - 1)]


func get_unlocked_tool_ids() -> Array[String]:
	return _unlocked_tool_ids.duplicate()


func get_run_knowledge_ids() -> Array[String]:
	return _run_knowledge_ids.duplicate()


func get_tool_count(tool_id: String) -> int:
	return int(_tool_counts.get(tool_id, 0))


func get_tool_cooldown(tool_id: String) -> float:
	return float(_cooldowns.get(tool_id, 0.0))


func is_armor_active() -> bool:
	return _armor_active


func begin_use() -> bool:
	if _using_tool_id != "":
		return false

	var tool_id := get_selected_tool_id()
	if tool_id == "":
		_emit_message("还没有可用道具。")
		return false
	if not _can_use_tool(tool_id):
		_update_hud()
		return false

	var mode := String(TOOL_DEFS[tool_id]["mode"])
	if mode == "instant":
		return activate_tool(tool_id)

	_using_tool_id = tool_id
	_use_elapsed = 0.0
	if mode == "deploy":
		player.set_action_movement_locked(true)
	else:
		player.set_action_speed_multiplier(PREPARE_SPEED_MULTIPLIER)
	_emit_message("正在准备%s，松开 Q 触发。" % _tool_label(tool_id))
	_update_hud()
	return true


func release_use() -> bool:
	if _using_tool_id == "":
		return false

	var tool_id := _using_tool_id
	var prepare_time := float(TOOL_DEFS[tool_id]["prepare"])
	var mode := String(TOOL_DEFS[tool_id]["mode"])
	_clear_player_action_modifier()
	_using_tool_id = ""
	if _use_elapsed < prepare_time:
		_emit_message("%s准备中断。" % _tool_label(tool_id))
		_use_elapsed = 0.0
		_update_hud()
		return true

	_use_elapsed = 0.0
	if mode == "deploy":
		return activate_tool(tool_id)
	return activate_tool(tool_id)


func cancel_use() -> void:
	_using_tool_id = ""
	_use_elapsed = 0.0
	_clear_player_action_modifier()
	_update_hud()


func activate_tool(tool_id: String) -> bool:
	if not _can_use_tool(tool_id):
		_update_hud()
		return false

	var activated := false
	match tool_id:
		"toxin_net":
			activated = _activate_toxin_net()
		"turtle_armor":
			activated = _activate_turtle_armor()
		"propeller":
			activated = _activate_propeller()
		"freeze_trap":
			activated = _activate_freeze_trap()
		"magma_bomb":
			activated = _activate_magma_bomb()
		"electric_whip":
			activated = _activate_electric_whip()

	if activated:
		_consume_or_cooldown(tool_id)
	_update_hud()
	return activated


func try_block_damage() -> bool:
	if not _armor_active:
		return false

	_armor_active = false
	var affected := 0
	for monster in _monsters_in_radius(player.global_position, 270.0):
		if monster.has_method("apply_knockback"):
			monster.apply_knockback(player.global_position, 680.0)
			affected += 1
	_spawn_marker(player.global_position, 280.0, Color(0.34, 0.9, 0.82, 0.34), 0.35)
	_emit_message("海龟盔甲挡下一次伤害并震退 %d 个敌人，盔甲已损坏。" % affected)
	_update_hud()
	return true


func flush_recovered_knowledge() -> Array[String]:
	var recovered := _run_knowledge_ids.duplicate()
	_run_knowledge_ids.clear()
	_update_hud()
	return recovered


func _process(delta: float) -> void:
	_update_cooldowns(delta)
	_update_preparation(delta)
	_update_traps()
	_update_markers(delta)
	_discover_current_region_knowledge()


func _update_cooldowns(delta: float) -> void:
	for tool_id in _cooldowns.keys():
		_cooldowns[tool_id] = maxf(0.0, float(_cooldowns[tool_id]) - delta)


func _update_preparation(delta: float) -> void:
	if _using_tool_id == "":
		return

	_use_elapsed += delta
	var prepare_time := float(TOOL_DEFS[_using_tool_id]["prepare"])
	if String(TOOL_DEFS[_using_tool_id]["mode"]) == "deploy" and _use_elapsed >= prepare_time:
		var tool_id := _using_tool_id
		_using_tool_id = ""
		_use_elapsed = 0.0
		_clear_player_action_modifier()
		activate_tool(tool_id)
	_update_hud()


func _discover_current_region_knowledge() -> void:
	if player == null or progress == null:
		return

	var region_id := _region_id_for_x(player.global_position.x)
	if not REGION_KNOWLEDGE.has(region_id):
		return

	for knowledge_id in REGION_KNOWLEDGE[region_id]:
		if _run_knowledge_ids.has(knowledge_id):
			continue
		if progress.has_method("has_knowledge") and progress.has_knowledge(knowledge_id):
			continue
		_run_knowledge_ids.append(knowledge_id)
		_emit_message("获得知识：%s。成功撤离并上传后可解锁相关道具。" % _knowledge_label(knowledge_id))
	_update_hud()


func _activate_toxin_net() -> bool:
	var direction := _player_facing()
	var targets := _monsters_in_cone(player.global_position, direction, 430.0, 70.0)
	for monster in targets:
		if monster.has_method("apply_disarm"):
			monster.apply_disarm(4.0)
	_spawn_marker(player.global_position + direction * 210.0, 230.0, Color(0.42, 1.0, 0.34, 0.34), 0.45)
	_emit_message("毒素网命中 %d 个敌人，短时间缴械。" % targets.size())
	return true


func _activate_turtle_armor() -> bool:
	if _armor_active:
		_emit_message("海龟盔甲已经穿戴。")
		return false
	_armor_active = true
	_spawn_marker(player.global_position, 120.0, Color(0.28, 0.95, 0.72, 0.3), 0.35)
	_emit_message("已穿上海龟盔甲，可抵挡一次怪物接触伤害。")
	return true


func _activate_propeller() -> bool:
	var direction := _player_facing()
	player.trigger_dash(direction)
	if player.has_method("apply_item_impulse"):
		player.apply_item_impulse(direction, 820.0)
	_spawn_marker(player.global_position + direction * 110.0, 150.0, Color(0.22, 0.72, 1.0, 0.32), 0.3)
	_emit_message("螺旋桨推进器启动。")
	return true


func _activate_freeze_trap() -> bool:
	var marker := _spawn_marker(player.global_position, 74.0, Color(0.38, 0.82, 1.0, 0.46), 999.0)
	_active_traps.append({
		"position": player.global_position,
		"radius": 185.0,
		"marker": marker,
	})
	_emit_message("急冻陷阱已布设。")
	return true


func _activate_magma_bomb() -> bool:
	var direction := _player_facing()
	var impact := player.global_position + direction * 300.0
	var targets := _monsters_in_radius(impact, 190.0)
	for monster in targets:
		if monster.has_method("defeat"):
			monster.defeat()
	_spawn_marker(impact, 200.0, Color(1.0, 0.25, 0.08, 0.42), 0.45)
	_emit_message("岩浆炸弹清除了 %d 个敌人。" % targets.size())
	return true


func _activate_electric_whip() -> bool:
	var direction := _player_facing()
	var target: Node = _first_monster_in_cone(player.global_position, direction, 390.0, 42.0)
	if target != null and target.has_method("apply_stun"):
		target.apply_stun(3.0)
		_emit_message("电鞭命中并控制 1 个敌人。")
	else:
		_emit_message("电鞭挥空。")
	_spawn_marker(player.global_position + direction * 190.0, 100.0, Color(0.72, 0.55, 1.0, 0.36), 0.28)
	return true


func _update_traps() -> void:
	var remaining := []
	for trap in _active_traps:
		var trap_position: Vector2 = trap["position"]
		var radius := float(trap["radius"])
		var triggered := false
		for monster in _valid_monsters():
			if monster.global_position.distance_to(trap_position) <= radius:
				triggered = true
				break
		if triggered:
			var count := 0
			for monster in _monsters_in_radius(trap_position, radius):
				if monster.has_method("apply_stun"):
					monster.apply_stun(5.0)
					count += 1
			if is_instance_valid(trap["marker"]):
				trap["marker"].queue_free()
			_spawn_marker(trap_position, radius, Color(0.48, 0.86, 1.0, 0.45), 0.5)
			_emit_message("急冻陷阱触发，控制 %d 个敌人。" % count)
		else:
			remaining.append(trap)
	_active_traps = remaining


func _update_markers(delta: float) -> void:
	var remaining := []
	for marker_data in _markers:
		var marker = marker_data["node"]
		if not is_instance_valid(marker):
			continue
		var time_left := float(marker_data["time"]) - delta
		if time_left <= 0.0:
			marker.queue_free()
			continue
		marker_data["time"] = time_left
		remaining.append(marker_data)
	_markers = remaining


func _consume_or_cooldown(tool_id: String) -> void:
	var uses := int(_tool_counts.get(tool_id, 0))
	if uses > 0:
		_tool_counts[tool_id] = uses - 1
	var cooldown := float(TOOL_DEFS[tool_id]["cooldown"])
	if cooldown > 0.0:
		_cooldowns[tool_id] = cooldown


func _can_use_tool(tool_id: String) -> bool:
	if not _unlocked_tool_ids.has(tool_id):
		_emit_message("尚未解锁%s。" % _tool_label(tool_id))
		return false
	var uses := int(_tool_counts.get(tool_id, 0))
	if uses == 0:
		_emit_message("%s本次下潜已经用完。" % _tool_label(tool_id))
		return false
	if float(_cooldowns.get(tool_id, 0.0)) > 0.0:
		_emit_message("%s冷却中：%.1f 秒。" % [_tool_label(tool_id), float(_cooldowns[tool_id])])
		return false
	return true


func _update_hud() -> void:
	if hud == null or not hud.has_method("update_tool_status"):
		return

	if _unlocked_tool_ids.is_empty():
		hud.update_tool_status("道具：未解锁", "探索并上传知识后解锁。")
		return

	var tool_id := get_selected_tool_id()
	var label := _tool_label(tool_id)
	var count_text := _count_text(tool_id)
	var cooldown := float(_cooldowns.get(tool_id, 0.0))
	var title := "道具 %d/%d：%s  次数：%s" % [_selected_index + 1, _unlocked_tool_ids.size(), label, count_text]
	var hint := "数字键选择，按住 Q 准备/部署。"
	if _armor_active:
		hint = "海龟盔甲已穿戴，可抵挡一次接触伤害。"
	elif _using_tool_id != "":
		var prepare_time := maxf(0.01, float(TOOL_DEFS[_using_tool_id]["prepare"]))
		var percent := clampf(_use_elapsed / prepare_time, 0.0, 1.0)
		hint = "准备%s：%d%%" % [_tool_label(_using_tool_id), int(roundf(percent * 100.0))]
	elif cooldown > 0.0:
		hint = "%s冷却中：%.1f 秒。" % [label, cooldown]
	hud.update_tool_status(title, hint)


func _count_text(tool_id: String) -> String:
	var uses := int(_tool_counts.get(tool_id, 0))
	return "无限" if uses == INFINITE_USES else str(uses)


func _tool_label(tool_id: String) -> String:
	return String(TOOL_DEFS.get(tool_id, {}).get("label", tool_id))


func _knowledge_label(knowledge_id: String) -> String:
	return String(KNOWLEDGE_LABELS.get(knowledge_id, knowledge_id))


func _player_facing() -> Vector2:
	if player == null:
		return Vector2.RIGHT
	var direction := player.facing
	return Vector2.RIGHT if direction == Vector2.ZERO else direction.normalized()


func _clear_player_action_modifier() -> void:
	if player == null:
		return
	player.clear_action_movement_modifier()


func _monsters_in_radius(center: Vector2, radius: float) -> Array:
	var result := []
	for monster in _valid_monsters():
		if monster.global_position.distance_to(center) <= radius:
			result.append(monster)
	return result


func _monsters_in_cone(origin: Vector2, direction: Vector2, max_range: float, angle_degrees: float) -> Array:
	var result := []
	var forward := direction.normalized()
	var half_angle := deg_to_rad(angle_degrees * 0.5)
	for monster in _valid_monsters():
		var to_monster: Vector2 = monster.global_position - origin
		if to_monster.length() > max_range or to_monster.length() <= 0.01:
			continue
		if absf(forward.angle_to(to_monster.normalized())) <= half_angle:
			result.append(monster)
	return result


func _first_monster_in_cone(origin: Vector2, direction: Vector2, max_range: float, angle_degrees: float):
	var closest = null
	var closest_distance := INF
	for monster in _monsters_in_cone(origin, direction, max_range, angle_degrees):
		var distance: float = monster.global_position.distance_to(origin)
		if distance < closest_distance:
			closest = monster
			closest_distance = distance
	return closest


func _valid_monsters() -> Array:
	var result := []
	for monster in monsters:
		if not is_instance_valid(monster) or monster.is_queued_for_deletion() or not monster.is_inside_tree():
			continue
		result.append(monster)
	monsters = result
	return result


func _spawn_marker(center: Vector2, radius: float, color: Color, duration: float) -> Polygon2D:
	if effect_parent == null:
		return null
	var marker := Polygon2D.new()
	marker.position = center
	marker.color = color
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	marker.polygon = points
	effect_parent.add_child(marker)
	_markers.append({"node": marker, "time": duration})
	return marker


func _region_id_for_x(x_position: float) -> int:
	for region in regions:
		if x_position >= float(region["x_min"]) and x_position <= float(region["x_max"]):
			return int(region["id"])
	return 1


func _number_key_index(keycode: Key) -> int:
	match keycode:
		KEY_1:
			return 0
		KEY_2:
			return 1
		KEY_3:
			return 2
		KEY_4:
			return 3
		KEY_5:
			return 4
		KEY_6:
			return 5
	return -1


func _emit_message(message: String) -> void:
	message_requested.emit(message)
