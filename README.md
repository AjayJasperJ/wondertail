# WONDERTAIL

An offline floating-island adventure where kindness opens new paths.

**3D version: 0.12.1** · Godot 4.4.1 · `three_d/`

**Current version: 0.8.0** · existing Flutter + Flame edition · `lib/`

## Play in your browser

[Browser preview](https://ajayjasperj.github.io/wondertail/) — live now. Successful builds on
`main` update this same link automatically. Refresh to test the latest
deployment on your phone or computer; no APK installation needed.

## Play the new 3D edition

Explore irregular floating highlands with physical hills, cliffs, trees, ruins,
a ridge bridge, waterfalls and an explorable cave. Free a cloud companion,
gather three skyseeds, solve the cavern's song, defeat a ridge warden and restore
the sky beacon to reach the next seeded island. Discoveries and Starlight persist.

- Rigged Quaternius adventurer/farmer characters and animated biome creatures.
- Muted highland terrain, small grass tufts, mixed leafy trees and pines, a timber
  campsite cabin, rock-framed cave entrance and a recessed shoreline pool.
- Landscape lobby, three explorers with different bodies and movement stats,
  unlocked-island atlas, sound/graphics/camera settings and themed pause menu.
- First-person, trailing, shoulder and tactical cameras, milestone reveal pans,
  north-up loot/mob/objective radar, aiming, physical crouching and three-heart feedback.
- Camera collision, analog movement, sprinting, double
  jumps, sword strikes, stamina-driven dashes, health and safe camp respawns.
- Six biome identities, varied island sizes/coastlines, accessible landmark
  trails, proximity cues and an original synthesized looping score.
- Touch joystick on the left, camera drag over the world, actions on the right,
  compact bottom-center health/stamina and persistent offline progression.
- Nearby unlocked loot pulls into the backpack with wall checks and durable receipts.
  New games start with a bow and 24 arrows; mobs drop ammo, crystal and Starlight.
- Gather wood, crystals and herbs into a saved backpack. Craft a bow, arrows
  and bottled tonics at camp; swap weapons and fight with swept-collision arrows.

Download `wondertail-3d-android`, `wondertail-3d-desktop` or `wondertail-3d-web`
from a successful [Wondertail 3D build](https://github.com/AjayJasperJ/wondertail/actions/workflows/godot.yml).
Android ZIP contains an APK; desktop ZIP contains Windows and Linux executables.
The Android package is separate from the Flutter app, so both can be installed.
CI APKs are release-mode test builds signed with an ephemeral debug key;
in-place updates between CI builds may require matching signing keys.

Open `three_d/project.godot` with **Godot 4.4.1**, then press F5 to play.
Selected models are bundled; no asset downloads, plugins or network services are required.
[Camera/combat features and limits](docs/3D_POLISH_V0.12.md) ·
[Art credits and source licenses](three_d/assets/ASSET_CREDITS.md) ·
[Organized original uploads](source_assets/README.md)

```sh
godot --path three_d
godot --headless --path three_d --editor --quit
godot --headless --path three_d --script tests/smoke.gd
python3 three_d/tests/check_packaging.py
```

Keyboard: WASD/arrows to move, Space to double jump, Shift to sprint, F to strike,
Q to dash, E to interact, B for backpack, Tab to swap weapons, Escape to pause.
Drag the mouse to orbit the camera.
On touch, RUN toggles sprint; all menus pause gameplay. Low detail disables
shadows and distant scenery; new mobile installs default to Low.

This is the first playable 3D conversion, with a smaller feature set than the 2D
edition. Its six biomes remix a finite landmark/quest library. It does not yet
port the remaining 2D arsenal, expanded inventory, three puzzle families or Trailblazer mode.
Old Flutter saves stay in the original app; there is no cross-engine importer.
See [3D gameplay, build instructions and limits](docs/3D_EDITION.md).

## Existing Flutter edition

The v0.8 game remains available with its eight biomes, tactical equipment,
inventory/crafting, cave light gates, three puzzle families, workshop and optional
Trailblazer challenges. Use Flutter **3.29.3** / Dart **3.7.2** and Java 17:

```sh
flutter pub get
flutter run -d chrome
flutter build apk --release
flutter build web --release --no-web-resources-cdn
```

Its [Flutter checks](https://github.com/AjayJasperJ/wondertail/actions/workflows/flutter.yml)
publish `wondertail-android-apk` and `wondertail-web`; these are the **2D** builds.
Older saves retain their visited layouts. Progress is local to the device;
uninstalling either edition removes its own saves.

```sh
dart format --output=none --set-exit-if-changed lib test tool
dart tool/check_release.dart
flutter analyze
flutter test
```

## Documentation

- [CHANGELOG.md](CHANGELOG.md) — separate 3D and Flutter release histories
- [3D edition](docs/3D_EDITION.md) — shipped mechanics, architecture and validation
- [v0.8 Flutter gameplay and limits](docs/ULTIMATE_OVERHAUL_V0.8.md)
- [Contributing](CONTRIBUTING.md)
- [Playtest checklist](docs/PLAYTEST_CHECKLIST.md)
- [Original design](docs/GAME_DESIGN.md) — concept history, not a feature checklist

Automated checks do not establish fun, retention or real-device frame pacing.
Distribution licensing is undecided; this repository grants no open-source license.

