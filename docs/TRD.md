# TRD - Run And Boat Inventory Implementation

## Engine
Godot 4.7 stable.

## Technical Approach
- `RunSceneController` owns run state, haul accounting, extraction choices, run backpack/minimap UI toggling, region access refresh, and signal wiring.
- `PlayerInventory` is a Godot autoload that owns runtime backpack, warehouse, uploaded records, research point totals, and slot-level add/remove operations.
- `ProgressState` is a Godot autoload that owns persistent region unlock state, uploaded legendary count, and debug save mutation APIs.
- `BoatScene` owns the boat interaction zones and delegates item state changes to `PlayerInventory`.
- `StorageTransferUi` owns the storage panel, can show backpack-only or backpack/warehouse modes, creates fixed grid slots, tracks the temporary hand stack, and calls slot-level `PlayerInventory` methods.
- `StorageSlot` owns Godot `Control._gui_input` callbacks for one clickable grid cell.
- `RunLayout` provides explicit level data for region bounds, region anchors, cover, treasure, chests, and patrol routes.
- `RunLevelBuilder` instantiates separate scenes into the run scene containers and selects a random unlocked spawn anchor.
- `PlayerDiver` owns player movement, camera limits, and hidden-cover state.
- `MonsterPatrol` owns patrol/chase behavior and line-of-sight detection.
- `TreasurePickup` owns pickup collision and rarity value.
- `TreasureChest` owns one-time weighted random reward selection.
- `AnchorExit` owns anchor overlap signals.
- Prop and HUD scripts own their own placeholder presentation.

## Scene Split
- `scenes/actors/player_diver.tscn`
- `scenes/actors/monster_patrol.tscn`
- `scenes/pickups/treasure_pickup.tscn`
- `scenes/props/anchor_exit.tscn`
- `scenes/props/solid_cover.tscn`
- `scenes/props/seaweed_cover.tscn`
- `scenes/props/chest_box.tscn`
- `scenes/ui/run_hud.tscn`
- `scenes/ui/storage_transfer_ui.tscn`
- `scenes/ui/minimap_ui.tscn`
- `scenes/boat_scene.tscn`

## MCP Configuration
- Godot AI plugin is enabled in `project.godot` and exposes `godot-ai` through `http://127.0.0.1:8000/mcp`.
- Codex global MCP config also contains `godot-mcp` through `http://127.0.0.1:3000/mcp`.

## Godot APIs Used
- `CharacterBody2D` and `move_and_slide()` for player and monster movement.
- `Area2D` body overlap signals for treasure, anchor, seaweed, and monster collision checks.
- `Area2D` body overlap signals for boat interaction prompts.
- `Control._gui_input` and `InputEventMouseButton` for Minecraft-like inventory clicks.
- `Node._unhandled_input` and `InputEventKey` for `B` inventory toggles in run and boat scenes and `M` minimap toggles in the run scene.
- Project autoloads for runtime cross-scene inventory state.
- Project autoloads for persistent region progression state.
- `PhysicsRayQueryParameters2D` with `PhysicsDirectSpaceState2D.intersect_ray()` for solid-cover line-of-sight blocking.
- `FileAccess` and JSON dictionaries for the small progression save file.

## References
- Godot CharacterBody2D documentation: https://docs.godotengine.org/en/stable/classes/class_characterbody2d.html
- Godot Area2D documentation: https://docs.godotengine.org/en/stable/classes/class_area2d.html
- Godot Control documentation: https://docs.godotengine.org/en/stable/classes/class_control.html
- Godot InputEventMouseButton documentation: https://docs.godotengine.org/en/stable/classes/class_inputeventmousebutton.html
- Godot Singletons Autoload documentation: https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html
- Godot ray-casting documentation: https://docs.godotengine.org/en/stable/tutorials/physics/ray-casting.html

## Collision Layers
- Layer 1: player.
- Layer 2: solid world cover and boundaries.
- Layer 3: monster bodies.
- Layer 4: treasure pickup areas.
- Layer 5: anchor exit area.
- Layer 6: seaweed hiding areas.

## Rollback
Revert the added gameplay `scenes/`, `scripts/`, `tests/`, `docs/` files and restore `project.godot` to the previous launch/plugin/autoload configuration. To roll back only the run backpack feature, remove the `StorageTransferUi` instance from `run_scene.tscn`, remove run-side `B` handling and immediate backpack writes from `RunSceneController`, and restore extraction-time backpack insertion. To roll back only persistent region progression, remove `ProgressState`, remove lobby debug save controls, restore single-anchor layout data, and remove run fog/soft-boundary handling. To roll back only the minimap, remove `MiniMapUi` from `run_scene.tscn`, remove `M` handling from `RunSceneController`, and delete the minimap UI scene/scripts. Remove the `godot-mcp` Codex MCP entry with `codex mcp remove godot-mcp` if the editor bridge is no longer needed.
