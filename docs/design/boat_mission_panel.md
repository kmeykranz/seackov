# Boat Mission Panel Design

## Problem Definition
The boat mission console needs a visible task interface instead of cycling spawn anchors through status text. The player should see the current story task list on the left and choose an unlocked dive spawn anchor on the right once the story allows spawn selection.

## Options Considered
- Keep `F` cycling through anchors: rejected because the current selection is hard to inspect and easy to miss.
- Add a separate centered mission panel scene: selected because it keeps task presentation and spawn buttons isolated from `BoatScene` persistence logic.
- Merge this into the storage UI: rejected because storage click state and mission selection are unrelated workflows.

## State Machine
States:
- `Closed`: mission panel is hidden.
- `OpenLocked`: mission panel is visible, task list is readable, and spawn selection buttons are disabled before signal tower completion.
- `OpenSelectable`: mission panel is visible, task list is readable, and unlocked spawn anchors can be selected.

Events:
- `mission_console_used`: opens the panel from the boat mission console.
- `spawn_anchor_pressed`: saves the selected unlocked anchor when selection is available.
- `default_spawn_pressed`: clears the saved anchor so the next run defaults to deepest-region random spawn.
- `close_pressed`: hides the panel.

Guards:
- Spawn selection is available only after the signal tower network unlocks region three.
- The selected anchor id must be present in the unlocked anchor specs.
- The panel does not move inventory items or advance story stages.

Side Effects:
- `BoatScene` passes task rows, unlocked anchor specs, and the selected anchor id into `MissionConsoleUi`.
- `MissionConsoleUi` emits the chosen anchor id, and `BoatScene` writes it through `ProgressState.set_selected_spawn_anchor_id()`.
- Boat status text refreshes after the selection changes.

Rollback Path
Remove `scenes/ui/mission_console_ui.tscn`, `scripts/ui/mission_console_ui.gd`, the `MissionConsoleUi` instance from `boat_scene.tscn`, and restore `_handle_mission_console()` to status text or cycling behavior.

## Primitive Acceptance Criteria
- Using the boat mission console opens a centered mission panel.
- The left side shows story task rows.
- The right side shows unlocked dive anchor choices plus a default deepest-region random option.
- Before signal tower completion, spawn choices are visible but disabled.
- After signal tower completion, selecting an unlocked anchor updates the saved spawn anchor id.
- Selecting the default option clears the saved anchor id.
