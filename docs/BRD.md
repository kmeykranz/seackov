# BRD - Underwater Extraction Treasure Run

## Business Goal
Create a fast, readable prototype for a 2D underwater extraction game inspired by survival arena readability, risk/reward pressure, a small boat home-base loop, and a persistent visual story campaign.

## Player Value
Players should understand the loop within seconds: collect recovered objects, avoid patrol monsters, decide whether to extract safely or keep searching for more value, then choose what to do with recovered items on the boat.

## Scope
In scope:
- One playable underwater run.
- Treasure pickup and carried haul tracking.
- Run backpack visibility with pickup and chest rewards entering the backpack immediately.
- Persistent region progression with the rightmost region open first.
- Persistent story progression from purifier repair through signal towers, tunnel repair, ruins investigation, and final escape.
- Visual story objectives placed on the current authored map.
- Full-map population where lower-x regions contain denser risk and higher rewards.
- Main-menu debug save controls for progression testing.
- Patrol monster sight penalty and contact failure page.
- Anchor extraction prompt and end-of-run banking.
- Debug-accessible boat scene with dive hatch, mission console task/spawn panel, purifier device, upload device, and warehouse.
- Runtime backpack and warehouse interactions across the run and boat scenes.
- Story knowledge discovered during dives, uploaded on the boat, and converted into usable placeholder tools.
- Placeholder active tools for disarm, armor block, propulsion, trap control, bomb removal, and electric stun.

Out of scope:
- Finished campaign art, cinematics, and bespoke biome scenes.
- Full save files beyond the small progression state.
- Meta progression.
- Procedural map expansion.

## Success Signals
- The prototype communicates risk versus reward without tutorial text.
- The prototype communicates gradual exploration by revealing new map regions after story tasks rather than only through item thresholds.
- The player can lose current-run carried treasure from the haul and backpack through detection, and direct monster contact clearly ends the dive.
- The player can bank treasure only by extracting from the anchor.
- Recovered items can be stored or uploaded after returning to the boat.
- Discovering and uploading story knowledge makes later dives feel more capable through usable tools, even before final art or full encounter content exists.
- Story beats are visible through terminal overlays, world markers, hold progress bars, the objective HUD, and ending state changes instead of relying only on static text.
