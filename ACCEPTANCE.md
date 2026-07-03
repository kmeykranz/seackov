# Acceptance

## Current Goal
Deliver a playable single-run underwater treasure extraction prototype in Godot 4.7. The ship scene is out of scope.

## Acceptance Criteria
- The project launches into one underwater run scene.
- Codex has both `godot-ai` and `godot-mcp` MCP servers configured for the local Godot editor bridges.
- The first rendered frame contains visible player, treasure, cover, monster vision, and HUD placeholder art.
- Player, monster, treasure, anchor, solid cover, seaweed cover, sea floor, and HUD are separate scenes instantiated into the run scene.
- The player can move around a bounded 2D sea-floor map with visible rocks, wreckage, and seaweed cover.
- Treasure pickups have common, rare, and legendary rarities, add their value to the carried haul, and have no capacity limit.
- A patrolling monster follows a fixed loop, uses a front-facing cone plus line-of-sight check, and does not detect the player when the player is hidden in seaweed or blocked by solid cover.
- When the monster detects or collides with the player, all currently carried treasure is cleared immediately while already banked treasure remains unchanged.
- The anchor exit only offers extraction choices while the player is standing in the anchor area.
- Choosing extraction at the anchor banks all carried treasure to the run warehouse summary and ends the run.
- Choosing continue at the anchor hides the prompt and keeps the run playable.
- The implementation has a headless acceptance test covering scene loading, treasure collection, catch penalty, anchor extraction, monster vision guards, and scene split structure.

## Completion Measurement
Completion is measured by the criteria above. This prototype is complete when all criteria pass in local Godot 4.7 validation.
