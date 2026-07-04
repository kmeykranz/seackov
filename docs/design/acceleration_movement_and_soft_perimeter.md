# Acceleration Movement And Soft Perimeter Design

## Problem Definition
The diver currently snaps directly to maximum velocity, which feels abrupt. The outer world boundary also relies on large hard wall bodies, while the desired behavior is a segmented perimeter that slows the player near the edge and elastically pushes them back.

## References
- Godot `CharacterBody2D` uses the node's `velocity` with `move_and_slide()` for motion and collision response: https://docs.godotengine.org/en/stable/classes/class_characterbody2d.html
- Godot `Input` exposes key state queries for keyboard controls: https://docs.godotengine.org/en/stable/classes/class_input.html

## Options Considered
- Keep direct velocity assignment and only lower `speed`: rejected because it keeps the same abrupt movement feel.
- Add a separate movement controller node: rejected for this scope because `PlayerDiver` already owns player movement and hidden-cover state, and no other actor needs this movement model yet.
- Keep full-size hard world walls and only add soft force: rejected because the requested perimeter should read as segmented walls.
- Add acceleration and dash state inside `PlayerDiver`, and generate segmented perimeter walls in `RunLevelBuilder`: selected because it is the smallest change that keeps movement rules with the player and map construction rules with the builder.

## Movement State Machine
States:
- `Idle`: no directional input; velocity decelerates smoothly toward zero.
- `Cruising`: directional input is held; velocity accelerates toward the base maximum speed.
- `Dashing`: Space starts a short boost; velocity receives a directional impulse and the maximum speed temporarily rises.
- `DashRecovery`: boost weight curves down to zero, then returns to `Cruising` or `Idle`.

Events:
- `movement_input_started`: `Idle -> Cruising`.
- `movement_input_released`: `Cruising -> Idle`.
- `space_pressed`: `Idle/Cruising -> Dashing` when the cooldown has elapsed.
- `dash_timer_elapsed`: `Dashing -> DashRecovery`, then normal movement.

Guards:
- Dash uses the current movement direction when present, otherwise the diver's facing direction.
- Dash cannot restart while the cooldown timer is active.
- Velocity is clamped to the current curved speed cap.

Side Effects:
- Movement updates `CharacterBody2D.velocity`, then calls `move_and_slide()`.
- Facing and animation use input direction, not the soft boundary push direction.

## Soft Perimeter State Machine
States:
- `InsideSafeArea`: player is farther than the margin from all world edges.
- `InSlowZone`: player is within the soft margin and movement into the edge is damped.
- `InReboundZone`: player is near or outside the boundary and receives inward force.

Events:
- `approach_edge`: `InsideSafeArea -> InSlowZone`.
- `release_or_cross_edge`: `InSlowZone -> InReboundZone`.
- `return_inside`: `InReboundZone -> InsideSafeArea` after leaving the rebound zone.

Guards:
- Soft perimeter uses world bounds from the run layout.
- Locked-region soft boundary remains separate from the world perimeter boundary.

Side Effects:
- Perimeter walls are spawned as repeated wall segments.
- The player receives inward velocity adjustments before `move_and_slide()`.

## Impact Surface
- `PlayerDiver`: acceleration, deceleration, dash, locked-region soft boundary, and world-perimeter soft boundary.
- `RunLevelBuilder`: segmented perimeter wall generation and world soft-boundary configuration.
- `SolidCover`: collision and visual size configuration for wall segments and cover.
- Tests and acceptance docs: movement acceleration, dash boost, segmented perimeter, and soft perimeter rebound.

## Rollback Path
Restore direct velocity assignment in `PlayerDiver`, remove world soft-boundary fields and methods, change `RunLevelBuilder._spawn_boundaries()` back to four large wall specs, and restore the previous movement acceptance tests.

## Primitive Acceptance Criteria
- Holding movement accelerates toward a lower base maximum speed instead of snapping immediately to full speed.
- Releasing movement decelerates smoothly.
- Pressing Space briefly raises the speed cap and applies a dash impulse.
- Dash boost decays back to normal movement without an abrupt speed-cap drop.
- The outer boundary is made from multiple wall segments.
- Near the outer boundary, movement into the edge slows and the player is pushed back inward.
