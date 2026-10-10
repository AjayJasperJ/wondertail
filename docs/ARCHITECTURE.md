# Proposed technical architecture

These are planning choices, not installed or verified dependencies.

| Component | Proposed approach |
| --- | --- |
| Game loop and rendering | Flame |
| Menus, inventory, settings | Flutter |
| Application state | Provider or Riverpod; choose one at bootstrap |
| Generation | Seeded Dart algorithms |
| Maps | Flame tile/component rendering |
| Movement and collisions | Flame collision system |
| Persistence | SQLite preferred candidate; validate package choice |
| Audio | Flame Audio |
| Events and consequences | Custom pure Dart rule engine |

## Boundaries

`lib/game/` owns real-time presentation and movement. `lib/domain/` owns world state, event eligibility and consequences without rendering dependencies. `lib/data/` owns serialization and storage. `lib/ui/` owns Flutter screens. Keep persistent state authoritative outside visual components.

## Generation and persistence

Store a world seed, save schema version and generator version. Give each island stable coordinates or IDs and derive its seed deterministically using a specified algorithm. Store only deviations from the generated base: changed tiles, inventory, entity state, completed event IDs and unlocked routes.

Seed-only reconstruction requires stable algorithms and content definitions. Version both, or migrate/materialize old islands before changing generation rules. Seeds plus deltas reduce storage, but unlimited player modifications still grow the save; define storage budgets and eventual archival behavior.

## Consequence transaction

Validate prerequisites → construct state changes → commit changes and completed-event marker atomically → update visuals. A repeated interaction must not repeat a one-time reward. Save interrupted transactions safely and keep migrations explicit.

## Event model

An authored event needs an ID, eligible biome/state conditions, dialogue, choices, effects, repeat policy and follow-up unlocks. Validate references and ensure at least one reachable continuation. Randomness selects from eligible authored content; it does not generate unrestricted text.

## Meaningful future tests

Seed determinism; save round-trip and migration; duplicate event application; interrupted save recovery; traversable island entrances/exits; event prerequisites and fallbacks. Profile active chunk counts and frame times on actual target devices.
