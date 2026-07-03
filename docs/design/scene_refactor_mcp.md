# Design - Scene Refactor and MCP Setup

## Problem Definition
The previous prototype created too much of the game world inside one controller script and did not give a reliable first-screen visual read. The project also needs Codex configured for the local Godot MCP bridge in addition to the existing Godot AI bridge.

## Options Compared
| Option | Pros | Cons | Decision |
| --- | --- | --- | --- |
| Keep procedural construction in `RunSceneController` | Few files | Hard to inspect, hard to edit in Godot, poor ownership boundaries | Rejected |
| Move every object into hand-authored scene files and use a layout builder | Clear ownership, reusable entities, editor-visible scenes | More files | Used |
| Build a TileMap-first world now | Production-friendly map workflow | Adds tile pipeline before core loop is stable | Deferred |

## State Machine
Run states remain:
- `SEARCHING`
- `ANCHOR_PROMPT`
- `EXTRACTED`

Scene construction states:
- `UNBUILT`: run scene containers exist, no level instances.
- `BUILT`: layout has spawned player, props, pickups, anchor, and monsters.
- `WIRED`: spawned signals are connected to the run controller and HUD.

Events:
- `build_level`: `UNBUILT -> BUILT`.
- `wire_signals`: `BUILT -> WIRED`.
- `scene_load_failed`: remains in current construction state and fails validation.

Guards:
- Run state starts only after construction reaches `WIRED`.
- Extraction still requires `run_state == ANCHOR_PROMPT` and `player_on_anchor == true`.

Side effects:
- Codex user MCP config receives `godot-mcp = http://127.0.0.1:3000/mcp`.
- Run scene instances object scenes from `RunLayout`.

Failure and Rollback Paths:
- If MCP is unavailable, gameplay remains local but Codex cannot inspect the live editor bridge through that server.
- If a scene fails to load, headless acceptance fails before claiming the run is playable.
- Roll back by reverting the scene/script refactor and removing the `godot-mcp` entry.

## Impact
Affected:
- `project.godot` plugin/main-scene configuration.
- Codex user MCP config.
- Gameplay scene and script layout.
- Acceptance and technical docs.

Unaffected:
- Existing Godot MCP plugin source.
- Existing Godot AI plugin source.
- Persistent save data, because none exists yet.

## Primitive Acceptance Criteria
- `codex mcp list` shows `godot-ai` and `godot-mcp`.
- The run scene launches without script errors.
- Each gameplay entity type has a separate `.tscn`.
- The first rendered frame visibly contains placeholder actor, pickup, cover, monster vision, and HUD elements.
- Headless acceptance validates pickup, detection penalty, anchor choices, extraction, and monster vision guards.
