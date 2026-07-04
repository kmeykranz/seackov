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

const CHESTS := [
	{"region_id": 1, "position": Vector2(9000, 2540)},
	{"region_id": 2, "position": Vector2(6060, 2580)},
]

const SOLID_COVER := [
	{"name": "North Reef", "region_id": 1, "position": Vector2(8280, 1480), "size": Vector2(260, 110), "kind": "reef"},
	{"name": "Wreck Bow", "region_id": 1, "position": Vector2(9090, 2140), "size": Vector2(360, 95), "kind": "wreck"},
	{"name": "Reef Gate", "region_id": 1, "position": Vector2(10060, 3540), "size": Vector2(280, 130), "kind": "reef"},
	{"name": "Broken Hull", "region_id": 1, "position": Vector2(9700, 4720), "size": Vector2(320, 110), "kind": "wreck"},
	{"name": "Signal Debris", "region_id": 2, "position": Vector2(6940, 1850), "size": Vector2(380, 110), "kind": "wreck"},
	{"name": "Lava Rock", "region_id": 2, "position": Vector2(6040, 4020), "size": Vector2(280, 140), "kind": "reef"},
	{"name": "Deep Rock", "region_id": 3, "position": Vector2(3120, 3300), "size": Vector2(240, 120), "kind": "reef"},
	{"name": "Tunnel Rubble", "region_id": 4, "position": Vector2(980, 3580), "size": Vector2(320, 130), "kind": "wreck"},
]

const SEAWEED := [
	{"name": "West Grass", "region_id": 1, "position": Vector2(8360, 3360), "size": Vector2(210, 210)},
	{"name": "Center Grass", "region_id": 1, "position": Vector2(9260, 3700), "size": Vector2(280, 180)},
	{"name": "East Grass", "region_id": 1, "position": Vector2(10120, 2840), "size": Vector2(210, 240)},
	{"name": "South Grass", "region_id": 1, "position": Vector2(8660, 4960), "size": Vector2(240, 160)},
	{"name": "Wreck Kelp", "region_id": 2, "position": Vector2(6540, 3060), "size": Vector2(260, 220)},
	{"name": "Abyss Kelp", "region_id": 3, "position": Vector2(2680, 2220), "size": Vector2(260, 220)},
]

const TREASURES := [
	{"region_id": 1, "position": Vector2(8220, 1160), "rarity": "common"},
	{"region_id": 1, "position": Vector2(8760, 1660), "rarity": "common"},
	{"region_id": 1, "position": Vector2(9350, 1860), "rarity": "rare"},
	{"region_id": 1, "position": Vector2(10040, 2360), "rarity": "common"},
	{"region_id": 1, "position": Vector2(8680, 3060), "rarity": "rare"},
	{"region_id": 1, "position": Vector2(9200, 3560), "rarity": "common"},
	{"region_id": 1, "position": Vector2(9620, 4120), "rarity": "legendary"},
	{"region_id": 1, "position": Vector2(10030, 4660), "rarity": "common"},
	{"region_id": 1, "position": Vector2(8220, 4880), "rarity": "legendary"},
	{"region_id": 2, "position": Vector2(7080, 1460), "rarity": "rare"},
	{"region_id": 2, "position": Vector2(6200, 2520), "rarity": "common"},
	{"region_id": 2, "position": Vector2(5480, 4180), "rarity": "rare"},
	{"region_id": 3, "position": Vector2(3180, 1260), "rarity": "legendary"},
]

const MONSTERS := [
	{
		"region_id": 1,
		"name": "Patrol Angler",
		"points": [
			Vector2(8360, 2140),
			Vector2(9420, 2140),
			Vector2(9420, 2980),
			Vector2(8360, 2980),
		],
	},
	{
		"region_id": 1,
		"name": "Anchor Guard",
		"points": [
			Vector2(9000, 4380),
			Vector2(10040, 4380),
			Vector2(10040, 5160),
			Vector2(9000, 5160),
		],
	},
	{
		"region_id": 2,
		"name": "Wreck Watcher",
		"points": [
			Vector2(5480, 2160),
			Vector2(7060, 2160),
			Vector2(7060, 3440),
			Vector2(5480, 3440),
		],
	},
]


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
		"chests": CHESTS.duplicate(true),
		"solid_cover": SOLID_COVER.duplicate(true),
		"seaweed": SEAWEED.duplicate(true),
		"treasures": TREASURES.duplicate(true),
		"monsters": MONSTERS.duplicate(true),
	}


static func get_regions() -> Array:
	return REGIONS.duplicate(true)


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
