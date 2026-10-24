# Wondertail: living island expedition

Identity: a living island expedition where each journey creates a story, earns
useful upgrades, and reveals something unexpected.

Loop: Discover → Decide → Risk → Earn → Upgrade → Return to a changed world.

## Shipped foundation in 3D 0.17

The CAMP button opens an optional contract board. Services require returning to
within 14 metres of the campsite. Choose deliveries of wood, crystal or herbs,
a marked ridge hunt, or a stranded explorer rescue at the ruins. Delivery tasks
consume their materials; encounters must be completed before payment. Contracts
can be repeated, have no countdown, survive reload and award coins plus two
diamonds. Only one contract is active at once. Changing islands keeps it active;
return through the atlas to finish an encounter on its original island.

Coin supplies: eight arrows for five coins, tonic for ten, twelve rounds for eight.
The workshop discounts these prices by two. Diamonds build persistent improvements:

| Improvement | Diamonds | Benefit |
| --- | ---: | --- |
| Workshop | 2 | Supply discounts |
| Garden | 3 | Two herbs per completed contract if space permits |
| Telescope | 4 | Direction and distance hints for remaining field caches |
| Forge | 5 | Five additional melee damage |
| Storage | 3 | Nine additional backpack boxes |

Improvements appear at each island's campsite as simple lightweight props. They
are a shared traveling camp, not a separately streamed home settlement. Normal
exploration no longer requires completing three objectives: CAMP → EXPLORE NEXT
ISLAND opens the next destination. Existing relay/archive/outpost expeditions
remain optional bonus content with their prior rewards.

Lighting now cycles between daylight and moonlit colors while playing; menus
pause it. Wardens resist frontal hits and some hunters approach at a flank.
This is an initial behavior and lighting pass, not a full night ecosystem.

Android edge smoothing is separately selectable: Off / 2× / 4× MSAA. Default 2×
smooths geometry; reduced rendering resolution can still soften or pixelate edges.
Use Custom at 100% resolution for sharper edges, at additional GPU cost.

## Approved roadmap and honest status

### Next visual/gameplay milestone: Colour Archives

The 3D edition now includes bright painted mural panels at the ruins and
colour-coded pennants at the beacon. These are visual anchors for the next
world-mutation activity, not a finished painting game yet. The intended loop is:

1. Find three faded colour waystones on an island.
2. Gather natural pigments from flowers, crystals, and biome materials.
3. Paint a mural by matching a simple pattern or palette challenge.
4. Persist the restored colour in the island save and reveal a nearby discovery.

Painting should alter the world locally (new flowers, warmer lights, opened
shortcuts, or a friendly creature) so it has gameplay value. It should not be a
detached colouring screen or a repetitive tap-for-reward task.

| Priority | Feature | Current status and remaining work |
| --- | --- | --- |
| 1 | Short varied contracts | Deliveries, hunt, rescue repeatable; defense, escort, bridge repair and optional timed cave runs remain planned |
| 2 | Useful currency | Coins buy supplies; diamonds build camp; crystal crafting retained. Cosmetic and weapon skins planned |
| 3 | Evolving home camp | Five visible improvements shipped; blacksmith NPC, rescued population and trophy displays planned |
| 4 | Distinct enemies | Flanking hunters and frontal guardian resistance; burrowing, flying, stalking and pack coordination need further work |
| 5 | Day/night gameplay | Lighting cycle shipped; night-specific spawns, lanterns, rare materials, cave danger and dawn survival rewards planned |
| 6 | Surprises and rumours | Telescope cache hints shipped; distress signals, storms, emerging ruins and changing landmarks planned |
| 7 | Photo and sharing | Planned: HUD hiding, camera orbit, poses, frame with island/contract and export |
| 8 | Weekly seed challenges | Planned: shared weekly seed and starting kit, isolated saves, local time/hits/rescue/discovery scores; no online leaderboard yet |
| 9 | First-five-minute onboarding | Existing movement and contract guidance retained; emergency tutorial, first upgrade and surprise reveal planned |

Discovery events should target a 5–10 minute cadence without forcing departure.
Normal gameplay stays offline and untimed. Challenge timers must be optional,
pause with menus and never overwrite normal progress. No full multiplayer, chat,
large shallow weapon catalog, interrupting ads, energy gates or forced streaks.

The roadmap is an approved direction, not a claim that every row is shipped.
Fun, retention and shareability must be measured through playtests.
