# Run Minimap UI Design

## Problem Definition
The player needs a floating minimap during a run. It should open with `M`, close with `M`, show the full map of unlocked regions without exposing locked regions, and mark the currently active story target positions.

## Options Considered
- Draw the minimap directly in `RunSceneController`: rejected because the controller already owns run state, anchors, fog, and inventory routing.
- Add a separate `MiniMapUi` scene with a custom drawing control: selected because it keeps presentation isolated and lets tests query visibility and unlocked region count.
- Use the full world texture cropped into the panel: deferred because the prototype only needs region and anchor readability.

## State Machine
States:
- `Closed`: minimap panel is hidden.
- `Open`: minimap panel is visible and draws unlocked region bounds, available extraction anchors, current story targets, and the player position.

Events:
- `press_m`: toggles between `Closed` and `Open`.
- `progress_changed`: redraws the minimap with the new unlocked region count.
- `story_targets_changed`: redraws the minimap with the current story target markers.
- `player_moved`: redraws player marker on refresh.

Guards:
- Locked regions are not drawn as explored map space.
- The spawn anchor is not drawn because it is not an extraction point in the current run.
- Story targets are drawn only when the story system currently exposes them.
- The minimap does not mutate progress or inventory state.

Side Effects:
- The run scene passes layout metadata, current player, anchors, spawn anchor data, and story target data into the minimap.
- The minimap control redraws when opened or refreshed.

Failure Paths
- If the run has no player yet, the minimap draws unlocked regions and anchors without a player marker.
- If no unlocked region data is available, the panel stays empty but can still close normally.

Rollback Path
Remove `scenes/ui/minimap_ui.tscn`, `scripts/ui/minimap_ui.gd`, the `MiniMapUi` instance from `run_scene.tscn`, and `M` key handling from `RunSceneController`.

## Primitive Acceptance Criteria
- Pressing `M` in the run scene opens a floating minimap panel.
- Pressing `M` again closes the minimap panel.
- The minimap reports/draws only unlocked regions.
- Current story targets appear as distinct minimap markers.
- Unlocking a region updates the minimap's unlocked region count.
