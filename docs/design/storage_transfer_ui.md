# Grid Storage UI Design

## Problem Definition
The boat scene has runtime backpack and warehouse counts, but storage movement needs to feel like a grid inventory: items should appear as icons in slots, and common Minecraft-style clicks should move stacks without opening extra dialogs.

## Options Considered
- Keep rarity rows and drag/drop: rejected because it does not match the requested grid inventory interaction model.
- Build a full Minecraft clone with crafting, hotbar, number keys, stack splitting inputs, and item type metadata: rejected as out of scope for the current boat storage loop.
- Add a small fixed grid UI with hand-held stack state: selected because it supports the requested click behavior while keeping save data, equipment, and crafting out of scope.

## State Machine
States:
- `Closed`: storage UI is hidden; gameplay input continues.
- `OpenEmptyHand`: backpack and warehouse grids are visible and no stack is held.
- `OpenHoldingStack`: a temporary hand stack is shown next to the mouse cursor.

Events:
- `press_b`: toggles between `Closed` and `OpenEmptyHand`, unless a held stack cannot be returned.
- `warehouse_interact`: opens the same grid UI.
- `left_click_occupied_slot`: `OpenEmptyHand -> OpenHoldingStack` by taking the whole stack.
- `left_click_empty_or_matching_slot`: places the held stack, returning to `OpenEmptyHand` if it all fits.
- `left_click_different_slot`: swaps the held stack with the clicked stack.
- `right_click_occupied_slot_empty_hand`: `OpenEmptyHand -> OpenHoldingStack` by taking half, rounded up.
- `right_click_empty_or_matching_slot_holding`: places one item from the held stack.
- `shift_click_slot`: quick-transfers the whole clicked stack to the other storage location when the hand is empty.

Guards:
- Empty slots cannot be taken from.
- Right-click placement only accepts empty slots or matching non-full stacks.
- Shift-click is ignored while holding a stack.
- Different item types never merge into one slot.
- Closing the panel first tries to return the held stack to its source storage, then the other storage; if both are full, the panel stays open.

Side Effects:
- Slot clicks update `PlayerInventory`.
- The hand label and all slot icons refresh after each operation.
- The held stack icon follows the mouse cursor while the hand is not empty.
- The boat HUD summary refreshes after storage changes.

Failure Paths
- Clicking an invalid slot leaves counts unchanged.
- If no storage has room for the held stack, closing is refused and the held stack remains visible.
- Upload remains a separate action and only consumes backpack slots.

Rollback Path
Remove `scenes/ui/storage_transfer_ui.tscn`, `scripts/ui/storage_transfer_ui.gd`, `scripts/ui/storage_slot.gd`, the slot-level `PlayerInventory` methods, and the `StorageTransferUi` instance from `boat_scene.tscn`. Restore the previous storage transfer UI behavior.

## Primitive Acceptance Criteria
- Pressing `B` in the boat scene opens the grid storage UI.
- Pressing `B` again closes the grid storage UI when no stack is held.
- Interacting with the warehouse opens the same grid storage UI.
- Occupied slots show an item icon and stack count.
- A picked-up stack appears as an item icon and count next to the mouse cursor.
- Left-click on an occupied slot with an empty hand picks up the whole stack.
- Left-click while holding a stack places or swaps the whole stack.
- Right-click on an occupied slot with an empty hand picks up half the stack, rounded up.
- Right-click while holding a stack places exactly one item into an empty or matching slot.
- Shift-click with an empty hand quick-transfers the clicked stack between backpack and warehouse.
- Different item types swap on left-click instead of merging into one slot.
