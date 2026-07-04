# TRD - Run And Boat Inventory Implementation

## Engine
Godot 4.7 stable.

## Technical Approach
- `RunSceneController` owns run state, haul accounting, extraction choices, run backpack/minimap/pause UI toggling, region access refresh, depth-light filter updates, collision death, and signal wiring.
- `RunToolSystem` owns story knowledge discovery, selected tool state, preparation, per-run uses, cooldowns, and placeholder effects.
- `PlayerInventory` is a Godot autoload that owns runtime backpack, warehouse, uploaded records, research point totals, and slot-level add/remove operations.
- `ProgressState` is a Godot autoload that owns persistent region unlock state, uploaded legendary count, pending/uploaded knowledge, unlocked tools, and debug save mutation APIs.
- `BoatScene` owns the boat interaction zones and delegates item state changes to `PlayerInventory`.
- `StorageTransferUi` owns the centered storage panel, can show backpack-only or backpack/warehouse modes, creates fixed grid slots, tracks the temporary hand stack, and calls slot-level `PlayerInventory` methods.
- `StorageSlot` owns Godot `Control._gui_input` callbacks for one clickable grid cell.
- `RunLayout` provides region bounds, exactly seven anchor specs, and deterministic population generation for full-map cover, coral, treasure, chests, and patrol routes.
- `RunLevelBuilder` instantiates separate scenes into the run scene containers, generates segmented perimeter walls, configures player soft world bounds, builds coral and seaweed cover, and selects a random unlocked spawn anchor.
- `PlayerDiver` owns accelerated player movement, dash timing, camera limits, soft boundary response, and hidden-cover state.
- `PlayerDiver` also exposes movement slow/lock and item impulse hooks for prepared tools.
- `MonsterPatrol` owns patrol/chase behavior, line-of-sight detection, and stun/disarm/knockback/defeat hooks for tools.
- `PauseMenuUi` owns the paused overlay controls and keeps processing while the scene tree is paused.
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
- `scenes/props/coral.tscn`
- `scenes/props/chest_box.tscn`
- `scenes/ui/run_hud.tscn`
- `scenes/ui/storage_transfer_ui.tscn`
- `scenes/ui/minimap_ui.tscn`
- `scenes/ui/pause_menu_ui.tscn`
- `scenes/ui/fail.tscn`
- `scenes/boat_scene.tscn`

## Gameplay Scripts
- `scripts/items/run_tool_system.gd`

## MCP Configuration
- Godot AI plugin is enabled in `project.godot` and exposes `godot-ai` through `http://127.0.0.1:8000/mcp`.
- Codex global MCP config also contains `godot-mcp` through `http://127.0.0.1:3000/mcp`.

## Godot APIs Used
- `CharacterBody2D` and `move_and_slide()` for player and monster movement.
- `Vector2.move_toward()` for player acceleration, deceleration, and dash recovery.
- `Area2D` body overlap signals for treasure, anchor, seaweed, and monster contact checks.
- `Area2D` body overlap signals for boat interaction prompts.
- `Control._gui_input` and `InputEventMouseButton` for Minecraft-like inventory clicks.
- `Node._unhandled_input` and `InputEventKey` for `B` inventory toggles in run and boat scenes, `M` minimap toggles, and `Esc` pause toggles in the run scene.
- `SceneTree.paused` plus `Node.PROCESS_MODE_ALWAYS` for paused menu input and resume handling.
- `CanvasModulate.color` for the run scene depth filter.
- `FontFile` theme overrides for player-facing Chinese UI text.
- `Control` anchors and viewport sizing for centered floating panels.
- `Node._process` timers for tool preparation, cooldowns, temporary tool effect markers, and trap trigger scanning.
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
- Godot pausing games and process mode documentation: https://docs.godotengine.org/en/stable/tutorials/scripting/pausing_games.html
- Godot CanvasModulate documentation: https://docs.godotengine.org/en/stable/classes/class_canvasmodulate.html

## Collision Layers
- Layer 1: player.
- Layer 2: solid world cover and boundaries.
- Layer 3: monster bodies.
- Layer 4: treasure pickup areas.
- Layer 5: anchor exit area.
- Layer 6: seaweed hiding areas.

Monster bodies collide with world cover but not the player body; the monster catch `Area2D` still masks the player layer so contact opens the failure scene instead of causing a push-lock collision.

## Rollback
Revert the added gameplay `scenes/`, `scripts/`, `tests/`, `docs/` files and restore `project.godot` to the previous launch/plugin/autoload configuration. To roll back only the run backpack feature, remove the `StorageTransferUi` instance from `run_scene.tscn`, remove run-side `B` handling and immediate backpack writes from `RunSceneController`, and restore extraction-time backpack insertion. To roll back only persistent region progression, remove `ProgressState`, remove lobby debug save controls, restore single-anchor layout data, and remove run fog/soft-boundary handling. To roll back only the minimap, remove `MiniMapUi` from `run_scene.tscn`, remove `M` handling from `RunSceneController`, and delete the minimap UI scene/scripts. To roll back only the accelerated movement and soft perimeter, restore direct player velocity assignment, remove dash timers and soft world bounds from `PlayerDiver`, and change `RunLevelBuilder._spawn_boundaries()` back to four full-size wall specs. To roll back only map population generation, restore the previous static `RunLayout` arrays and remove coral spawning from `RunLevelBuilder`. To roll back only depth lighting, remove the depth-lighting methods from `RunSceneController` and restore the fixed `CanvasModulate.color` in `run_scene.tscn`. To roll back only the tool system, delete `RunToolSystem`, remove the run HUD tool panel, remove tool input forwarding and recovered-knowledge recording from `RunSceneController`, restore `BoatScene._upload_backpack()` to backpack-only upload, remove knowledge/tool fields from `ProgressState`, and remove tool effect hooks from `PlayerDiver` and `MonsterPatrol`. To roll back only collision death and pause, restore player/monster body collision masks, remove `PauseMenuUi`, remove `Esc` handling, and remove `clear_backpack()` use from `RunSceneController`. Remove the `godot-mcp` Codex MCP entry with `codex mcp remove godot-mcp` if the editor bridge is no longer needed.
