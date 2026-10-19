# WONDERTAIL

An offline floating-island adventure where kindness opens new paths.

**Current version: 0.8.0** · Flutter + Flame · Android and web

Explore islands, help Pip, Luma and Moss, solve cave light-gate puzzles, and restore
ancient archives. Bank Starlight, earn cores, and unlock permanent equipment in
the lobby workshop. From island 4, wind, mist and overgrown paths change how you
explore. Optional Trailblazer runs remix three compact islands against an
active-play clock.

The Super-Adventure update adds health, stamina, double jumps, lava, chasers,
close-range combat, a persistent backpack, lodge crafting, and three puzzle-gate
families. Recover at camp without losing your bag when health runs out.

The v0.8 expansion adds directional weapon combos, ranged projectiles, tactical
throwables and powers, forage creatures, flying/burrowing hunters and vault
guardians. Beyond the introduction, new islands expand to three times the width
and height, with desert, snow, underground, volcanic and celestial realms.
Existing saves retain their visited layouts; expansion starts beyond their frontier.

## Play

Use Flutter **3.29.3** / Dart **3.7.2**:

```sh
flutter pub get
flutter run -d chrome
```

For Android, use Java 17 and an installed Android SDK:

```sh
flutter run --release
flutter build apk --release
```

Android uses landscape orientation. The lobby contains island selection,
explorer selection, settings, the Loom & Workshop, and Trailblazer Runs.
Touch: analog stick, context action, and bottom bag/jump/attack/sprint controls.
Keyboard: WASD/arrows, Shift to sprint, Space to jump (again for double jump),
F to attack, E to interact, B for backpack, J for journal, Escape to close a card.
Q cycles weapons; G throws, R activates a power, I explores nearby secrets or
forage creatures and builds a bridge when materials are available. Tap the world
to aim. Tap bottom-center slots to cycle weapon, throwable and power selection.

## What's included

- Three main adventure families, with later ordering and interaction variations.
- Three biomes, five landform profiles, and seeded island layouts.
- Wind currents, visibility-changing mist, and a clearable vine gate from island 4.
- Two- or three-chamber caves with mirror/rune gate puzzles and saved crystals.
- Scout lodges, companion skyseed favors, bond ranks, and functional archives.
- A global Starlight wallet, twelve-coin cores, permanent capes, companion crowns,
  comet trails, and a Glider Cape for safe pond crossings.
- Optional three-island, seven-minute Trailblazer runs after restoring three
  islands; first victory earns a permanent cape and one-time currency reward.
- Local saves, island revisits, backup recovery, and migration of older progress.
- Original synthesized Android music and cues; web audio is currently silent.
- Health and booster bars, gravity-driven jumps, pond falls and campsite recovery.
- Mountain/building/trunk foot colliders and distinct explorer movement/body stats.
- Gather crystals/herbs; craft health tonics, stamina boosters and a guard charm.
- Seeded rope, maze and four-color puzzle gates; an optional maze timer.
- Six weapons, three throwables, three energy powers, lodge gear crafting,
  weight limits, and eight biome identities with progress-driven seasons.
- Animated lava channels, craftable crossings, slippery snow and cold exposure,
  capped biome mobs, hidden switches, lore and explorable guarded vaults.

The island sequence has no authored ending, but its mechanics and modular rooms
come from a finite content library. Progress and unlocks are shared across
islands **on this device**; there are no online accounts or cloud saves.

## Downloads and builds

Download `wondertail-android-apk` from the latest successful
[GitHub Actions run](https://github.com/AjayJasperJ/wondertail/actions), extract
the ZIP, and install the APK. CI also uploads `wondertail-web`.

The APK is a release-mode test build signed with a debug key. Different CI keys
can prevent an in-place update. Uninstalling the app removes local saves.

```sh
flutter build web --release --no-web-resources-cdn
```

Serve `build/web` over HTTP(S). Installed native gameplay is offline; offline web
reload depends on retained browser assets and cache behavior.

## Development

```sh
dart format --output=none --set-exit-if-changed lib test tool
dart tool/check_release.dart
flutter analyze
flutter test
```

Keep release history in [CHANGELOG.md](CHANGELOG.md), not in this README.
Every version bump must have a changelog entry; CI verifies this.

- [v0.8 gameplay, equipment, migration and limits](docs/ULTIMATE_OVERHAUL_V0.8.md)
- [v0.7 gameplay foundation](docs/SUPER_ADVENTURE_V0.7.md)
- [v0.5 progression and save details](docs/ENGAGEMENT_UPDATE.md)
- [Contributing](CONTRIBUTING.md)
- [Playtest checklist](docs/PLAYTEST_CHECKLIST.md)
- [Original design](docs/GAME_DESIGN.md) — concept history, not a shipped-feature checklist

The project uses `lib/domain` for game rules, `lib/game` for rendering/audio,
`lib/data` for persistence, and `lib/ui` for menus and controls.

Automated checks do not establish fun, retention or real-device frame pacing.
The engagement scores in the supplied design document are unmeasured targets.
Distribution licensing is undecided; this repository grants no open-source license.
