# DesignSpec - Single Underwater Run

## Scene Composition
The run scene is a `Node2D` controlled by `RunSceneController`. It contains named world containers and an instanced HUD scene. `RunLevelBuilder` reads `RunLayout` data and instances separate actor, pickup, prop, and UI scenes into those containers.

## Module Responsibilities
- `RunSceneController`: run state, score/haul accounting, extraction choices, and actor signal wiring.
- `RunLayout`: explicit map bounds, spawn positions, cover specs, treasure specs, and monster patrol routes.
- `RunLevelBuilder`: scene instantiation from layout data into run scene containers.
- `PlayerDiver`: keyboard movement, current facing direction, and whether the player is hidden.
- `MonsterPatrol`: fixed waypoint patrol, chase recovery, front cone detection, and collision discovery.
- `TreasurePickup`: rarity value and one-time collection.
- `AnchorExit`: player overlap at extraction point.
- `RunHud`: status, messages, anchor prompt, and run-end panel.
- Prop scenes: visible placeholder art plus collision or cover behavior.

## Run State Machine
States:
- `SEARCHING`: Player can move, collect treasure, be detected, and enter the anchor.
- `ANCHOR_PROMPT`: Player is standing in the anchor area and can choose extract or continue.
- `EXTRACTED`: Carried treasure has been banked and the run is complete.

Events:
- `treasure_collected`: Adds pickup value to carried haul.
- `player_detected`: Clears carried haul.
- `anchor_entered`: `SEARCHING -> ANCHOR_PROMPT`.
- `anchor_exited`: `ANCHOR_PROMPT -> SEARCHING`.
- `continue_selected`: `ANCHOR_PROMPT -> SEARCHING`.
- `extract_selected`: `ANCHOR_PROMPT -> EXTRACTED`.

Guards:
- Extraction is ignored unless the anchor prompt is active and the player is still inside the anchor area.
- Detection is ignored after extraction.

Side Effects:
- Treasure collection removes the pickup from the map.
- Detection clears only carried treasure.
- Extraction moves carried treasure into the warehouse summary and disables active gameplay.

Failure and Rollback Paths:
- If detection happens with no carried treasure, state remains playable and no banked treasure changes.
- If the player leaves the anchor before choosing, the prompt closes and extraction cannot be confirmed.
- If extraction is chosen, the only in-run rollback is restarting/reloading the scene.

## Placeholder Art
Placeholder art is intentionally high-contrast and scene-local: cyan diver, red patrol, translucent red vision cone, yellow/blue/magenta treasure, green seaweed, teal reef, brown wreckage, and panel-backed HUD.

## Future Exploration Range
The current map layout is centralized in `RunLayout` as world bounds, cover rectangles, treasure spawns, and patrol paths. Expanding exploration later should start by changing those layout inputs and adding a progression event that reveals or unlocks new regions.
