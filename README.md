# WONDERTAIL

A little adventure where the world remembers your kindness.

**First playable slice: Little Drift.** Explore an original code-drawn floating island, meet Pip the cloud, restore a grove with rain, plant its seed, and cross your living bridge to Lantern Lookout. This is a short authored prototype, not yet the planned 15-minute MVP.

## Play locally

Install Flutter **3.29.3** (the CI/tested SDK; Dart 3.7.2), then:

```sh
flutter pub get
flutter run -d chrome
```

Move with **WASD**, **arrow keys**, or the on-screen direction buttons. Walk near a landmark and press **E**, **Space**, or the action button. Open the journal with **J** or its book button. Your compass points toward the next part of the adventure. Listening to the crystal is optional and never blocks rescue.

The included web target is ready to run. To create native mobile platform wrappers with your own organization/signing setup:

```sh
flutter create --platforms=android,ios --org com.example --project-name wondertail .
flutter run
```

Review generated platform files before committing them. Android/iOS wrappers and device testing are not included in this first slice.

## What's implemented

- One authored island and a small destination connected by a growable bridge.
- Player-following view, touch/keyboard movement, normalized diagonal speed, shore/rock/pond collisions.
- Complete **rescue → rain → grove → seed → bridge → lookout** consequence chain.
- Optional curiosity choice, cloud companion, animated rain, compass, backpack count, persistent journal.
- Versioned local save snapshots, serialized writes, backup recovery, two-second movement autosaves, immediate quest saves, lifecycle save attempts, and visible write-error feedback.
- Pure Dart rules/map separated from Flame rendering and Flutter UI; deterministic seed-based decorations.

All art is drawn in code. No external asset, AI, account, ad, backend, or gameplay network request is required. No audio is included yet.

## Saves and offline behavior

Progress lives on the current device/browser using `SharedPreferencesAsync`. Clearing app/browser data removes saves; private browsing may discard them. A valid previous snapshot can recover a corrupt current save. `shared_preferences` is suitable for this small prototype but does **not** guarantee durable transactional storage or persistence after an abrupt power loss. A database-backed production save system remains future work. At most the recent unsaved movement can be lost during a normal interruption; abrupt storage failure can lose more.

Native gameplay is designed to work offline once installed. Web needs an initial load; deploy a self-contained build with:

```sh
flutter build web --release --no-web-resources-cdn
```

Serve `build/web` over HTTP(S). Offline reload depends on the browser retaining the generated service-worker cache and has not been device-tested. Do not claim a fresh, uncached web visit works without a network connection.

## Checks

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn
```

Tests cover quest ordering/idempotency, rain continuation after reload, save recovery and write races, deterministic decoration, collision boundaries, bridge/landmark reachability, and basic phone UI/keyboard/dialog behavior. CI runs the same commands. Real-device playtesting, browser reload persistence, accessibility, frame-time profiling, and the planned 15-minute session remain acceptance work.

## Project files

- `lib/domain/`: authoritative world state, authored map and event rules
- `lib/game/`: Flame canvas renderer and movement loop
- `lib/data/`: local save repository and storage adapter
- `lib/ui/`: Flutter controls, dialogue and journal
- `test/`: rules, persistence and UI tests
- [Game design](docs/GAME_DESIGN.md)
- [MVP scope](docs/MVP.md)
- [Architecture and tradeoffs](docs/ARCHITECTURE.md)
- [Roadmap](docs/ROADMAP.md)
- [Visual references](docs/REFERENCES.md)
- [Contribution workflow](CONTRIBUTING.md)

Canonical private repository: https://github.com/AjayJasperJ/wondertail

Distribution licensing is undecided; no open-source license is granted by this repository. Third-party reference images are not bundled or licensed game assets.
