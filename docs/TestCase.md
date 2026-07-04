# TestCase - Single Underwater Run

## Manual Smoke Test
1. Launch the project.
2. From the main menu, choose `Dive In`.
3. Verify the run screen visibly shows the diver, treasure, reef/wreck cover, coral, seaweed, monster vision cone, and HUD.
4. Verify the full authored map has seven anchor positions, with the selected spawn anchor hidden for the current run.
5. Verify seaweed, coral, treasure, chests, and monsters appear across multiple regions, and lower-x regions are denser and more valuable.
6. Verify a fresh save starts in the rightmost region and the spawn anchor is not visible as an extraction anchor.
7. Verify the outer perimeter is made from visible segmented wall pieces.
8. Verify the locked-left region is covered by fog and the soft boundary pushes the player back after the player stops pressing into it, stopping near two body lengths outside the boundary.
9. Move the player with arrow keys or WASD and verify movement accelerates/decelerates smoothly instead of snapping to full speed.
10. Press `Space` while moving and verify the diver dashes briefly, then curves back to normal speed.
11. Move near an outer edge and verify the player slows and is pushed back inward.
12. Press `Esc` and verify the pause menu opens with continue, settings, and exit-to-main-menu options, and no return-to-ship option.
13. Resume from pause and verify gameplay continues.
14. Pick up at least one treasure and verify carried value increases and the item appears in the backpack.
15. Press `B` in the run scene and verify only backpack slots are visible; press `B` again to close it.
16. Press `M` in the run scene and verify a floating minimap opens with full unlocked regions; press `M` again to close it.
17. Collect two legendary items, return to the boat, upload them, and verify the second region unlocks permanently.
18. Upload two more legendary items and verify the third region unlocks; upload two more and verify the fourth region unlocks.
19. Open a chest and verify one random item appears in the backpack.
20. Enter seaweed and confirm the player becomes visually tinted as hidden.
21. Let the monster see the player and verify current-run carried treasure clears from the haul and backpack.
22. Touch a monster and verify the backpack is emptied and the scene returns to the boat.
23. Start another run, pick up treasure, enter a non-spawn anchor area, and verify the two-choice prompt appears.
24. Choose continue and verify the prompt closes while the run remains playable.
25. Re-enter the anchor, choose extraction, and verify the game returns to the boat scene with recovered items still in the backpack and not duplicated.
26. Return to the main menu and open the save debug menu.
27. Use the debug controls to reset, add uploaded legendary progress, unlock the next region, and lock back to the starting region.
28. Choose the boat debug entry.
29. Walk near the hatch, mission console, purifier, upload device, and warehouse; verify each area shows an `F` prompt.
30. Press `B` and verify the backpack/warehouse grid storage UI opens; press `B` again and verify it closes.
31. Use the warehouse interaction and verify the same storage UI opens.
32. Verify occupied slots show item icons and stack counts.
33. Right-click a stack and verify half is picked up into the hand and shown next to the mouse cursor.
34. Right-click an empty compatible slot and verify one item is placed.
35. Left-click a compatible stack and verify all held items are placed.
36. Shift-click a stack and verify it quick-transfers between backpack and warehouse.
37. Try placing a held item onto a different item type and verify the items swap instead of merging into one slot.
38. After another extraction, use the upload interaction and verify backpack items move into uploaded records with research points.

## Automated Acceptance Test
Command:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/run_acceptance_test.gd
```

Expected result:
- Exit code `0`.
- Output contains `ACCEPTANCE TESTS PASSED`.
