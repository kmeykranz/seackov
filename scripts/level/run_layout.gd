extends RefCounted

const WORLD_RECT := Rect2(Vector2.ZERO, Vector2(10320, 5983))
const INITIAL_UNLOCKED_REGION_COUNT := 1
const SOFT_BOUNDARY_MARGIN := 520.0
const NO_SOFT_BOUNDARY_X := -1.0

const REGIONS := [
	{"id": 1, "name": "Coral Shelf", "x_min": 7786.0, "x_max": 10320.0},
	{"id": 2, "name": "Wreck Shelf", "x_min": 4284.0, "x_max": 7786.0},
	{"id": 3, "name": "Abyss Shelf", "x_min": 1882.0, "x_max": 4284.0},
	{"id": 4, "name": "Trench Core", "x_min": 0.0, "x_max": 1882.0},
]

const ANCHORS := [
	{"id": "coral_north", "region_id": 1, "position": Vector2(8450, 1250)},
	{"id": "coral_mid", "region_id": 1, "position": Vector2(9390, 3140)},
	{"id": "coral_south", "region_id": 1, "position": Vector2(10020, 4840)},
	{"id": "wreck_gate", "region_id": 2, "position": Vector2(7060, 1640)},
	{"id": "wreck_basin", "region_id": 2, "position": Vector2(5480, 4320)},
	{"id": "abyss_ridge", "region_id": 3, "position": Vector2(3180, 1320)},
	{"id": "trench_core", "region_id": 4, "position": Vector2(880, 3120)},
]

const REGION_POPULATION := {
	1: {"seaweed": 7, "coral": 6, "chests": 1, "monsters": 2, "treasures": {"common": 9, "rare": 3, "legendary": 2}},
	2: {"seaweed": 9, "coral": 8, "chests": 2, "monsters": 5, "treasures": {"common": 6, "rare": 8, "legendary": 4}},
	3: {"seaweed": 11, "coral": 10, "chests": 3, "monsters": 10, "treasures": {"common": 4, "rare": 10, "legendary": 8}},
	4: {"seaweed": 13, "coral": 12, "chests": 4, "monsters": 30, "treasures": {"common": 20, "rare": 20, "legendary": 20}},
}


static func build(unlocked_region_count: int = INITIAL_UNLOCKED_REGION_COUNT) -> Dictionary:
	var clamped_count := clampi(unlocked_region_count, INITIAL_UNLOCKED_REGION_COUNT, REGIONS.size())
	return {
		"world_rect": WORLD_RECT,
		"regions": get_regions(),
		"unlocked_region_count": clamped_count,
		"soft_boundary_x": soft_boundary_x_for_unlocked_count(clamped_count),
		"soft_boundary_margin": SOFT_BOUNDARY_MARGIN,
		"locked_region_rects": locked_region_rects_for_unlocked_count(clamped_count),
		"anchors": ANCHORS.duplicate(true),
		"chests": _generate_chests(),
		"solid_cover": _generate_solid_cover(),
		"seaweed": _generate_seaweed(),
		"coral": _generate_coral(),
		"treasures": _generate_treasures(),
		"monsters": _generate_monsters(),
	}


static func get_regions() -> Array:
	return REGIONS.duplicate(true)


static func get_anchor_count() -> int:
	return ANCHORS.size()


static func soft_boundary_x_for_unlocked_count(unlocked_region_count: int) -> float:
	var clamped_count := clampi(unlocked_region_count, INITIAL_UNLOCKED_REGION_COUNT, REGIONS.size())
	if clamped_count >= REGIONS.size():
		return NO_SOFT_BOUNDARY_X
	return float(REGIONS[clamped_count - 1]["x_min"])


static func locked_region_rects_for_unlocked_count(unlocked_region_count: int) -> Array:
	var clamped_count := clampi(unlocked_region_count, INITIAL_UNLOCKED_REGION_COUNT, REGIONS.size())
	var rects := []
	for region in REGIONS:
		if int(region["id"]) <= clamped_count:
			continue
		rects.append(Rect2(
			Vector2(float(region["x_min"]), WORLD_RECT.position.y),
			Vector2(float(region["x_max"]) - float(region["x_min"]), WORLD_RECT.size.y)
		))
	return rects


static func _generate_solid_cover() -> Array:
	var specs := []
	for region in REGIONS:
		var region_id := int(region["id"])
		var count := 3 + region_id
		for index in range(count):
			var kind := "wreck" if (index + region_id) % 3 == 0 else "reef"
			specs.append({
				"name": "Region%d%s%02d" % [region_id, "Wreck" if kind == "wreck" else "Reef", index],
				"region_id": region_id,
				"position": _position_in_region(region, index, count, 0.11),
				"size": Vector2(240.0 + float((index + region_id) % 4) * 42.0, 96.0 + float(index % 3) * 22.0),
				"kind": kind,
			})
	return specs


static func _generate_seaweed() -> Array:
	var specs := []
	for region in REGIONS:
		var region_id := int(region["id"])
		var count := int(REGION_POPULATION[region_id]["seaweed"])
		for index in range(count):
			specs.append({
				"name": "Region%dSeaweed%02d" % [region_id, index],
				"region_id": region_id,
				"position": _position_in_region(region, index, count, 0.37),
				"size": Vector2(190.0 + float(index % 4) * 32.0, 170.0 + float((index + 2) % 4) * 28.0),
			})
	return specs


static func _generate_coral() -> Array:
	var specs := []
	for region in REGIONS:
		var region_id := int(region["id"])
		var count := int(REGION_POPULATION[region_id]["coral"])
		for index in range(count):
			specs.append({
				"name": "Region%dCoral%02d" % [region_id, index],
				"region_id": region_id,
				"position": _position_in_region(region, index, count, 0.23),
				"size": Vector2(150.0 + float(index % 5) * 24.0, 120.0 + float((index + 1) % 4) * 26.0),
			})
	return specs


static func _generate_chests() -> Array:
	var specs := []
	for region in REGIONS:
		var region_id := int(region["id"])
		var count := int(REGION_POPULATION[region_id]["chests"])
		for index in range(count):
			specs.append({
				"region_id": region_id,
				"position": _position_in_region(region, index, count, 0.61),
			})
	return specs


static func _generate_treasures() -> Array:
	var specs := []
	for region in REGIONS:
		var region_id := int(region["id"])
		var rarity_counts: Dictionary = REGION_POPULATION[region_id]["treasures"]
		var rarity_list := _rarity_list(rarity_counts)
		for index in range(rarity_list.size()):
			specs.append({
				"region_id": region_id,
				"position": _position_in_region(region, index, rarity_list.size(), 0.49),
				"rarity": rarity_list[index],
			})
	return specs


static func _generate_monsters() -> Array:
	var specs := []
	for region in REGIONS:
		var region_id := int(region["id"])
		var count := int(REGION_POPULATION[region_id]["monsters"])
		for index in range(count):
			var center := _position_in_region(region, index, count, 0.73)
			var width := 340.0 + float(region_id) * 60.0
			var height := 250.0 + float((index + region_id) % 3) * 80.0
			specs.append({
				"region_id": region_id,
				"name": "Region%dPatrol%02d" % [region_id, index],
				"points": _patrol_loop(center, width, height, region),
			})
	return specs


static func _rarity_list(rarity_counts: Dictionary) -> Array:
	var result := []
	for rarity in ["common", "rare", "legendary"]:
		for index in range(int(rarity_counts.get(rarity, 0))):
			result.append(rarity)
	return result


static func _position_in_region(region: Dictionary, index: int, count: int, offset: float) -> Vector2:
	var usable_left := float(region["x_min"]) + 220.0
	var usable_right := float(region["x_max"]) - 220.0
	var usable_top := WORLD_RECT.position.y + 520.0
	var usable_bottom := WORLD_RECT.end.y - 520.0
	var spread_count := maxf(1.0, float(count))
	var x_seed := fmod((float(index) * 0.61803398875) + offset, 1.0)
	var y_seed := fmod((float(index % 7) / 7.0) + offset * 0.73 + float(index / 7) * 0.19, 1.0)
	if count == 1:
		x_seed = 0.5
	var x := lerpf(usable_left, usable_right, clampf((x_seed * spread_count + 0.5) / (spread_count + 1.0) + x_seed * 0.12, 0.08, 0.92))
	var y := lerpf(usable_top, usable_bottom, clampf(y_seed, 0.08, 0.92))
	return Vector2(x, y)


static func _patrol_loop(center: Vector2, width: float, height: float, region: Dictionary) -> Array:
	var min_x := float(region["x_min"]) + 180.0
	var max_x := float(region["x_max"]) - 180.0
	var min_y := WORLD_RECT.position.y + 420.0
	var max_y := WORLD_RECT.end.y - 420.0
	var half_size := Vector2(width, height) * 0.5
	return [
		Vector2(clampf(center.x - half_size.x, min_x, max_x), clampf(center.y - half_size.y, min_y, max_y)),
		Vector2(clampf(center.x + half_size.x, min_x, max_x), clampf(center.y - half_size.y, min_y, max_y)),
		Vector2(clampf(center.x + half_size.x, min_x, max_x), clampf(center.y + half_size.y, min_y, max_y)),
		Vector2(clampf(center.x - half_size.x, min_x, max_x), clampf(center.y + half_size.y, min_y, max_y)),
	]
