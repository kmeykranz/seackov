# Design - Single Run Loop

## Problem Definition
The prototype needs one playable underwater run that proves the collect, risk, detection, and extraction loop before ship gameplay or persistent progression exists.

## Options Compared
| Option | Pros | Cons | Decision |
| --- | --- | --- | --- |
| Hand-authored scene with every node placed in editor | Easy to inspect visually | Slower to adjust layout in code review; harder to test spawned variants | Not used |
| Runtime-created run layout from explicit spawn data | Small diff, easy to test, easy to alter bounds/spawns later | Less visual editing in the editor | Used |
| TileMap-first world | Better for production maps | Adds tile assets and setup before the loop is proven | Deferred |

## State Machine
States:
- `SEARCHING`
- `ANCHOR_PROMPT`
- `EXTRACTED`

Events and transitions:
- `treasure_collected`: stay in `SEARCHING` or `ANCHOR_PROMPT`, add carried value.
- `player_detected`: stay in current non-extracted state, clear carried value.
- `anchor_entered`: `SEARCHING -> ANCHOR_PROMPT`.
- `anchor_exited`: `ANCHOR_PROMPT -> SEARCHING`.
- `continue_selected`: `ANCHOR_PROMPT -> SEARCHING`.
- `extract_selected`: `ANCHOR_PROMPT -> EXTRACTED`.

Guards:
- `extract_selected` requires `run_state == ANCHOR_PROMPT` and `player_on_anchor == true`.
- Monster sight requires range, front cone angle, not hidden, and no solid blocker raycast hit.

Side effects:
- Pickup removal.
- Carried haul reset.
- Warehouse summary update.
- Gameplay disable after extraction.

Failure paths:
- Detection with empty carried haul leaves banked treasure unchanged.
- Leaving anchor closes the prompt and prevents stale extraction.

Rollback path:
- Revert the run scene, scripts, docs, and `project.godot` launch setting.

## Impact
Affected:
- Godot launch scene.
- Run gameplay scripts and split gameplay scenes.
- New project documentation and acceptance criteria.

Unaffected:
- Existing addon code.
- External services.
- Save data, because no persistence is introduced.

## Primitive Acceptance Criteria
- A player-observable pickup changes the carried haul.
- A player-observable detection clears the carried haul immediately.
- A player-observable anchor overlap opens choices.
- A player-observable extraction banks carried value and stops the run.
- A solid blocker or hiding zone prevents monster sight detection.
- First launch visibly shows actor, pickup, cover, monster vision, and HUD placeholders.
