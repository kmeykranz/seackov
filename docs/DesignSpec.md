# DesignSpec - Underwater Run And Boat Inventory

## Scene Composition
The run scene is a `Node2D` controlled by `RunSceneController`. It contains named world containers and an instanced HUD scene. `RunLevelBuilder` reads `RunLayout` data and instances separate actor, pickup, prop, and UI scenes into those containers.

The boat scene is a `Node2D` controlled by `BoatScene`. It contains a player diver and five interaction areas: dive hatch, mission console, purifier device, upload device, and warehouse. Interactions use the same `F` key prompt pattern as chests and the hatch.

The storage transfer UI is a separate scene instanced into the boat. It shows fixed backpack and warehouse grids, opens with `B` or the warehouse interaction, and uses Godot `Control._gui_input` mouse handling for Minecraft-like stack selection.

## Module Responsibilities
- `RunSceneController`: run state, score/haul accounting, extraction choices, and actor signal wiring.
- `PlayerInventory`: runtime cross-scene backpack, warehouse, uploaded item records, and research point accounting.
- `BoatScene`: boat interaction prompts, boat status HUD, and calls into `PlayerInventory`.
- `StorageTransferUi`: backpack/warehouse panel visibility, slot refresh, hand-held stack state, and click operation routing.
- `StorageSlot`: one clickable storage grid cell with an item icon and stack count.
- `RunLayout`: explicit map bounds, spawn positions, cover specs, treasure specs, and monster patrol routes.
- `RunLevelBuilder`: scene instantiation from layout data into run scene containers.
- `PlayerDiver`: keyboard movement, current facing direction, and whether the player is hidden.
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
- `treasure_collected`: Adds pickup value to carried haul.
- `player_detected`: Clears carried haul.
- `anchor_entered`: `SEARCHING -> ANCHOR_PROMPT`.
- `anchor_exited`: `ANCHOR_PROMPT -> SEARCHING`.
- `continue_selected`: `ANCHOR_PROMPT -> SEARCHING`.
- `extract_selected`: `ANCHOR_PROMPT -> EXTRACTED`, then transitions to the boat scene.

Guards:
- Extraction is ignored unless the anchor prompt is active and the player is still inside the anchor area.
- Detection is ignored after extraction.

Side Effects:
- Treasure collection removes the pickup from the map.
- Detection clears only carried treasure.
- Extraction moves carried treasure into the warehouse summary, sends recovered counts to the runtime backpack, disables active gameplay, and returns to the boat scene.

Failure and Rollback Paths:
- If detection happens with no carried treasure, state remains playable and no banked treasure changes.
- If the player leaves the anchor before choosing, the prompt closes and extraction cannot be confirmed.
- If extraction is chosen, the rollback path is returning from the boat debug hatch into a new run.

## Boat Inventory State Machine
States:
- `Backpack`: extracted items are stored in backpack grid slots.
- `Warehouse`: items are stored in warehouse grid slots.
- `Hand`: the storage UI is holding a temporary stack selected from a slot.
- `Uploaded`: backpack items have been transmitted and converted into research points.

Events:
- `extract_run`: current run carried counts are added to the backpack.
- `left_click_slot`: takes a whole stack when hand is empty, otherwise places or swaps the held stack.
- `right_click_slot`: takes half a stack when hand is empty, otherwise places one item into a compatible slot.
- `shift_click_slot`: quick-transfers the clicked stack to the other storage location.
- `upload_backpack`: all backpack items move to uploaded counts and add research points.

Guards:
- Clicks on empty slots are no-ops unless the hand is holding a stack.
- Right-click placement only works on empty slots or matching non-full stacks.
- Shift-click is ignored while the hand is holding a stack.
- Upload is a no-op when the backpack is empty.
- Detection before extraction does not touch backpack, warehouse, or uploaded records.

Side Effects:
- Boat status text refreshes after any interaction.
- Uploading uses existing rarity values as research points.
- Storage UI refreshes after any click operation.

## Placeholder Art
Placeholder art is intentionally high-contrast and scene-local: cyan diver, red patrol, translucent red vision cone, yellow/blue/magenta treasure, green seaweed, teal reef, brown wreckage, and panel-backed HUD.

## Future Exploration Range
The current map layout is centralized in `RunLayout` as world bounds, cover rectangles, treasure spawns, and patrol paths. Expanding exploration later should start by changing those layout inputs and adding a progression event that reveals or unlocks new regions.
