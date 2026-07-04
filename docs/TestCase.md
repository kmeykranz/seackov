# TestCase - Single Underwater Run

## Manual Smoke Test
1. Launch the project.
2. From the main menu, choose `Dive In`.
3. Verify the run screen visibly shows the diver, treasure, reef/wreck cover, seaweed, monster vision cone, and HUD.
4. Verify a fresh save starts in the rightmost region and the spawn anchor is not visible as an extraction anchor.
5. Verify the locked-left region is covered by fog and the soft boundary pushes the player back after the player stops pressing into it, stopping near two body lengths outside the boundary.
6. Move the player with arrow keys or WASD.
7. Pick up at least one treasure and verify carried value increases and the item appears in the backpack.
8. Press `B` in the run scene and verify only backpack slots are visible; press `B` again to close it.
9. Press `M` in the run scene and verify a floating minimap opens with full unlocked regions; press `M` again to close it.
10. Collect two legendary items, return to the boat, upload them, and verify the second region unlocks permanently.
11. Upload two more legendary items and verify the third region unlocks; upload two more and verify the fourth region unlocks.
12. Open a chest and verify one random item appears in the backpack.
13. Enter seaweed and confirm the player becomes visually tinted as hidden.
14. Let the monster see or touch the player and verify current-run carried treasure clears from the haul and backpack.
15. Pick up treasure again, enter a non-spawn anchor area, and verify the two-choice prompt appears.
16. Choose continue and verify the prompt closes while the run remains playable.
17. Re-enter the anchor, choose extraction, and verify the game returns to the boat scene with recovered items still in the backpack and not duplicated.
18. Return to the main menu and open the save debug menu.
19. Use the debug controls to reset, add uploaded legendary progress, unlock the next region, and lock back to the starting region.
20. Choose the boat debug entry.
21. Walk near the hatch, mission console, purifier, upload device, and warehouse; verify each area shows an `F` prompt.
22. Press `B` and verify the backpack/warehouse grid storage UI opens; press `B` again and verify it closes.
23. Use the warehouse interaction and verify the same storage UI opens.
24. Verify occupied slots show item icons and stack counts.
25. Right-click a stack and verify half is picked up into the hand and shown next to the mouse cursor.
26. Right-click an empty compatible slot and verify one item is placed.
27. Left-click a compatible stack and verify all held items are placed.
28. Shift-click a stack and verify it quick-transfers between backpack and warehouse.
29. Try placing a held item onto a different item type and verify the items swap instead of merging into one slot.
30. After another extraction, use the upload interaction and verify backpack items move into uploaded records with research points.

## Automated Acceptance Test
Command:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/run_acceptance_test.gd
```

Expected result:
- Exit code `0`.
- Output contains `ACCEPTANCE TESTS PASSED`.
