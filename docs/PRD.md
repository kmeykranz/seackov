# PRD - Single Underwater Run

## Objective
Implement one underwater run where the player collects recovered objects, avoids a patrolling monster, extracts at an anchor, and can inspect/store/upload recovered items on a debug-accessible boat scene.

## Functional Requirements
- The game starts in the main menu.
- The main menu can start the run scene.
- The main menu includes a temporary debug entry for the boat scene.
- The main menu includes debug save controls for resetting progression, adding uploaded legendary progress, unlocking the next region, and locking back to the start.
- The player moves in 2D using keyboard input with smooth acceleration and deceleration.
- Pressing `Space` performs a short dash that gives an impulse and temporarily raises the maximum speed before curving back to normal movement.
- The map is bounded by segmented wall pieces and contains solid cover, coral cover, and seaweed hiding zones.
- The run scene depth filter is almost clear in the rightmost region and becomes progressively darker toward the leftmost region.
- Depth filter strength remains fixed inside each region and changes linearly only inside the boundary band between neighboring regions.
- The generated run layout has exactly seven authored anchors.
- Seaweed, coral, treasures, chests, and monsters populate the full authored map.
- Lower-x regions contain more chests, more monsters, and a more valuable treasure mix.
- A fresh save unlocks only the rightmost map region.
- Each run starts at a random anchor from unlocked regions.
- The selected spawn anchor is hidden and cannot be used for extraction in that run.
- Locked regions are hidden by fog and guarded by an elastic soft boundary that slows the player and rebounds them to roughly two body lengths outside the active boundary.
- The outer map perimeter also slows the player near the edge and pushes the player back inward.
- Pressing `M` in the run scene opens or closes a floating minimap showing full unlocked regions.
- Uploading two legendary items unlocks the second region permanently; each additional two uploaded legendary items unlocks one more region until the authored regions are open.
- Entering mapped story regions discovers knowledge, but knowledge only unlocks tools after successful extraction and boat upload.
- The run HUD shows selected tool, uses, cooldown, and preparation progress.
- Number keys select unlocked tools, and holding `Q` prepares or deploys the selected tool.
- Toxic net is a consumable prepared tool that disarms monsters in front of the player.
- Turtle armor can be equipped, blocks one monster-contact death, knocks back nearby monsters, and then breaks.
- Propeller booster is a reusable prepared tool that gives a forward burst and then enters cooldown.
- Freeze trap is a consumable hold-to-deploy tool that locks player movement during deployment and stuns monsters in range when triggered.
- Magma bomb is a consumable prepared tool that removes monsters in a small blast radius.
- Electric whip is a reusable charged tool that stuns the first monster in front and then enters cooldown.
- Treasures are visible pickups with common, rare, and legendary rarities.
- Pressing `B` in the run scene opens or closes a backpack-only grid UI.
- Collecting treasure increases the carried haul and places the item into the backpack immediately.
- Opening a chest grants one random item rarity and places that item into the backpack immediately.
- Monster patrol uses fixed waypoints.
- Monster detection requires player to be inside the front cone, within range, not hidden, and not blocked by solid cover.
- Monster sight detection clears the carried haul and removes current-run carried items from the backpack.
- Monster contact empties the backpack, ends the run, and opens the failure scene.
- The failure scene can return the player to the boat scene.
- Pressing `Esc` in the run scene opens a pause menu with resume, settings, and exit-to-main-menu options.
- The pause menu must not provide a return-to-ship option.
- Pause, minimap, storage, anchor prompt, and failure overlays use the main menu Chinese font where they show text, and centered modal panels are centered in the viewport.
- The anchor shows extract/continue choices only while the player is inside the anchor area.
- Extracting banks carried treasure, keeps recovered backpack items without duplicating them, and returns to the boat scene.
- Continuing closes the prompt and keeps the run active.
- The boat scene includes a dive hatch that can enter the run scene for testing.
- The boat scene includes a mission console, purifier device, upload device, and warehouse interaction area.
- Pressing `B` in the boat scene opens or closes the backpack and warehouse grid storage UI.
- Interacting with the warehouse opens the same storage UI.
- Storage slots show item icons and stack counts.
- Picking up a stack shows the held item icon and count next to the mouse cursor.
- Left-click takes or places a whole stack.
- Right-click takes half a stack when the hand is empty, or places one item when holding a stack.
- Holding the shift key while clicking quickly transfers a stack between backpack and warehouse.
- Different item types cannot merge into the same grid slot; left-click swaps them instead.
- The upload interaction moves all backpack items into uploaded records and increases research points.
- Player-facing UI copy is Chinese except keyboard key names and proper nouns.

## Non-Functional Requirements
- Use Godot 4.7-compatible GDScript and built-in 2D nodes.
- Keep run logic local to the run scene and keep cross-scene item/progression state in small autoloads.
- Keep future exploration expansion data-driven enough to adjust bounds, obstacles, and spawns without changing actor behavior.

## Exclusions
- No full ship-to-run campaign routing.
- No full save-game system beyond the small progression save.
- No combat or player attack.
- No new inventory capacity rules beyond the existing fixed prototype grid.
- No equipment exchange or upgrade shop yet.
