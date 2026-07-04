# BRD - Underwater Extraction Treasure Run

## Business Goal
Create a fast, readable prototype for a 2D underwater extraction game inspired by survival arena readability, risk/reward pressure, and a small boat home-base loop.

## Player Value
Players should understand the loop within seconds: collect recovered objects, avoid patrol monsters, decide whether to extract safely or keep searching for more value, then choose what to do with recovered items on the boat.

## Scope
In scope:
- One playable underwater run.
- Treasure pickup and carried haul tracking.
- Run backpack visibility with pickup and chest rewards entering the backpack immediately.
- Persistent region progression with the rightmost region open first.
- Full-map population where lower-x regions contain denser risk and higher rewards.
- Main-menu debug save controls for progression testing.
- Patrol monster sight penalty and contact death return.
- Anchor extraction prompt and end-of-run banking.
- Debug-accessible boat scene with dive hatch, mission console, purifier device, upload device, and warehouse.
- Runtime backpack and warehouse interactions across the run and boat scenes.

Out of scope:
- Full ship-to-run campaign flow.
- Full save files beyond the small progression state.
- Meta progression.
- Procedural map expansion.

## Success Signals
- The prototype communicates risk versus reward without tutorial text.
- The prototype communicates gradual exploration by revealing new map regions after task progress.
- The player can lose current-run carried treasure from the haul and backpack through detection, and direct monster contact clearly ends the dive.
- The player can bank treasure only by extracting from the anchor.
- Recovered items can be stored or uploaded after returning to the boat.
