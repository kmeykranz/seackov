# DesignSpec - Underwater Run And Boat Inventory

## Scene Composition
The run scene is a `Node2D` controlled by `RunSceneController`. It contains named world containers, an instanced HUD scene, an instanced storage UI configured to show only the backpack, an instanced pause menu, an effects container for placeholder tool markers, and a fog container for locked regions. `RunLevelBuilder` reads `RunLayout` region data and instances separate actor, pickup, prop, and UI scenes into those containers.

The boat scene is a `Node2D` controlled by `BoatScene`. It contains a player diver and five interaction areas: dive hatch, mission console, purifier device, upload device, and warehouse. Interactions use the same `F` key prompt pattern as chests and the hatch.

The storage transfer UI is a separate scene instanced into the run scene and the boat. In the run scene it shows only the backpack grid; in the boat scene it shows fixed backpack and warehouse grids, opens with `B` or the warehouse interaction, stays centered in the viewport, shows the held stack next to the mouse cursor, and uses Godot `Control._gui_input` mouse handling for Minecraft-like stack selection. The run scene also instances a centered floating minimap UI that opens with `M` and draws only unlocked region bounds, available anchors, and the player marker.

Player-facing UI text uses the same Chinese font family as the main menu where text is shown. Runtime messages are Chinese except keyboard key names and proper nouns.

## Module Responsibilities
- `RunSceneController`: run state, score/haul accounting, extraction choices, run backpack/minimap/pause UI routing, region fog/soft-boundary refresh, collision death, and actor signal wiring.
- `RunToolSystem`: story knowledge discovery, unlocked tool selection, tool preparation, per-run uses, cooldowns, placeholder effects, and HUD tool status.
- `PlayerInventory`: runtime cross-scene backpack, warehouse, uploaded item records, research point accounting, and slot-level add/remove operations.
- `ProgressState`: persistent region unlock count, uploaded legendary progress, pending/uploaded knowledge, unlocked tools, save/load, and debug mutation APIs.
- `BoatScene`: boat interaction prompts, boat status HUD, and calls into `PlayerInventory`.
- `StorageTransferUi`: backpack-only or backpack/warehouse panel visibility, slot refresh, hand-held stack state, cursor-following held item preview, and click operation routing.
- `StorageSlot`: one clickable storage grid cell with an item icon and stack count.
- `RunLayout`: explicit map bounds, region bounds, anchor specs, and deterministic full-map population specs for cover, coral, treasure, chests, and monster patrol routes.
- `RunLevelBuilder`: scene instantiation from layout data into run scene containers, coral/seaweed/solid cover construction, segmented wall construction, and random unlocked-anchor spawn selection.
- `PlayerDiver`: accelerated keyboard movement, dash boost, tool preparation movement modifiers, soft lock-boundary resistance, soft world-perimeter resistance, current facing direction, and whether the player is hidden.
- `MonsterPatrol`: fixed waypoint patrol, chase recovery, front cone detection, collision discovery, and tool-applied stun/disarm/knockback/defeat effects.
- `TreasurePickup`: rarity value and one-time collection.
- `AnchorExit`: player overlap at extraction point.
- `RunHud`: status, messages, anchor prompt, and run-end panel.
- `PauseMenuUi`: visible pause controls for resume, settings placeholder, and exit to main menu.
- Prop scenes: visible placeholder art plus collision or cover behavior.

## Run State Machine
States:
- `SEARCHING`: Player can move, collect treasure, be detected, and enter the anchor.
- `ANCHOR_PROMPT`: Player is standing in the anchor area and can choose extract or continue.
- `EXTRACTED`: Carried treasure has been banked and the player is returned to the boat scene.
- `CAUGHT`: Monster contact has emptied the backpack, disabled gameplay, and started the failure-page transition.

Events:
- `press_b`: Opens or closes the backpack-only grid UI.
- `press_m`: Opens or closes the floating minimap UI.
- `press_esc`: Opens or closes the pause menu.
- `press_space`: Applies a short dash impulse and temporarily raises the player speed cap.
- `press_number`: Selects an unlocked run tool.
- `press_q`: Starts tool preparation, instant equip, or hold-to-deploy behavior.
- `release_q`: Completes prepared tools if ready, otherwise cancels and resets preparation.
- `player_x_changed`: recomputes the run depth filter from the player's x position.
- `knowledge_discovered`: Records current-run story knowledge from mapped regions.
- `knowledge_uploaded`: Unlocks the tool mapped to uploaded knowledge.
- `treasure_collected`: Adds pickup value to carried haul and adds the item to backpack slots immediately.
- `chest_opened`: Picks one weighted random reward and adds it to carried haul and backpack slots immediately.
- `uploaded_legendary_changed`: Unlocks additional regions at every two uploaded legendary items.
- `progress_changed`: Refreshes locked-region fog and player soft boundary.
- `player_detected`: Clears carried haul and removes current-run carried counts from backpack slots.
- `monster_collision`: `SEARCHING -> CAUGHT`, empties backpack, disables gameplay, and transitions to the failure scene.
- `failure_return_selected`: transitions from the failure scene to the boat scene.
- `anchor_entered`: `SEARCHING -> ANCHOR_PROMPT`.
- `anchor_exited`: `ANCHOR_PROMPT -> SEARCHING`.
- `continue_selected`: `ANCHOR_PROMPT -> SEARCHING`.
- `extract_selected`: `ANCHOR_PROMPT -> EXTRACTED`, then transitions to the boat scene.

Guards:
- Extraction is ignored unless the anchor prompt is active and the player is still inside the anchor area.
- Detection is ignored after extraction.
- Run storage UI does not expose warehouse slots or modifier-key quick-transfer to warehouse.
- The selected spawn anchor is not available as an extraction anchor.
- Anchors in locked regions are ignored.
- Dash cannot restart while the dash cooldown is active.
- Pause cannot return directly to the boat.
- Tools cannot be used while paused, caught, extracted, out of uses, or on cooldown.
- Knowledge discovered in a failed run is not recorded as pending upload.

Side Effects:
- Movement accelerates toward a target velocity and decelerates toward zero instead of snapping immediately to maximum speed.
- Dash speed cap curves back to the base cap over a short duration.
- Tool preparation slows or locks player movement until completion or cancel.
- Tool effects can disarm, stun, knock back, or remove monsters, and turtle armor can block one monster-contact death.
- The depth filter keeps one fixed ambient color inside each region and linearly blends only inside the boundary band between neighboring regions.
- Treasure collection removes the pickup from the map.
- Chest opening marks the chest opened and emits exactly one reward item.
- Sight detection clears only current-run carried treasure from score and backpack.
- Monster contact clears the whole backpack, zeroes carried haul, disables gameplay, and opens the failure scene.
- The failure scene return button changes to the boat scene.
- Pause sets `SceneTree.paused`, resume clears it, settings stays paused, and exit clears pause before switching to the main menu.
- Extraction moves carried treasure into the run banked summary, keeps already-added backpack items without adding another copy, disables active gameplay, and returns to the boat scene.
- Locked-region fog is rebuilt after progression changes.
- The player is pushed rightward when crossing the active locked-region boundary, and also springs outward after releasing input inside the slowdown margin until roughly two body lengths outside the active boundary.
- Segmented outer wall pieces are generated around the world perimeter, and the player receives inward soft-boundary force near those edges.
- The minimap redraws after being opened or after progression changes.
- Successful extraction moves current-run discovered knowledge into pending upload state.
- Boat upload converts pending knowledge into unlocked tool ids.

Failure and Rollback Paths:
- If detection happens with no carried treasure, state remains playable and no banked, warehouse, or uploaded treasure changes.
- If the player leaves the anchor before choosing, the prompt closes and extraction cannot be confirmed.
- If extraction is chosen, the rollback path is returning from the boat debug hatch into a new run.

## Region Progression State Machine
States:
- `Region1Open`: only the rightmost authored region is open.
- `Region2Open`: the rightmost region and the next region to the left are open.
- `Region3Open`: three rightmost regions are open.
- `Region4Open`: all authored regions are open.

Events:
- `new_run_started`: chooses one random spawn anchor from open regions.
- `legendary_uploaded`: increments and saves uploaded legendary progress.
- `unlock_threshold_met`: opens one additional region at every two uploaded legendary items.
- `debug_reset_save`: resets to `Region1Open`.
- `debug_unlock_next`: opens one additional region.

Guards:
- Region count is clamped to authored region bounds.
- Missing or malformed save data falls back to `Region1Open`.

Side Effects:
- Progress changes write to `user://seackov_progress.json`.
- Lobby debug status text refreshes after edits.

## Tool Unlock State Machine
States:
- `KnowledgeUnknown`: the story knowledge has not been found.
- `KnowledgeRecovered`: the current run has found the knowledge, but it is unsafe until extraction.
- `KnowledgePendingUpload`: extraction succeeded and the knowledge is waiting at the boat upload device.
- `ToolUnlocked`: upload has unlocked the mapped tool for future runs.

Events:
- `region_entered`: maps placeholder region knowledge to the current run.
- `extract_selected`: records recovered knowledge as pending upload.
- `upload_selected`: turns pending knowledge into unlocked tools.

Guards:
- Already pending or uploaded knowledge is ignored if discovered again.
- Failed runs do not persist recovered knowledge.

Side Effects:
- `ProgressState` saves pending knowledge, uploaded knowledge, and unlocked tool ids.
- The run HUD updates the selected tool, uses, cooldown, and preparation progress.

## Tool Use State Machine
States:
- `Ready`: selected tool can be used.
- `Preparing`: tool use key is held and movement is slowed.
- `Deploying`: hold-to-deploy trap is charging and movement is locked.
- `Active`: effect has been applied.
- `Cooldown`: reusable tool is waiting before it can be used again.
- `Consumed`: per-run consumable has no uses left.

Events:
- `use_pressed`: starts instant use, preparing, or deploying.
- `use_released`: completes a prepared tool or cancels if not ready.
- `prepare_complete`: auto-deploys the freeze trap.
- `cooldown_elapsed`: returns a reusable tool to ready.
- `damage_taken`: turtle armor blocks monster contact once and breaks.

## Boat Inventory State Machine
States:
- `Backpack`: recovered run items are stored in backpack grid slots.
- `Warehouse`: items are stored in warehouse grid slots.
- `Hand`: the storage UI is holding a temporary stack selected from a slot.
- `Uploaded`: backpack items have been transmitted and converted into research points.

Events:
- `collect_run_item`: current run pickups and chest rewards are added to the backpack.
- `extract_run`: current run carried counts are banked by the run, but are not added to the backpack a second time.
- `left_click_slot`: takes a whole stack when hand is empty, otherwise places or swaps the held stack.
- `right_click_slot`: takes half a stack when hand is empty, otherwise places one item into a compatible slot.
- `shift_click_slot`: quick-transfers the clicked stack to the other storage location.
- `player_detected`: removes current-run carried counts from backpack.
- `monster_collision`: clears all backpack slots before opening the failure scene.
- `upload_backpack`: all backpack items move to uploaded counts and add research points.

Guards:
- Clicks on empty slots are no-ops unless the hand is holding a stack.
- Right-click placement only works on empty slots or matching non-full stacks.
- Modifier-key quick-transfer is ignored while the hand is holding a stack.
- Modifier-key quick-transfer is disabled in backpack-only run mode because the warehouse is not visible.
- Different item types never merge into one slot.
- Upload is a no-op when the backpack is empty.
- Detection before extraction removes only current-run carried backpack counts; warehouse and uploaded records are unchanged.
- Monster contact clears backpack slots; warehouse and uploaded records are unchanged.

Side Effects:
- Boat status text refreshes after any interaction.
- Uploading uses existing rarity values as research points.
- Storage UI refreshes after any click operation.
- Held-stack preview follows the mouse cursor while the hand is not empty.

## Map Population
`RunLayout` keeps exactly seven authored anchor specs. A run hides the selected spawn anchor and instances the remaining anchor exits, with locked-region anchors ignored until their region opens. The layout generator produces seaweed, coral, solid cover, treasure, chests, and monsters in every authored region. Region profiles increase chest count, monster count, and legendary treasure density as x values get smaller toward the left side of the map.

## Depth Lighting
`RunSceneController` drives the run scene `CanvasModulate.color` from the player's x position and the four `RunLayout` region bounds. Region 1 uses a near-white ambient color, regions 2 and 3 use progressively darker fixed ambient colors, and region 4 uses the darkest ambient color. Each region keeps its fixed color away from boundaries. A narrow boundary band centered on each region boundary linearly blends from the shallower region color to the deeper region color. This avoids a hard visual jump without making the whole region continuously change. The diver's existing `PointLight2D` remains responsible for the bright circle around the player.

## UI Presentation
Text-bearing HUD, pause, minimap, storage, boat, failure, pickup, and patrol labels use the same Chinese font resource as the main menu buttons. The pause panel, minimap panel, storage panel, anchor prompt, and run-end panel are centered overlays so they do not appear offset on different viewport sizes.

## Placeholder Art
Placeholder art is intentionally high-contrast and scene-local: cyan diver, red patrol, translucent red vision cone, yellow/blue/magenta treasure, green seaweed, coral texture cover, teal reef, brown wreckage, and panel-backed HUD.

## Future Exploration Range
The current map layout is centralized in `RunLayout` as world bounds, cover rectangles, treasure spawns, and patrol paths. Expanding exploration later should start by changing those layout inputs and adding a progression event that reveals or unlocks new regions.
