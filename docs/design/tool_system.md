# Tool System Design

## Problem Definition
The prototype needs usable placeholder tools tied to story knowledge. Tools must not merge into the existing treasure backpack because they have active effects, cooldowns, preparation states, and per-run consumable counts rather than stack-only storage behavior.

## Options Considered
- Store tools as regular backpack stacks: rejected because backpack clicks, warehouse transfers, and upload logic would inherit combat behavior that does not belong to storage slots.
- Add a separate run tool system with persistent knowledge unlocks: selected because it keeps treasure storage stable while letting tools own active-use state, cooldowns, and monster/player effects.
- Build full biome encounter scenes first: rejected for this step because the user asked for placeholder tools that actually work now.

## State Machine
States:
- `Locked`: tool knowledge has not been uploaded, so the tool is unavailable.
- `UnlockedReady`: tool is available in the run and can be selected.
- `Preparing`: the use key is held; movement is slowed or locked depending on the tool.
- `ActiveEffect`: the tool effect is applied to monsters, traps, or armor state.
- `Cooldown`: reusable tools cannot be used again until their timer ends.
- `Consumed`: per-run consumable tools have no remaining uses.

Events:
- `knowledge_discovered`: player enters a mapped region and adds knowledge to the current run.
- `extract_success`: current-run knowledge becomes pending boat upload.
- `upload_knowledge`: pending knowledge unlocks its mapped tools.
- `select_tool`: number key selects one unlocked tool.
- `use_pressed`: begins instant use or preparation.
- `use_released`: completes prepared tools if ready, otherwise cancels and resets progress.
- `effect_timeout`: stun, disarm, marker, or cooldown timers expire.
- `damage_taken`: equipped turtle armor blocks one monster-contact death and then breaks.

Guards:
- Tools cannot be used while the run is paused, extracted, caught, or when no unlocked tool is selected.
- Consumable tools require at least one remaining run use.
- Prepared tools require the hold timer to reach their prepare duration.
- Freeze trap deployment locks movement and resets if released early.
- Reusable tools require cooldown to be zero.

Side Effects:
- `ProgressState` persists pending knowledge, uploaded knowledge, and unlocked tool ids.
- `RunToolSystem` applies movement slow or movement lock during preparation.
- Monsters can be disarmed, stunned, knocked back, or removed by tool effects.
- Placeholder effect markers are spawned in the run scene.
- `RunHud` displays selected tool, uses, cooldown, and preparation state.

## Initial Placeholder Mapping
- Region 1 knowledge unlocks `毒素网`.
- Region 2 knowledge unlocks `螺旋桨推进器`.
- Region 3 knowledge unlocks `急冻陷阱` and `岩浆炸弹`.
- Region 4 knowledge unlocks `海龟盔甲` and `电鞭`.

This mapping stands in for the future red mangrove, shipwreck, cold sea, volcano, turtle, and electric eel encounters.

## Impact Surface
- `ProgressState`: save/load of knowledge and unlocked tool ids.
- `BoatScene`: upload device unlocks tools from pending knowledge as well as uploading backpack contents.
- `RunSceneController`: forwards tool input, records recovered knowledge on extraction, and lets armor block monster-contact death.
- `RunToolSystem`: owns active tool state and effects.
- `PlayerDiver`: exposes action movement slow, movement lock, and item impulse hooks.
- `MonsterPatrol`: exposes stun, disarm, knockback, and defeat hooks.
- `RunHud`: displays tool state.

## Rollback Path
Remove `RunToolSystem`, remove tool input forwarding from `RunSceneController`, remove knowledge fields from `ProgressState`, restore `BoatScene._upload_backpack()` to upload only backpack contents, remove player/monster tool effect methods, and remove the tool panel from `run_hud.tscn`.

## Primitive Acceptance Criteria
- Discovering region knowledge during a run does not immediately unlock a tool.
- Extracting with discovered knowledge records pending upload knowledge.
- Uploading pending knowledge on the boat unlocks its mapped tool ids.
- Unlocked tools appear in the run HUD and can be selected.
- Toxic net disarms monsters, turtle armor blocks one monster-contact death, propeller gives a forward burst, freeze trap stuns monsters when triggered, magma bomb removes monsters in a small radius, and electric whip stuns the first monster in front with a cooldown.
