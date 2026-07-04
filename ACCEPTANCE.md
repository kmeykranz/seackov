# Acceptance

## Current Goal
Deliver a playable underwater treasure extraction prototype in Godot 4.7 with a debug-accessible boat scene and a minimal runtime backpack loop.

## Acceptance Criteria
- The project launches into the main menu, and `Dive In` enters one underwater run scene.
- The main menu includes a temporary debug button that enters the boat scene.
- Codex has both `godot-ai` and `godot-mcp` MCP servers configured for the local Godot editor bridges.
- The run scene contains visible player, treasure, cover, monster vision, and HUD placeholder art.
- Player, monster, treasure, anchor, solid cover, seaweed cover, and HUD are separate scenes instantiated into the run scene.
- The player can move around a bounded 2D sea-floor map with visible rocks, wreckage, and seaweed cover.
- Treasure pickups have common, rare, and legendary rarities, add their value to the carried haul, and have no capacity limit.
- A patrolling monster follows a fixed loop, uses a front-facing cone plus line-of-sight check, and does not detect the player when the player is hidden in seaweed or blocked by solid cover.
- When the monster detects or collides with the player, all currently carried treasure is cleared immediately while already banked treasure remains unchanged.
- The anchor exit only offers extraction choices while the player is standing in the anchor area.
- Choosing extraction at the anchor banks all carried treasure, moves recovered items into the cross-scene backpack, and returns to the boat scene.
- Choosing continue at the anchor hides the prompt and keeps the run playable.
- The boat scene contains a dive hatch, mission console, purifier device, upload device, and warehouse interaction areas.
- Pressing `B` in the boat scene opens or closes a grid storage UI showing backpack and warehouse slots.
- Interacting with the warehouse opens the storage UI.
- Storage slots show item icons and stack counts.
- Left-click takes or places a whole stack.
- Right-click takes half a stack when the hand is empty, or places one item when holding a stack.
- Shift-click quickly transfers a stack between backpack and warehouse.
- The upload device can move all backpack items into uploaded records and increase research points.
- The warehouse UI can receive item stacks from backpack click operations and can send them back.
- The implementation has a headless acceptance test covering scene loading, treasure collection, catch penalty, anchor extraction, boat inventory transfer, boat scene structure, monster vision guards, and scene split structure.

## Completion Measurement
Completion is measured by the criteria above. This prototype is complete when all criteria pass in local Godot 4.7 validation.
