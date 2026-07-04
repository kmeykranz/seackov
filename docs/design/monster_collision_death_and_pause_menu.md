# Monster Collision Death And Pause Menu Design

## Problem Definition
The player can physically wedge against a monster and be dragged along by `CharacterBody2D` collision response. Monster contact should instead be a fail state: the backpack is emptied and the run returns to the boat. The run also needs an `Esc` pause menu with resume, settings, and exit-to-main-menu options, but no return-to-boat option because boat return must come from extraction or death.

## References
- Godot pause behavior is controlled by `SceneTree.paused`; nodes that need to keep receiving UI/input while paused should use a process mode that runs during pause: https://docs.godotengine.org/en/stable/tutorials/scripting/pausing_games.html
- Godot `CharacterBody2D.move_and_slide()` uses the node's `velocity` and collision masks, so removing physical player/monster body collision prevents push-lock while an Area2D can still detect contact: https://docs.godotengine.org/en/stable/classes/class_characterbody2d.html

## Options Considered
- Keep player/monster body collision and detect slide collisions: rejected because the player can still push or be pushed before the fail state resolves.
- Remove body collision between player and monsters and use the existing monster catch area: selected because it directly prevents wedging and uses the existing contact signal.
- Return to boat from pause: rejected because it bypasses the extraction loop.

## Run Failure State Machine
States:
- `Searching`: player can move, collect, be seen, and touch monsters.
- `Caught`: monster collision has ended the run; backpack is cleared and gameplay is disabled.
- `ReturnedToBoat`: scene changes to the boat.

Events:
- `monster_collision`: `Searching -> Caught -> ReturnedToBoat`.
- `monster_sight`: keeps the existing sight penalty behavior unless collision occurs.

Guards:
- Collision death is ignored after extraction or after already being caught.
- Warehouse and uploaded records are not cleared by collision death.

Side Effects:
- Current backpack slots are emptied.
- Carried value and carried rarity counts are zeroed.
- The scene changes to the boat scene.

## Pause State Machine
States:
- `Running`: gameplay and physics run normally.
- `Paused`: `SceneTree.paused` is true and only pause UI input should be handled.
- `ExitingToMenu`: unpauses and changes to the main menu scene.

Events:
- `press_esc`: toggles `Running` and `Paused`.
- `resume_pressed`: `Paused -> Running`.
- `settings_pressed`: remains paused and shows a placeholder settings message.
- `exit_pressed`: `Paused -> ExitingToMenu`.

Guards:
- Pause cannot return to the boat.
- Death and extraction clear pause before scene change.

## Impact Surface
- `MonsterPatrol`: body collision mask no longer includes player; catch area still detects player contact.
- `RunSceneController`: handles collision death, pause menu signals, and scene transitions.
- `PlayerInventory`: exposes a backpack clear operation.
- `PauseMenuUi`: owns visible pause menu controls.
- Tests and acceptance docs: cover collision death and pause choices.

## Rollback Path
Restore monster body collision with the player, remove collision-death handling from `RunSceneController`, remove the pause menu scene/scripts from `run_scene.tscn`, and restore previous acceptance tests.

## Primitive Acceptance Criteria
- Monster body collision does not physically drag the player.
- Entering a monster catch area clears the backpack and returns to the boat.
- Pressing `Esc` opens a pause menu.
- Resume closes pause and unpauses the run.
- Settings is available as a pause-menu option.
- Exit to main menu does not return to the boat.
