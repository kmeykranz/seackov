# Story Campaign System Design

## Problem
The current project has a playable dive, boat interactions, item upload, region fog, anchors, and placeholder tools, but plot progression is still scattered across fixed messages and old upload thresholds. The updated campaign needs persistent story stages, visual objectives on the existing map, terminal dialogue at key beats, hold-to-deploy tasks, tunnel repair, final truth recovery, and separate success/failure endings.

This document treats the latest user-provided story text as the source of truth. Older docs describe existing systems only where they match current code.

## References
- Godot Tween docs: https://docs.godotengine.org/en/stable/classes/class_tween.html
- Godot FileAccess docs: https://docs.godotengine.org/en/stable/classes/class_fileaccess.html

## Options
- Put all story checks inside `RunSceneController` and `BoatScene`: rejected because stage logic would be mixed into movement, extraction, inventory, and UI code.
- Make each story step a separate scene: rejected for now because the requested prototype needs to use the current single map and existing boat scene.
- Add a persistent story state to `ProgressState` plus a run-local story objective system: selected because save state stays cross-scene while visual targets and hold interactions stay in the run scene.

## Story State Machine
States:
- `prism_recovery`: fresh save. The boat intro has not necessarily played. Only the rightmost shallow region is open. The objective is to recover and upload two purple prism placeholders.
- `signal_tower`: purifier repair is complete. Region 2 is open. Two signal tower deployment targets are visible on the current map.
- `tunnel_repair`: both signal towers are deployed. Region 3 is open. New runs default to the deepest unlocked region unless the player has selected a specific dive anchor from the boat mission console. The tunnel approach can trigger hidden dialogue, then repair targets appear near the existing tunnel art.
- `ruins_investigation`: tunnel repair is complete. Region 4 is open. The ruins terminal and black sphere placeholder are visible.
- `final_escape`: the ruins terminal has been read. The player carries truth data and must extract once.
- `ending_success`: the final data was extracted and uploaded on the boat.
- `ending_failure`: the player died during `final_escape`.

Events:
- `intro_finished`: marks the opening terminal dialogue as seen.
- `legendary_uploaded`: increments uploaded purple placeholders.
- `prism_threshold_met`: `prism_recovery -> signal_tower`, unlocks region 2 and plays purifier/task terminal dialogue.
- `signal_site_deployed`: records one of two signal tower sites.
- `all_signal_sites_deployed`: `signal_tower -> tunnel_repair`, unlocks region 3 and plays the deep-region terminal dialogue.
- `tunnel_approached`: marks the hidden tunnel story as seen.
- `tunnel_site_repaired`: records one tunnel repair target.
- `all_tunnel_sites_repaired`: `tunnel_repair -> ruins_investigation`, unlocks region 4 and plays tunnel-complete/final-task terminal dialogue.
- `ruins_terminal_read`: `ruins_investigation -> final_escape`, starts the final escape warning.
- `final_extract`: marks final truth data as pending upload.
- `final_data_uploaded`: `final_escape -> ending_success`.
- `final_death`: `final_escape -> ending_failure`.

Guards:
- Purple upload only unlocks region 2. Regions 3 and 4 require story objectives.
- Signal targets can only complete in `signal_tower`.
- Tunnel repair targets can only complete in `tunnel_repair`.
- The ruins terminal can only complete in `ruins_investigation`.
- Final success requires extraction first, then upload on the boat.
- Final failure only applies while `final_escape` is active.

Side Effects:
- `ProgressState` writes stage fields to the existing JSON save file.
- The boat terminal reuses the typewriter overlay for intro, stage, and ending dialogue.
- The run scene spawns high-contrast world markers for signal towers, tunnel repairs, ruins terminal, black sphere, and final escape.
- Hold-to-deploy or hold-to-repair locks player movement and resets if the key is released early.
- Run HUD shows the active objective and hold progress.
- The minimap shows current story target markers so active objectives can be located without reading long text.
- Terminal text can be fast-forwarded while typing, then shows a hold-progress bar and requires holding `E` for one second before it closes.
- The selected boat dive anchor is saved after the signal tower network is complete.

Failure Paths
- If the player dies before `final_escape`, the existing failure page is used and story stage does not advance.
- If the player dies during `final_escape`, the failure page uses the story failure copy and the save records `ending_failure`.
- If a save is missing story fields, it loads as `prism_recovery`.

Rollback Path
Remove `RunStorySystem`, remove story fields from `ProgressState`, restore upload-based region unlock rules, remove story target setup from `RunSceneController`, restore fixed boat mission/purifier messages, and remove story-specific failure/success handling.

## Primitive Acceptance
- A fresh save starts on the boat and plays camera shake followed by the opening terminal text.
- Uploading two purple placeholders repairs the purifier, opens region 2, and does not open deeper regions.
- In region 2, two visible signal tower targets require held input; releasing early resets progress.
- The minimap marks currently active story target positions.
- Full terminal text is not dismissed by a short `E` press; its close progress bar fills while holding `E`, and it closes only after holding `E` for one second.
- Completing both signal tower targets opens region 3 and enables saved dive-anchor selection from the boat mission panel.
- Approaching the tunnel in region 3 triggers hidden terminal dialogue and exposes repair markers.
- Completing all tunnel repair markers opens region 4 and exposes the ruins terminal plus black sphere placeholder.
- Interacting with the ruins terminal starts final escape and changes the objective to extract with truth data.
- Dying during final escape records the failure ending and the failure page shows the story failure copy.
- Extracting during final escape marks truth data pending; uploading it on the boat records success and plays the success ending.
