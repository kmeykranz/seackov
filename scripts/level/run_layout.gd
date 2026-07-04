extends RefCounted

const WORLD_RECT := Rect2(Vector2.ZERO, Vector2(5000, 5000))


static func build() -> Dictionary:
	return {
		"world_rect": WORLD_RECT,
		"player_spawn": Vector2(200, 320),
		"anchor_spawn": Vector2(2020, 1160),
		"chests": [
			{"position": Vector2(430, 360)},
		],
		"solid_cover": [
			{"name": "North Reef", "position": Vector2(520, 260), "size": Vector2(260, 110), "kind": "reef"},
			{"name": "Wreck Bow", "position": Vector2(970, 520), "size": Vector2(360, 95), "kind": "wreck"},
			{"name": "Reef Gate", "position": Vector2(600, 880), "size": Vector2(280, 130), "kind": "reef"},
			{"name": "Broken Hull", "position": Vector2(1570, 330), "size": Vector2(320, 110), "kind": "wreck"},
			{"name": "Deep Rock", "position": Vector2(1450, 930), "size": Vector2(240, 120), "kind": "reef"},
			{"name": "Anchor Rubble", "position": Vector2(1810, 1010), "size": Vector2(160, 95), "kind": "wreck"},
		],
		"seaweed": [
			{"name": "West Grass", "position": Vector2(330, 650), "size": Vector2(210, 210)},
			{"name": "Center Grass", "position": Vector2(1180, 790), "size": Vector2(280, 180)},
			{"name": "East Grass", "position": Vector2(1790, 630), "size": Vector2(210, 240)},
			{"name": "South Grass", "position": Vector2(930, 1110), "size": Vector2(240, 160)},
		],
		"treasures": [
			{"position": Vector2(290, 300), "rarity": "common"},
			{"position": Vector2(760, 190), "rarity": "common"},
			{"position": Vector2(1190, 220), "rarity": "rare"},
			{"position": Vector2(1820, 250), "rarity": "common"},
			{"position": Vector2(360, 1030), "rarity": "rare"},
			{"position": Vector2(920, 900), "rarity": "common"},
			{"position": Vector2(1300, 1080), "rarity": "rare"},
			{"position": Vector2(1710, 820), "rarity": "common"},
			{"position": Vector2(1960, 1090), "rarity": "legendary"},
		],
		"monsters": [
			{
				"name": "Patrol Angler",
				"points": [
					Vector2(680, 390),
					Vector2(1260, 390),
					Vector2(1260, 700),
					Vector2(680, 700),
				],
			},
			{
				"name": "Anchor Guard",
				"points": [
					Vector2(1490, 1080),
					Vector2(1900, 1080),
					Vector2(1900, 790),
					Vector2(1490, 790),
				],
			},
		],
	}
