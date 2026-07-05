# Map Population Distribution Design

## Problem Definition
The authored run map should feel populated across the full world instead of concentrating elements in the first region. Seaweed, coral, treasure, chests, monsters, and anchors must be distributed across the map. The left side of the map, where x values are smaller, should carry higher risk and reward: more valuable treasure, more chests, and denser monsters.

## Options Considered
- Manually list every prop and pickup: rejected because adding broad coverage by hand makes balancing hard and creates noisy data.
- Generate deterministic layout specs from region profiles: selected because it keeps all map population rules in `RunLayout` and avoids runtime randomness in tests.
- Spawn random elements at runtime: rejected for now because acceptance tests need stable counts and progression unlocks.

## State Machine
States:
- `RegionProfileLoaded`: authored region bounds and density values are available.
- `SpecsGenerated`: deterministic specs for props, treasure, chests, and monsters are produced.
- `SceneBuilt`: `RunLevelBuilder` instances the specs into Godot scenes.

Events:
- `build_layout`: converts region profiles into generated specs.
- `new_run_started`: uses the generated specs and chooses a spawn anchor from the deepest unlocked region unless a saved selected anchor is valid.

Guards:
- The authored anchor count remains exactly seven.
- Region density is monotonic from right to left for chests and monsters.
- Treasure rarity shifts toward rare and legendary as region id increases leftward.

Side Effects:
- More objects are instanced into the run scene.
- Acceptance tests validate aggregate distribution rules instead of individual hand-placed object names.

## Impact Surface
- `RunLayout`: owns deterministic population generation and density profiles.
- `RunLevelBuilder`: instances coral as cover and uses generated specs.
- Tests and acceptance docs: cover anchor count, full-map population, and leftward risk/reward scaling.

## Rollback Path
Replace the generator functions in `RunLayout` with the previous static arrays, remove coral spawning from `RunLevelBuilder`, and restore the previous scene-name assertions in acceptance tests.

## Primitive Acceptance Criteria
- The generated layout has exactly seven authored anchors.
- Seaweed, coral, treasures, chests, and monsters exist outside the first region.
- Chests and monsters increase from right to left.
- Legendary treasure count increases toward the left side of the map.
