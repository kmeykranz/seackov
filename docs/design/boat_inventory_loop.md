# Boat Inventory Loop Design

## Problem Definition
The current run can collect and extract treasure, but extracted items only live inside the run scene summary. The new boat scene needs a small home-base loop where recovered items can be carried back, stored in a warehouse, or uploaded for research interaction.

## Options Considered
- Keep inventory inside `BoatScene`: rejected because extracted items from the run scene would not survive scene changes without coupling the run directly to the boat.
- Store inventory inside `RunSceneController`: rejected because the boat would need to know run internals.
- Add a small autoload inventory ledger: selected because it gives both scenes a shared runtime state while keeping persistence, crafting, equipment exchange, and progression out of scope.

## State Machine
States:
- `AtSea`: items are unsafe carried haul inside the run scene.
- `Backpack`: extracted items have returned to the boat and can be deposited or uploaded.
- `Warehouse`: items are stored for later use and no longer in the backpack.
- `Uploaded`: items have been transmitted through the upload device and converted into research points.

Events:
- `extract_run`: moves current run carried counts into the backpack.
- `detected`: clears only the current run carried counts before extraction.
- `move_storage_stack`: moves one rarity stack between backpack and warehouse.
- `upload_backpack`: moves all backpack items into uploaded records and adds research points.

Guards:
- `extract_run` only happens through the anchor extraction flow.
- `move_storage_stack` and `upload_backpack` are no-ops when the source storage is empty.
- Warehouse and uploaded records do not move back into the current run.

Side Effects:
- Boat HUD text refreshes after each interaction.
- Uploading converts item counts into research points using the existing rarity values.
- Main menu receives a temporary boat debug entry, but normal game flow is not changed.

Failure Paths
- If the player is detected before extraction, no backpack state changes.
- If a boat interaction is triggered with no backpack items, the scene shows a status message and keeps all counts unchanged.

Rollback Path
Remove `PlayerInventory` from `project.godot`, remove boat interaction nodes/scripts, restore the lobby button layout, and revert the run extraction call that sends counts to the backpack.

## Primitive Acceptance Criteria
- A player can enter the boat scene from a debug button on the main menu.
- The boat scene visibly contains a dive hatch, mission console, purifier device, upload device, and warehouse.
- Standing in a boat interaction area shows an `F` prompt for that area.
- Extracting from a run adds the extracted item counts to a cross-scene backpack.
- Dragging from the boat storage UI moves item stacks between backpack and warehouse counts.
- Uploading from the boat moves all backpack items into uploaded counts and increases research points.
- Detection during a run still clears only unsafe carried items and does not change backpack, warehouse, or uploaded counts.
