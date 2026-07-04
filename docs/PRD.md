# PRD - Single Underwater Run

## Objective
Implement one underwater run where the player collects recovered objects, avoids a patrolling monster, extracts at an anchor, and can inspect/store/upload recovered items on a debug-accessible boat scene.

## Functional Requirements
- The game starts in the main menu.
- The main menu can start the run scene.
- The main menu includes a temporary debug entry for the boat scene.
- The player moves in 2D using keyboard input.
- The map is bounded and contains solid cover plus seaweed hiding zones.
- Treasures are visible pickups with common, rare, and legendary rarities.
- Collecting treasure increases the carried haul.
- Monster patrol uses fixed waypoints.
- Monster detection requires player to be inside the front cone, within range, not hidden, and not blocked by solid cover.
- Monster detection or collision clears the carried haul.
- The anchor shows extract/continue choices only while the player is inside the anchor area.
- Extracting banks carried treasure, moves recovered items into the runtime backpack, and returns to the boat scene.
- Continuing closes the prompt and keeps the run active.
- The boat scene includes a dive hatch that can enter the run scene for testing.
- The boat scene includes a mission console, purifier device, upload device, and warehouse interaction area.
- Pressing `B` in the boat scene opens or closes the backpack and warehouse grid storage UI.
- Interacting with the warehouse opens the same storage UI.
- Storage slots show item icons and stack counts.
- Picking up a stack shows the held item icon and count next to the mouse cursor.
- Left-click takes or places a whole stack.
- Right-click takes half a stack when the hand is empty, or places one item when holding a stack.
- Shift-click quickly transfers a stack between backpack and warehouse.
- Different item types cannot merge into the same grid slot; left-click swaps them instead.
- The upload interaction moves all backpack items into uploaded records and increases research points.

## Non-Functional Requirements
- Use Godot 4.7-compatible GDScript and built-in 2D nodes.
- Keep run logic local to the run scene and keep cross-scene item state in a small inventory autoload.
- Keep future exploration expansion data-driven enough to adjust bounds, obstacles, and spawns without changing actor behavior.

## Exclusions
- No full ship-to-run campaign routing.
- No save/load persistence.
- No combat or player attack.
- No inventory capacity.
- No equipment exchange or upgrade shop yet.
