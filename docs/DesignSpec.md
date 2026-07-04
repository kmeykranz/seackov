# DesignSpec - Underwater Run And Boat Inventory

## Scene Composition
The run scene is a `Node2D` controlled by `RunSceneController`. It contains named world containers, an instanced HUD scene, an instanced storage UI configured to show only the backpack, and a fog container for locked regions. `RunLevelBuilder` reads `RunLayout` region data and instances separate actor, pickup, prop, and UI scenes into those containers.

The boat scene is a `Node2D` controlled by `BoatScene`. It contains a player diver and five interaction areas: dive hatch, mission console, purifier device, upload device, and warehouse. Interactions use the same `F` key prompt pattern as chests and the hatch.

The storage transfer UI is a separate scene instanced into the run scene and the boat. In the run scene it shows only the backpack grid; in the boat scene it shows fixed backpack and warehouse grids, opens with `B` or the warehouse interaction, shows the held stack next to the mouse cursor, and uses Godot `Control._gui_input` mouse handling for Minecraft-like stack selection. The run scene also instances a floating minimap UI that opens with `M` and draws only unlocked region bounds, available anchors, and the player marker.

## Module Responsibilities
- `RunSceneController`: run state, score/haul accounting, extraction choices, run backpack/minimap UI routing, region fog/soft-boundary refresh, and actor signal wiring.
- `PlayerInventory`: runtime cross-scene backpack, warehouse, uploaded item records, research point accounting, and slot-level add/remove operations.
- `ProgressState`: persistent region unlock count, uploaded legendary progress, save/load, and debug mutation APIs.
- `BoatScene`: boat interaction prompts, boat status HUD, and calls into `PlayerInventory`.
- `StorageTransferUi`: backpack-only or backpack/warehouse panel visibility, slot refresh, hand-held stack state, cursor-following held item preview, and click operation routing.
- `StorageSlot`: one clickable storage grid cell with an item icon and stack count.
- `RunLayout`: explicit map bounds, region bounds, anchor specs, cover specs, treasure specs, and monster patrol routes.
- `RunLevelBuilder`: scene instantiation from layout data into run scene containers and random unlocked-anchor spawn selection.
- `PlayerDiver`: keyboard movement, soft lock-boundary resistance, current facing direction, and whether the player is hidden.
- `MonsterPatrol`: fixed waypoint patrol, chase recovery, front cone detection, and collision discovery.
- `TreasurePickup`: rarity value and one-time collection.
- `AnchorExit`: player overlap at extraction point.
- `RunHud`: status, messages, anchor prompt, and run-end panel.
- Prop scenes: visible placeholder art plus collision or cover behavior.

## Run State Machine
States:
- `SEARCHING`: Player can move, collect treasure, be detected, and enter the anchor.
- `ANCHOR_PROMPT`: Player is standing in the anchor area and can choose extract or continue.
- `EXTRACTED`: Carried treasure has been banked and the player is returned to the boat scene.

Events:
- `press_b`: Opens or closes the backpack-only grid UI.
- `press_m`: Opens or closes the floating minimap UI.
- `treasure_collected`: Adds pickup value to carried haul and adds the item to backpack slots immediately.
- `chest_opened`: Picks one weighted random reward and adds it to carried haul and backpack slots immediately.
- `uploaded_legendary_changed`: Unlocks additional regions at every two uploaded legendary items.
- `progress_changed`: Refreshes locked-region fog and player soft boundary.
- `player_detected`: Clears carried haul and removes current-run carried counts from backpack slots.
- `anchor_entered`: `SEARCHING -> ANCHOR_PROMPT`.
- `anchor_exited`: `ANCHOR_PROMPT -> SEARCHING`.
- `continue_selected`: `ANCHOR_PROMPT -> SEARCHING`.
- `extract_selected`: `ANCHOR_PROMPT -> EXTRACTED`, then transitions to the boat scene.

Guards:
- Extraction is ignored unless the anchor prompt is active and the player is still inside the anchor area.
- Detection is ignored after extraction.
- Run storage UI does not expose warehouse slots or Shift-transfer to warehouse.
- The selected spawn anchor is not available as an extraction anchor.
- Anchors in locked regions are ignored.

Side Effects:
- Treasure collection removes the pickup from the map.
- Chest opening marks the chest opened and emits exactly one reward item.
- Detection clears only current-run carried treasure from score and backpack.
- Extraction moves carried treasure into the run banked summary, keeps already-added backpack items without adding another copy, disables active gameplay, and returns to the boat scene.
- Locked-region fog is rebuilt after progression changes.
- The player is pushed rightward when crossing the active locked-region boundary, and also springs outward after releasing input inside the slowdown margin until roughly two body lengths outside the active boundary.
- The minimap redraws after being opened or after progression changes.

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
- `upload_backpack`: all backpack items move to uploaded counts and add research points.

Guards:
- Clicks on empty slots are no-ops unless the hand is holding a stack.
- Right-click placement only works on empty slots or matching non-full stacks.
- Shift-click is ignored while the hand is holding a stack.
- Shift-click is disabled in backpack-only run mode because the warehouse is not visible.
- Different item types never merge into one slot.
- Upload is a no-op when the backpack is empty.
- Detection before extraction removes only current-run carried backpack counts; warehouse and uploaded records are unchanged.

Side Effects:
- Boat status text refreshes after any interaction.
- Uploading uses existing rarity values as research points.
- Storage UI refreshes after any click operation.
- Held-stack preview follows the mouse cursor while the hand is not empty.

## Placeholder Art
Placeholder art is intentionally high-contrast and scene-local: cyan diver, red patrol, translucent red vision cone, yellow/blue/magenta treasure, green seaweed, teal reef, brown wreckage, and panel-backed HUD.

## Future Exploration Range
The current map layout is centralized in `RunLayout` as world bounds, cover rectangles, treasure spawns, and patrol paths. Expanding exploration later should start by changing those layout inputs and adding a progression event that reveals or unlocks new regions.
