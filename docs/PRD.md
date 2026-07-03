# PRD - Single Underwater Run

## Objective
Implement one self-contained underwater run where the player collects treasure, avoids a patrolling monster, and chooses whether to extract at an anchor.

## Functional Requirements
- The game starts directly in the run scene.
- The player moves in 2D using keyboard input.
- The map is bounded and contains solid cover plus seaweed hiding zones.
- Treasures are visible pickups with common, rare, and legendary rarities.
- Collecting treasure increases the carried haul.
- Monster patrol uses fixed waypoints.
- Monster detection requires player to be inside the front cone, within range, not hidden, and not blocked by solid cover.
- Monster detection or collision clears the carried haul.
- The anchor shows extract/continue choices only while the player is inside the anchor area.
- Extracting banks carried treasure and ends the run.
- Continuing closes the prompt and keeps the run active.

## Non-Functional Requirements
- Use Godot 4.7-compatible GDScript and built-in 2D nodes.
- Keep prototype logic local to the run scene and scripts.
- Keep future exploration expansion data-driven enough to adjust bounds, obstacles, and spawns without changing actor behavior.

## Exclusions
- No ship scene.
- No save/load persistence.
- No combat or player attack.
- No inventory capacity.
