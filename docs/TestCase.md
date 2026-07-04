# TestCase - Single Underwater Run

## Manual Smoke Test
1. Launch the project.
2. From the main menu, choose `Dive In`.
3. Verify the run screen visibly shows the diver, treasure, reef/wreck cover, seaweed, monster vision cone, and HUD.
4. Move the player with arrow keys or WASD.
5. Pick up at least one treasure and verify carried value increases.
6. Enter seaweed and confirm the player becomes visually tinted as hidden.
7. Let the monster see or touch the player and verify carried treasure clears.
8. Pick up treasure again, enter the anchor area, and verify the two-choice prompt appears.
9. Choose continue and verify the prompt closes while the run remains playable.
10. Re-enter the anchor, choose extraction, and verify the game returns to the boat scene with recovered items in the backpack.
11. Return to the main menu and choose the boat debug entry.
12. Walk near the hatch, mission console, purifier, upload device, and warehouse; verify each area shows an `F` prompt.
13. Press `B` and verify the backpack/warehouse grid storage UI opens; press `B` again and verify it closes.
14. Use the warehouse interaction and verify the same storage UI opens.
15. Verify occupied slots show item icons and stack counts.
16. Right-click a stack and verify half is picked up into the hand.
17. Right-click an empty compatible slot and verify one item is placed.
18. Left-click a compatible stack and verify all held items are placed.
19. Shift-click a stack and verify it quick-transfers between backpack and warehouse.
20. After another extraction, use the upload interaction and verify backpack items move into uploaded records with research points.

## Automated Acceptance Test
Command:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/run_acceptance_test.gd
```

Expected result:
- Exit code `0`.
- Output contains `ACCEPTANCE TESTS PASSED`.
