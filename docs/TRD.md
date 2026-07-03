# TRD - Single Run Implementation

## Engine
Godot 4.7 stable.

## Technical Approach
- `RunSceneController` owns only run state, haul accounting, extraction choices, and signal wiring.
- `RunLayout` provides explicit level data for bounds, spawns, cover, treasure, and patrol routes.
- `RunLevelBuilder` instantiates separate scenes into the run scene containers.
- `PlayerDiver` owns player movement, camera limits, and hidden-cover state.
- `MonsterPatrol` owns patrol/chase behavior and line-of-sight detection.
- `TreasurePickup` owns pickup collision and rarity value.
- `AnchorExit` owns anchor overlap signals.
- Prop and HUD scripts own their own placeholder presentation.

## Scene Split
- `scenes/actors/player_diver.tscn`
- `scenes/actors/monster_patrol.tscn`
- `scenes/pickups/treasure_pickup.tscn`
- `scenes/props/anchor_exit.tscn`
- `scenes/props/solid_cover.tscn`
- `scenes/props/seaweed_cover.tscn`
- `scenes/props/sea_floor.tscn`
- `scenes/ui/run_hud.tscn`

## MCP Configuration
- Godot AI plugin is enabled in `project.godot` and exposes `godot-ai` through `http://127.0.0.1:8000/mcp`.
- Codex global MCP config also contains `godot-mcp` through `http://127.0.0.1:3000/mcp`.

## Godot APIs Used
- `CharacterBody2D` and `move_and_slide()` for player and monster movement.
- `Area2D` body overlap signals for treasure, anchor, seaweed, and monster collision checks.
- `PhysicsRayQueryParameters2D` with `PhysicsDirectSpaceState2D.intersect_ray()` for solid-cover line-of-sight blocking.

## References
- Godot CharacterBody2D documentation: https://docs.godotengine.org/en/stable/classes/class_characterbody2d.html
- Godot Area2D documentation: https://docs.godotengine.org/en/stable/classes/class_area2d.html
- Godot ray-casting documentation: https://docs.godotengine.org/en/stable/tutorials/physics/ray-casting.html

## Collision Layers
- Layer 1: player.
- Layer 2: solid world cover and boundaries.
- Layer 3: monster bodies.
- Layer 4: treasure pickup areas.
- Layer 5: anchor exit area.
- Layer 6: seaweed hiding areas.

## Rollback
Revert the added gameplay `scenes/`, `scripts/`, `tests/`, `docs/` files and restore `project.godot` to the previous launch/plugin configuration. Remove the `godot-mcp` Codex MCP entry with `codex mcp remove godot-mcp` if the editor bridge is no longer needed.
