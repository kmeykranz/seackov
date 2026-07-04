# BRD - Underwater Extraction Treasure Run

## Business Goal
Create a fast, readable prototype for a 2D underwater extraction game inspired by survival arena readability, risk/reward pressure, and a small boat home-base loop.

## Player Value
Players should understand the loop within seconds: collect recovered objects, avoid patrol monsters, decide whether to extract safely or keep searching for more value, then choose what to do with recovered items on the boat.

## Scope
In scope:
- One playable underwater run.
- Treasure pickup and carried haul tracking.
- Patrol monster detection and catch penalty.
- Anchor extraction prompt and end-of-run banking.
- Debug-accessible boat scene with dive hatch, mission console, purifier device, upload device, and warehouse.
- Runtime backpack transfer from extracted runs to boat interactions.

Out of scope:
- Full ship-to-run campaign flow.
- Persistent save files.
- Meta progression.
- Procedural map expansion.

## Success Signals
- The prototype communicates risk versus reward without tutorial text.
- The player can lose carried treasure through detection.
- The player can bank treasure only by extracting from the anchor.
- Recovered items can be stored or uploaded after returning to the boat.
