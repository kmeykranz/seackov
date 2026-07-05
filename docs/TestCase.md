# TestCase - Single Underwater Run

## Manual Smoke Test
1. Launch the project.
2. From the main menu, choose `开始下潜`.
3. Verify the boat starts with camera shake and an opening terminal briefing on a fresh save.
4. Enter the run scene and verify it visibly shows the diver, treasure, reef/wreck cover, coral, seaweed, monster vision cone, objective HUD, and tool HUD.
5. Verify the full authored map has seven anchor positions, with the selected spawn anchor hidden for the current run.
6. Verify seaweed, coral, treasure, chests, and monsters appear across multiple regions, and lower-x regions are denser and more valuable.
7. Verify a fresh save starts in the rightmost region and the spawn anchor is not visible as an extraction anchor.
8. Verify the outer perimeter is made from visible segmented wall pieces.
9. Verify the locked-left region is covered by fog and the soft boundary pushes the player back after the player stops pressing into it, stopping near two body lengths outside the boundary.
10. Move the player with arrow keys or WASD and verify movement accelerates/decelerates smoothly instead of snapping to full speed.
11. Press `Space` while moving and verify the diver dashes briefly, then curves back to normal speed.
12. Move near an outer edge and verify the player slows and is pushed back inward.
13. Move from the rightmost region toward the left and verify the surrounding depth filter stays fixed inside a region, changes linearly only near each region boundary, and becomes very dark in the leftmost region while the diver light remains bright.
14. Press `Esc` and verify the pause menu opens centered with continue, settings, and exit-to-main-menu options, and no return-to-ship option.
15. Resume from pause and verify gameplay continues.
16. Pick up at least one treasure and verify carried value increases and the item appears in the backpack.
17. Press `B` in the run scene and verify only backpack slots are visible; press `B` again to close it.
18. Press `M` in the run scene and verify a floating minimap opens with full unlocked regions and current story target markers; press `M` again to close it.
19. Verify entering a mapped story region shows a knowledge scan ring/message, but the tool is not unlocked until after extraction and boat upload.
20. Extract successfully, use the boat upload interaction, then start another run and verify the tool HUD shows the unlocked tool.
21. Use number keys to select tools and hold `Q` to prepare or deploy the selected tool.
22. Verify toxic net disarms monsters in front and consumes its use.
23. Verify turtle armor equips, blocks one monster-contact death, knocks enemies back, and then breaks.
24. Verify propeller booster gives a forward burst and then enters cooldown.
25. Verify freeze trap requires holding deployment, locks movement while deploying, and stuns monsters when triggered.
26. Verify magma bomb removes monsters in a small blast radius and consumes its use.
27. Verify electric whip charges, stuns the first monster in front, and then enters cooldown.
28. Collect two legendary items, return to the boat, upload them, and verify the second region unlocks permanently with purifier-complete terminal dialogue.
29. Verify additional legendary uploads do not unlock the third or fourth region.
30. In region 2, approach both story markers, hold `E` to deploy signal towers, and verify releasing early resets progress.
31. Verify both signal towers deployed opens region 3, an unselected new run defaults to a region 3 spawn anchor, and the boat mission console opens a panel with task rows on the left and selectable unlocked dive anchors on the right.
32. Approach the tunnel marker, verify hidden terminal dialogue, verify short `E` presses do not close full terminal text, verify the close progress bar fills while holding `E`, then hold `E` for one second to close it and repair all tunnel markers with held `E`.
33. Verify tunnel repair opens region 4 and shows the ruins terminal plus black sphere placeholder.
34. Interact with the ruins terminal, verify final escape starts, then extract and upload final data on the boat for the success ending.
35. Repeat final escape and die to verify the failure ending copy.
36. Open a chest and verify one random item appears in the backpack.
37. Enter seaweed and confirm the player becomes visually tinted as hidden.
38. Let the monster see the player and verify current-run carried treasure clears from the haul and backpack.
39. Touch a monster and verify the backpack is emptied and the failure scene opens.
40. Press the failure scene return button and verify the scene returns to the boat.
41. Start another run, pick up treasure, enter a non-spawn anchor area, and verify the two-choice prompt appears.
42. Choose continue and verify the prompt closes while the run remains playable.
43. Re-enter the anchor, choose extraction, and verify the game returns to the boat scene with recovered items still in the backpack and not duplicated.
44. Return to the main menu and open the save debug menu.
45. Use the debug controls to reset, add uploaded legendary progress, unlock the next region, and lock back to the starting region.
46. Choose the boat debug entry.
47. Walk near the hatch, mission console, purifier, upload device, and warehouse; verify each area shows an `F` prompt.
48. Use the mission console and verify the centered mission panel opens with a task list on the left and dive-anchor choices on the right.
49. Before signal tower completion, verify dive-anchor choices are visible but disabled; after signal tower completion, choose an unlocked anchor and verify it becomes selected.
50. Press `B` and verify the centered backpack/warehouse grid storage UI opens; press `B` again and verify it closes.
51. Use the warehouse interaction and verify the same storage UI opens.
52. Verify occupied slots show item icons and stack counts.
53. Right-click a stack and verify half is picked up into the hand and shown next to the mouse cursor.
54. Right-click an empty compatible slot and verify one item is placed.
55. Left-click a compatible stack and verify all held items are placed.
56. Hold the shift key while clicking a stack and verify it quick-transfers between backpack and warehouse.
57. Try placing a held item onto a different item type and verify the items swap instead of merging into one slot.
58. After another extraction, use the upload interaction and verify backpack items move into uploaded records with research points.

## Automated Acceptance Test
Command:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/run_acceptance_test.gd
```

Expected result:
- Exit code `0`.
- Output contains `ACCEPTANCE TESTS PASSED`.
