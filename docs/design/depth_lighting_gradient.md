# Depth Lighting Gradient Design

## Problem Definition
The run scene already uses `CanvasModulate` plus the diver's local `PointLight2D` to create a bright circle around the player and a darker surrounding sea. The surrounding darkness is currently fixed, but it should communicate depth: the rightmost region should be almost unfiltered, and the leftmost region should be very dark. Each region should keep a stable darkness level, with linear blending only inside the boundary band between neighboring regions.

## References
- Godot `CanvasModulate` tints all nodes on a canvas through its `color` property: https://docs.godotengine.org/en/stable/classes/class_canvasmodulate.html

## Options Considered
- Keep one fixed `CanvasModulate` color: rejected because it does not communicate depth progression.
- Add separate filter scenes per region: rejected because it would duplicate state and introduce boundary handoff issues.
- Continuously interpolate across the full width of each region: rejected because it makes the filter change even when the player is not crossing a depth boundary.
- Drive one `CanvasModulate` color from player x position, authored region bounds, and a narrow boundary band: selected because it keeps each region visually stable while making boundary crossings continuous.

## State Machine
States:
- `RegionPlateau`: the player is away from a boundary band, so the current region's fixed ambient color is applied.
- `BoundaryBlend`: the player is inside a boundary band, so ambient color linearly blends from the shallower region color to the deeper region color.
- `TrenchDark`: the player is in region 4 away from a boundary band, so the darkest ambient color is applied.

Events:
- `player_x_changed`: recomputes ambient color from the player's x position.
- `boundary_band_entered`: begins linear blending between the two neighboring fixed region colors.
- `boundary_band_exited`: locks to the fixed ambient color of the region now being occupied.

Guards:
- X positions outside the authored world clamp to the nearest endpoint color.
- X positions outside boundary bands use the containing region's fixed color.
- HUD and pause UI remain on CanvasLayers and are not used as depth-lighting inputs.

Side Effects:
- `CanvasModulate.color` updates every frame while the run scene exists.
- The diver's existing local light continues to define the bright center circle.

## Impact Surface
- `RunSceneController`: owns depth-light color calculation and applies it to the run scene `CanvasModulate`.
- `RunLayout`: supplies the four authored region bounds used by plateau and boundary-band detection.
- Acceptance tests and docs: validate fixed region plateaus, monotonic darkening, and boundary continuity.

## Rollback Path
Restore the fixed `CanvasModulate.color` in `run_scene.tscn`, remove depth-lighting methods from `RunSceneController`, and remove the depth-lighting acceptance checks.

## Primitive Acceptance Criteria
- Region 1 ambient color is brighter than region 2, region 2 brighter than region 3, and region 3 brighter than region 4.
- Samples well inside the same region have the same ambient color.
- Crossing a region boundary does not jump to the next darkness level; the boundary band linearly blends from the shallower color to the deeper color.
- Moving the player to different x positions updates the active `CanvasModulate.color`.
