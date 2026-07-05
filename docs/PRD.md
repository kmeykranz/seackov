# PRD - Single Underwater Run

## Objective
Implement one underwater run where the player collects recovered objects, avoids patrol monsters, extracts at an anchor, handles recovered items on the boat, and advances a persistent visual story campaign across the current map.

## Functional Requirements
- The game starts in the main menu.
- The main menu starts the boat scene, and the boat dive hatch enters the run scene.
- The main menu includes a temporary debug entry for the boat scene.
- The main menu includes debug save controls for resetting progression, adding uploaded legendary progress, unlocking the next region, and locking back to the start.
- A fresh save starts in the boat scene, disables player control, shakes the camera, and plays the opening terminal briefing.
- The player moves in 2D using keyboard input with smooth acceleration and deceleration.
- Pressing `Space` performs a short dash that gives an impulse and temporarily raises the maximum speed before curving back to normal movement.
- The map is bounded by segmented wall pieces and contains solid cover, coral cover, and seaweed hiding zones.
- The run scene depth filter is almost clear in the rightmost region and becomes progressively darker toward the leftmost region.
- Depth filter strength remains fixed inside each region and changes linearly only inside the boundary band between neighboring regions.
- The generated run layout has exactly seven authored anchors.
- Seaweed, coral, treasures, chests, and monsters populate the full authored map.
- Lower-x regions contain more chests, more monsters, and a more valuable treasure mix.
- A fresh save unlocks only the rightmost map region.
- Each run starts at a random anchor in the deepest unlocked region unless the player has manually selected an unlocked dive anchor.
- The selected spawn anchor is hidden and cannot be used for extraction in that run.
- Locked regions are hidden by fog and guarded by an elastic soft boundary that slows the player and rebounds them to roughly two body lengths outside the active boundary.
- The outer map perimeter also slows the player near the edge and pushes the player back inward.
- Pressing `M` in the run scene opens or closes a floating minimap showing full unlocked regions and current story target markers.
- Uploading two legendary items repairs the purifier, advances the story to signal tower deployment, and unlocks the second region permanently.
- Additional legendary uploads do not unlock deeper regions by themselves.
- Two visible signal tower targets appear on the current map and require holding `E` to deploy; releasing early resets progress.
- Deploying both signal towers unlocks the third region and enables a boat mission panel with task rows on the left and unlocked dive-anchor selection on the right.
- Approaching the tunnel target triggers hidden terminal dialogue and exposes tunnel repair markers.
- Repairing all tunnel markers unlocks the fourth region and exposes a ruins terminal plus black sphere placeholder.
- Reading the ruins terminal starts final escape with truth data.
- Story terminal text can be fast-forwarded while typing, but after the full text is visible it shows a hold-progress bar and only closes after holding `E` for one second.
- During final escape, death records a story failure ending and extraction marks final data as pending boat upload.
- Uploading final data on the boat records the success ending and shows a black crystal placeholder on the player.
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
- Interacting with the boat mission console opens a centered mission panel; before signal tower completion it previews locked spawn choices, and after signal tower completion it can save an unlocked dive anchor or restore default deepest-region random spawn.
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
- No final campaign art or fully authored biome scenes beyond current-map placeholders.
- No full save-game system beyond the small progression save.
- No combat or player attack.
- No new inventory capacity rules beyond the existing fixed prototype grid.
- No equipment exchange or upgrade shop yet.
