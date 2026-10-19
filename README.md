# WONDERTAIL

An offline floating-island adventure where kindness opens new paths.

**Current version: 0.5.0** · Flutter + Flame · Android and web

Explore islands, help Pip, Luma and Moss, solve cave light-gate puzzles, and restore
ancient archives. Bank Starlight, earn cores, and unlock permanent equipment in
the lobby workshop. From island 4, wind, mist and overgrown paths change how you
explore. Optional Trailblazer runs remix three compact islands against an
active-play clock.

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
explorer appearances, settings, the Loom & Workshop, and Trailblazer Runs.
Touch: drag the analog stick and tap the context action. Keyboard: WASD/arrows,
Shift to sprint, E/Space to interact, J for the journal, Escape to close a card.

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

- [v0.5 gameplay and save details](docs/ENGAGEMENT_UPDATE.md)
- [Contributing](CONTRIBUTING.md)
- [Playtest checklist](docs/PLAYTEST_CHECKLIST.md)
- [Original design](docs/GAME_DESIGN.md) — concept history, not a shipped-feature checklist

The project uses `lib/domain` for game rules, `lib/game` for rendering/audio,
`lib/data` for persistence, and `lib/ui` for menus and controls.

Automated checks do not establish fun, retention or real-device frame pacing.
The engagement scores in the supplied design document are unmeasured targets.
Distribution licensing is undecided; this repository grants no open-source license.
