# TestCase - Single Underwater Run

## Manual Smoke Test
1. Launch the project.
2. From the main menu, choose `Dive In`.
3. Verify the run screen visibly shows the diver, treasure, reef/wreck cover, seaweed, monster vision cone, and HUD.
4. Move the player with arrow keys or WASD.
5. Pick up at least one treasure and verify carried value increases and the item appears in the backpack.
6. Press `B` in the run scene and verify only backpack slots are visible; press `B` again to close it.
7. Open a chest and verify one random item appears in the backpack.
8. Enter seaweed and confirm the player becomes visually tinted as hidden.
9. Let the monster see or touch the player and verify current-run carried treasure clears from the haul and backpack.
10. Pick up treasure again, enter the anchor area, and verify the two-choice prompt appears.
11. Choose continue and verify the prompt closes while the run remains playable.
12. Re-enter the anchor, choose extraction, and verify the game returns to the boat scene with recovered items still in the backpack and not duplicated.
13. Return to the main menu and choose the boat debug entry.
14. Walk near the hatch, mission console, purifier, upload device, and warehouse; verify each area shows an `F` prompt.
15. Press `B` and verify the backpack/warehouse grid storage UI opens; press `B` again and verify it closes.
16. Use the warehouse interaction and verify the same storage UI opens.
17. Verify occupied slots show item icons and stack counts.
18. Right-click a stack and verify half is picked up into the hand and shown next to the mouse cursor.
19. Right-click an empty compatible slot and verify one item is placed.
20. Left-click a compatible stack and verify all held items are placed.
21. Shift-click a stack and verify it quick-transfers between backpack and warehouse.
22. Try placing a held item onto a different item type and verify the items swap instead of merging into one slot.
23. After another extraction, use the upload interaction and verify backpack items move into uploaded records with research points.

## Automated Acceptance Test
Command:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/run_acceptance_test.gd
```

Expected result:
- Exit code `0`.
- Output contains `ACCEPTANCE TESTS PASSED`.
