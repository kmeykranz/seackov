# Run Backpack Inventory Design

## Problem Definition
The run scene previously stored recovered objects only in local carried counters and copied them into the runtime backpack on extraction. The requested behavior is that the backpack exists in the run, pickups enter it immediately, and chest rewards are random items that also enter the backpack.

The design must keep the existing risk rule: current-run carried objects are lost when the player is discovered, while already banked, warehouse, and uploaded items are not affected.

## Options Considered
- Keep local carried counters until extraction: rejected because the run backpack would not show newly collected items.
- Make run pickups permanent as soon as collected: rejected because detection would no longer clear the current run haul.
- Add items to the runtime backpack immediately and track current-run carried counts for rollback: selected because it makes the backpack visible during the run while preserving the catch penalty.

## State Machine
States:
- `Searching`: Player can collect pickups, open chests, press `B`, be detected, and enter the anchor.
- `BackpackOpen`: Same run state, with the backpack-only grid visible.
- `AnchorPrompt`: Player is inside the anchor area and can extract or continue.
- `Extracted`: Current carried counts are banked by the run and the scene returns to the boat.

Events:
- `press_b`: toggles the backpack-only storage UI.
- `treasure_collected`: adds one item to backpack slots and increments current-run carried counts/value.
- `chest_opened`: chooses one weighted random reward, adds it to backpack slots, and increments current-run carried counts/value.
- `player_detected`: removes current-run carried counts from backpack slots and clears carried counts/value.
- `extract_selected`: banks carried counts/value, clears carried counts/value, and changes to the boat scene without adding duplicate backpack items.
- `continue_selected`: hides the anchor prompt and returns to `Searching`.

Guards:
- Backpack-only UI cannot access warehouse slots.
- Shift-transfer is disabled in backpack-only UI because there is no visible target storage.
- Detection is ignored after extraction.
- Extraction requires the player to still be inside the anchor area.

Side Effects:
- `PlayerInventory.add_to_storage("backpack", rarity, 1)` is called on pickup and chest reward.
- `PlayerInventory.remove_counts_from_storage("backpack", carried_counts)` is called on detection.
- The run HUD and open backpack UI refresh after item changes.
- Chest opening disables that chest and emits exactly one reward.

Failure Paths
- If detection happens with no carried counts, backpack, warehouse, and uploaded records remain unchanged.
- If a backpack write fails, the run remains playable and reports that the item could not be stored.
- If the player leaves the anchor area before choosing extraction, extraction is ignored.

Rollback Path
Remove the `StorageTransferUi` instance from `run_scene.tscn`, remove run-scene `B` handling and storage UI wiring from `RunSceneController`, restore extraction-time `receive_extracted_counts`, and remove `PlayerInventory.remove_from_storage` / `remove_counts_from_storage` if no other code uses them.

## Impact Surface
- `PlayerInventory`: adds explicit removal APIs for current-run item rollback.
- `StorageTransferUi`: gains backpack-only mode and disables hidden warehouse operations in that mode.
- `RunSceneController`: writes pickups and chest rewards to the backpack immediately and removes them on detection.
- `run_scene.tscn`: instances the existing storage transfer UI.
- Tests and acceptance docs: cover run backpack visibility, immediate pickup storage, random chest reward storage, and non-duplicating extraction.

## Primitive Acceptance Criteria
- Pressing `B` in the run scene opens a grid inventory that shows backpack slots and hides warehouse slots.
- Pressing `B` again closes the run backpack UI.
- Collecting a treasure increases current carried value and increases backpack item count immediately.
- Opening a chest increases backpack item count by exactly one random reward.
- Monster discovery clears current carried value and removes current-run item counts from the backpack.
- Anchor extraction returns to the boat while keeping already-added backpack items without adding duplicates.
