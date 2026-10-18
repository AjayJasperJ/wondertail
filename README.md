# WONDERTAIL

A little adventure where every kindness opens another path.

**Version 0.2: the endless trail.** Roam a floating island, help its creature, change its landscape, and step through a skyway to a newly generated island. Your trail book lets you return to earlier islands and their remembered changes.

## Play locally

Use Flutter **3.29.3** / Dart **3.7.2** (the pinned CI SDK):

```sh
flutter pub get
flutter run -d chrome
```

Drag the on-screen **analog stick**, or use **WASD / arrow keys**. Hold **Shift** to run. Walk near a creature, planting bed or landmark and press **E / Space**, or tap the action button. The golden compass points to the next useful place. **J** opens your trail book; **Escape** closes a card. The book also offers a calmer animation mode.

The web target is included. Android/iOS wrappers, signing and physical-device testing remain separate work:

```sh
flutter create --platforms=android,ios --org com.example --project-name wondertail .
flutter run
```

## Three kinds of wonder

| Adventure | What you do | What changes |
| --- | --- | --- |
| A cloud’s promise | Free Pip, follow the rain, explore for three sunseeds, then bring them to the grove | Trees wake, Pip accompanies you, and a living skyway opens |
| The scattered stars | Follow numbered stepping lights in order, return their song to Luma, then kindle the lantern | The beacon shines, Luma joins you, and a star path opens |
| A garden for a wanderer | Meet Moss, fill a watering can at the garden, then explicitly plant three seed beds | Each planted bed grows immediately; the completed garden opens a skyway |

There is **no authored final island**. A deterministic generator creates the next island on demand, varying biome, name, landmark arrangement, obstacles and decoration. Three biomes mix with the three adventure types. This is an ongoing remix of **finite authored mechanics**, not an unlimited supply of unique stories or an AI story generator. Only one island is active at a time.

## What changed in 0.2

- Continuous analog movement with substeps, collision-normal sliding, gentle head-on obstacle assistance and smooth shoreline projection.
- Illustrated terrain, biome palettes, companions, collectible effects, planting changes and animated skyways.
- In-game parchment encounter cards, trail book and ribbon messages; no modal Flutter dialogs or snackbars.
- A cached static island drawing, event-driven HUD updates and a bounded effect pool. Movement no longer rebuilds the whole Flutter screen.
- Separate island-memory saves and a constant-size position/travel checkpoint; movement autosaves do not rewrite the full explored trail.

These changes address known sources of friction and rendering work. They do **not** establish that every device now runs smoothly; actual mobile frame-time measurements and hands-on playtesting are still required. See the [playtest checklist](docs/PLAYTEST_CHECKLIST.md).

## Saves, migration and offline play

Progress stays on this device/browser using `SharedPreferencesAsync`. Version 1 saves migrate into Little Drift: cloud rescue, listening, grove/seed and bridge completion are retained; the player starts at the redesigned arrival point. A completed old bridge unlocks the next island. Old save keys are retained.

Each island has its own compact memory and backup. The active checkpoint is saved on progress changes, every three seconds while moving, and on app lifecycle changes when possible. Travel checkpoints the old island before loading the new one. Earlier islands reload their saved changes when revisited.

Shared preferences offers **best-effort local persistence**, not durable transactional storage or a power-loss guarantee. Clearing browser/app data removes saves. Private browsing, quotas or storage failure can prevent persistence. Only active map memory and rendering are bounded; saved memories grow with the number of visited islands.

Gameplay has no backend or network dependency. For a self-contained web build:

```sh
flutter build web --release --no-web-resources-cdn
```

Serve `build/web` over HTTP(S). Web needs an initial load. Offline reload depends on the browser retaining its cache and requires browser/device testing. Native gameplay is designed to work offline once installed. No accounts, ads, runtime AI, external art or audio are included.

## Validation

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn
```

CI runs these gates and uploads `wondertail-web` for seven days after a successful build. Regression tests exercise repeated island generation/completion, map reachability, collision sliding, frame-rate-independent movement, ordered lights, planting, migration, revisits, recovery after failed writes, constant-size checkpoint work, joystick release/cancel, narrow/landscape UI and cached-render/HUD behavior. Automated tests cannot establish fun or real-device smoothness.

## Code and design

- `lib/domain/`: seeded maps, island progress, quest rules and collision geometry
- `lib/game/`: Flame loop, cached terrain, characters and effects
- `lib/data/`: checkpoint and island-memory storage
- `lib/ui/`: game-themed HUD, controls, encounter cards and trail book
- [Design](docs/GAME_DESIGN.md) · [MVP](docs/MVP.md) · [Architecture](docs/ARCHITECTURE.md) · [Roadmap](docs/ROADMAP.md)

Canonical private repository: https://github.com/AjayJasperJ/wondertail

Distribution licensing is undecided; no open-source license is granted by this repository. Third-party reference images are not bundled or licensed game assets.

## Android APK

Download **wondertail-android-apk** from the latest successful GitHub Actions run,
extract the ZIP, and open **Wondertail-0.4.0-android.apk** on your Android phone.
Allow installation from your browser or file manager if Android asks.
This is a release-mode test build signed with the Android debug key, not a
Play Store release. CI machines may generate different debug keys; a later
build may require uninstalling the old app, which removes its local save.
Keep important playtest saves in mind before uninstalling.

Build locally with Flutter 3.29.3, Java 17 and the Android SDK:
```sh
flutter pub get
flutter build apk --release
```
Application ID: `com.ajayjasperj.wondertail`.

## 0.3 landscape adventure pass

Android uses landscape orientation and immersive play. The HUD shows one current
objective; a glowing world marker and collision-aware trails lead to landmarks.
Encounter and journal cards occupy less than half the landscape screen width.
Meadow crowns, twilight pines, coral trees, mushrooms, layered paths, distant
islets and a waterfall add distinct environmental detail.

Twelve optional sky coins per island persist with its memory; completing the
collection equips a golden scarf on that island. The skyway previews the actual
next island's name and activity. Three authored task types still repeat; this
update does not claim unlimited unique stories.

Android synthesizes original offline music and proximity, coin, task and
completion cues. Music begins on movement, can be muted using the HUD button,
and stops on app background/audio-focus loss. Web is currently silent.
The audio toggle is session-only. Real-device audio and frame pacing still
need playtesting.


## 0.4 lobby and exploration

The app opens in a landscape lobby. Choose Rowan, Sky or Fern (cosmetic choices),
toggle sound, calm motion and objective markers, or select an unlocked island
in the paginated atlas. Preferences persist with your checkpoint. Use the home
button during play to save and return to the lobby.

Five landform profiles vary island width, height and coastline. Rendered shores
and collision use the same shape function. Mountain cave entrances and scout
lodges connect to the walking trails. Enter a separate walkable crystal chamber
or Wren's furnished map room, meet the scout, collect three cave crystals, and
restore the ancient Sky Archive outside. This optional discovery chain persists
per island and does not block the original main task.

Existing v2 checkpoints retain task and coin progress. Generator revision 3
reshapes the terrain; positions outside the new walkable region reset to the
arrival campsite. Interior saves resume safely at their outdoor entrance.
This is a 2D game: mountains use illustrated height rather than climbable 3D
terrain. Interior layouts and the discovery chain are authored and reused.
