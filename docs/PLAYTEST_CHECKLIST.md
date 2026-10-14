# Revision acceptance: movement, variety and smoothness

Automated tests cannot establish whether exploration is fun or whether the game is smooth on an affected phone. Use a release/profile build for these checks; record the device model, OS, browser/app version and display refresh rate.

## Movement

- Hold the joystick diagonally into a rock, then roll around its edge without lifting your finger. The player should slide along the obstacle without vibrating or becoming trapped.
- Trace the shoreline in both directions. Push outward, turn tangentially, then return inland.
- Release the stick outside its original touch area. Movement should stop; switching tabs or opening an in-game panel must also clear movement.
- Try short, light stick movements and full-speed movements. Confirm gradual speed control and consistent diagonal speed.

## Game UI

- Complete each task using the themed in-game prompts. Check that the character and next action remain understandable.
- Check small portrait phones, landscape and larger screens. Controls, prompts and rewards must not obscure one another.
- Trigger a save failure with a test storage adapter. The themed error should offer recovery without falsely reporting a successful save.

## Continuing exploration

- Complete and leave at least ten islands, including each biome and adventure type.
- Return to a previously changed island, close/reopen the game, and check its layout, collected rewards and completed tasks.
- Confirm a next destination remains available after every completed island.
- Track repeated task patterns. Procedural combinations provide continued content, but perceived variety needs playtesting and more authored mechanics over time.

## Performance

- Compare a fresh game with a long save on the same device and build.
- Watch Flutter DevTools frame timings while moving, colliding, collecting rewards, saving and changing islands. At 60 Hz, frames have about 16.7 ms; at 120 Hz, about 8.3 ms.
- Distinguish UI-thread work from raster-thread work. Capture the exact action causing missed frames before changing effects or rendering.
- Verify that memory settles after repeated island transitions instead of retaining every island's render resources.
- Repeat with reduced effects if available, documenting the difference. Passing unit tests or a desktop web build does not prove smoothness on low-end phones.

## Engagement

Observe rather than direct: does the player find the first activity, understand what changed, discover optional items, and choose to visit another island? Record confusing moments and repeated actions that feel like chores. Adjust task length, variety and feedback from those observations.
