# Persistent Region Progression Design

## Problem Definition
The run map needs story progression that persists across sessions. At first only the rightmost region is open. The player starts at a random anchor in the deepest unlocked region unless a later story stage has saved a selected anchor, the spawn anchor is not an extraction point, locked regions are hidden by fog, and a soft elastic boundary pushes the player away from locked space. The current campaign uses story gates: two uploaded legendary items repair the purifier and unlock region two, signal tower deployment unlocks region three, and tunnel repair unlocks region four.

## Options Considered
- Keep the existing hard wall stages: rejected because the requested boundary should feel elastic and should hide locked regions with fog.
- Store progress only in the run scene: rejected because region unlocks must persist and must be editable from the main menu.
- Add a small progress autoload with a JSON save file: selected because it gives the run scene and debug menu one shared source of truth without adding a larger quest framework.

## State Machine
States:
- `Region1Open`: only the rightmost region is open.
- `Region2Open`: the rightmost region and the next region to the left are open.
- `Region3Open`: three rightmost regions are open.
- `Region4Open`: all authored regions are open.
- `DebugEditing`: the lobby debug menu can reset or modify progress.

Events:
- `new_run_started`: chooses one random anchor from the deepest unlocked region as the player spawn unless a saved selected anchor is valid.
- `legendary_uploaded`: increments uploaded legendary count and can repair the purifier.
- `prism_threshold_met`: opens region two after two uploaded legendary items.
- `signal_network_complete`: opens region three.
- `tunnel_repaired`: opens region four.
- `debug_reset_save`: returns to `Region1Open` with zero legendary count.
- `debug_add_uploaded_legendary`: increments the saved uploaded legendary count and may repair the purifier if the first threshold is reached.
- `debug_unlock_next`: increases the saved unlocked region count by one.
- `debug_lock_start`: returns to the initial region and resets story-gated access back to the purifier repair stage.

Guards:
- Spawn anchor is not instantiated as an extraction anchor in that run.
- Extraction anchors in locked regions are ignored until their region is unlocked.
- Soft boundary exists only when some region to the left is still locked.
- Debug progress edits clamp region count to the authored region range.

Side Effects:
- Progress is saved to `user://seackov_progress.json` after every persistent edit.
- The run scene refreshes fog and the player soft boundary when progress changes.
- Locked region fog is drawn last so it hides map objects and anchors behind it.
- `PlayerDiver` reduces leftward velocity near the lock boundary, pushes back when past it, and applies an outward spring after the player releases input until the player is roughly two body lengths outside the active boundary.

Failure Paths
- If the save file is missing or malformed, default progress is used and saved.
- If no unlocked anchor is found, the first authored anchor is used as fallback.
- If the progress autoload is missing in a test context, the run uses the initial region only.

Rollback Path
Remove `ProgressState` from `project.godot`, delete `scripts/autoload/progress_state.gd`, remove lobby debug nodes and signals, restore `RunLayout` to single spawn/anchor data, remove multi-anchor handling from `RunSceneController`, and remove soft-boundary logic from `PlayerDiver`.

## Impact Surface
- `ProgressState`: owns persistent story progression and debug mutation APIs.
- `RunLayout`: owns authored regions, region anchors, and region-tagged spawn/object data.
- `RunLevelBuilder`: spawns the player at a selected unlocked anchor and hides the spawn anchor from extraction.
- `RunSceneController`: reacts to progress changes, handles multiple anchors, and draws locked-region fog.
- `MissionConsoleUi`: exposes selected-anchor changes through the boat mission panel after region three opens.
- `PlayerDiver`: applies the elastic boundary force.
- `lobby`: exposes debug save controls.
- Tests and acceptance docs: cover initial lock state, deepest-region default or selected spawn anchor behavior, purifier unlock, story-gated later regions, fog, soft boundary, persistence, and debug controls.

## Primitive Acceptance Criteria
- A fresh save starts with only region one unlocked.
- Starting a run without a saved selected anchor places the player at one authored anchor from the deepest unlocked region.
- The selected spawn anchor is not visible or usable as an extraction anchor.
- Locked regions are covered by fog.
- Crossing into locked space pushes the player back instead of using a hard wall, and releasing input inside the slowdown margin springs the player outward to roughly two body lengths outside the active boundary.
- Uploading two legendary items unlocks only region two and saves that state.
- Signal tower completion unlocks region three.
- Tunnel repair unlocks region four.
- A new run after unlocking defaults to the deepest unlocked region unless the player has selected a specific unlocked dive anchor.
- The lobby debug menu can reset progress, add uploaded legendary progress, unlock the next region, and lock back to the start region.
