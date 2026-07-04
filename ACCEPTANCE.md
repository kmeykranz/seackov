# Acceptance

## Current Goal
Deliver a playable underwater treasure extraction prototype in Godot 4.7 with a persistent region progression loop, a debug-accessible boat scene, and a minimal runtime backpack loop.

## Acceptance Criteria
- The project launches into the main menu, and `Dive In` enters one underwater run scene.
- The main menu includes a temporary debug button that enters the boat scene.
- The main menu includes a debug save menu that can reset progression, add uploaded legendary progress, unlock the next region, and lock progression back to the starting region.
- Codex has both `godot-ai` and `godot-mcp` MCP servers configured for the local Godot editor bridges.
- The run scene contains visible player, treasure, cover, coral, monster vision, HUD placeholder art, pause menu, and a backpack-only inventory UI.
- Player, monster, treasure, chest, anchor, solid cover, seaweed cover, coral cover, HUD, and pause menu are separate scenes instantiated into the run scene.
- The player accelerates and decelerates smoothly around a bounded 2D sea-floor map with visible rocks, wreckage, and seaweed cover.
- Pressing `Space` gives the player a short curved dash boost that temporarily raises the maximum speed before returning to normal.
- The generated run layout has exactly seven authored anchors.
- Seaweed, coral, treasures, chests, and monsters are distributed across the full authored map, not only the starting region.
- Lower-x regions contain more chests, denser monsters, and a more valuable treasure mix than the rightmost starting region.
- A fresh save starts with only the rightmost map region unlocked.
- The run starts at a random authored anchor from unlocked regions.
- The selected spawn anchor is not visible and cannot be used for extraction in that run.
- Locked regions are covered by fog and blocked by an elastic soft boundary that slows the player and rebounds them to roughly two body lengths outside the active boundary instead of using a hard wall.
- The outer map boundary is built from visible segmented wall pieces, and approaching the boundary slows and pushes the player back inward.
- Pressing `M` in the run scene opens or closes a floating minimap that shows the full unlocked regions.
- Uploading two legendary items unlocks the second region permanently; each additional two uploaded legendary items unlocks the next region until all authored regions are open.
- Pressing `B` in the run scene opens or closes a grid backpack UI that does not show warehouse slots.
- Treasure pickups have common, rare, and legendary rarities, add their value to the carried haul, enter the backpack immediately, and have no capacity limit.
- Opening a chest grants one random item rarity and places that item into the backpack immediately.
- A patrolling monster follows a fixed loop, uses a front-facing cone plus line-of-sight check, and does not detect the player when the player is hidden in seaweed or blocked by solid cover.
- When the monster sees the player, all current-run carried treasure is cleared from the haul and backpack immediately while already banked, warehouse, and uploaded treasure remains unchanged.
- When the player touches a monster, the backpack is emptied, gameplay ends, and the failure scene opens.
- The failure scene has a return button that sends the player back to the boat.
- Pressing `Esc` opens a pause menu with resume, settings, and exit-to-main-menu options, and no return-to-ship option.
- The anchor exit only offers extraction choices while the player is standing in the anchor area.
- Choosing extraction at the anchor banks all carried treasure, keeps recovered items already in the cross-scene backpack without duplicating them, and returns to the boat scene.
- Choosing continue at the anchor hides the prompt and keeps the run playable.
- The boat scene contains a dive hatch, mission console, purifier device, upload device, and warehouse interaction areas.
- Pressing `B` in the boat scene opens or closes a grid storage UI showing backpack and warehouse slots.
- Interacting with the warehouse opens the storage UI.
- Storage slots show item icons and stack counts.
- Picking up a stack shows the held item icon and count next to the mouse cursor.
- Left-click takes or places a whole stack.
- Right-click takes half a stack when the hand is empty, or places one item when holding a stack.
- Shift-click quickly transfers a stack between backpack and warehouse.
- Different item types cannot merge into the same grid slot; left-click swaps them instead.
- The upload device can move all backpack items into uploaded records and increase research points.
- The warehouse UI can receive item stacks from backpack click operations and can send them back.
- The implementation has a headless acceptance test covering scene loading, map population distribution, treasure collection, region progression, minimap UI, pause UI, run backpack UI, random chest rewards, sight penalty, monster collision death, anchor extraction, boat inventory transfer, boat scene structure, monster vision guards, debug save controls, and scene split structure.

## Completion Measurement
Completion is measured by the criteria above. This prototype is complete when all criteria pass in local Godot 4.7 validation.
