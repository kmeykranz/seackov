# TestCase - Single Underwater Run

## Manual Smoke Test
1. Launch the project.
2. Verify the first screen visibly shows the diver, treasure, reef/wreck cover, seaweed, monster vision cone, and HUD.
3. Move the player with arrow keys or WASD.
4. Pick up at least one treasure and verify carried value increases.
5. Enter seaweed and confirm the player becomes visually tinted as hidden.
6. Let the monster see or touch the player and verify carried treasure clears.
7. Pick up treasure again, enter the anchor area, and verify the two-choice prompt appears.
8. Choose continue and verify the prompt closes while the run remains playable.
9. Re-enter the anchor, choose extraction, and verify carried treasure is banked and the run ends.

## Automated Acceptance Test
Command:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/run_acceptance_test.gd
```

Expected result:
- Exit code `0`.
- Output contains `ACCEPTANCE TESTS PASSED`.
