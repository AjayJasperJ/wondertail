# Technical architecture

## First playable implementation

| Boundary | Implementation |
| --- | --- |
| Real-time presentation | Flame 1.30.1 game loop with original Flutter Canvas art |
| Screens and controls | Flutter widgets; local State ownership |
| Authoritative state | Pure Dart `WorldState`, schema 1, generator 1 |
| Authored rules | `WorldRules` validates proximity and prerequisites; one-time flags make events idempotent |
| Map and movement | Hand-authored ellipses, footprint checks, rock/pond blockers and an unlocked bridge corridor |
| Seeded content | Stable integer generator places cosmetic flowers; terrain is authored |
| Persistence | SharedPreferencesAsync 2.5.3, versioned JSON snapshot and previous-good backup |
| Audio | Deferred |

`lib/game/` presents and animates; `lib/domain/` owns state, eligibility, geometry and consequences; `lib/data/` serializes and stores; `lib/ui/` owns Flutter screens. No Provider/Riverpod dependency is needed for one small state owner. Gameplay has no network dependency.

The view follows the player by translating the canvas. Collision geometry is pure Dart and shared by movement validation and tests. This deliberately avoids a component/tile-map architecture until content justifies it. Two small maps stay loaded; procedural expansion and unloading are not implemented.

## Consequences

The cloud can be studied or freed immediately. Rescue starts four seconds of active gameplay rain; the timer is saved and resumes after reload. Rain restores the grove; collecting its one seed allows planting at the edge; planting unlocks a traversable bridge; the lookout records completion. Repeated interactions do not duplicate inventory or journal entries. Dialogue pauses movement and the rain timer. Losing app focus clears input and pauses the engine.

State changes occur synchronously before their save is requested. Snapshot writes are serialized and capture JSON before entering the queue, so a delayed old write cannot overwrite newer progress. Each save writes the previous known-valid snapshot to a backup key before replacing the current key. A corrupt snapshot or inconsistent prerequisite chain is rejected; invalid positions reset to the arrival point. New schema/generator versions require explicit migration; none is needed for this first version.

## Prototype storage limitations

`shared_preferences` is not a durable transactional database. This two-key scheme offers best-effort recovery, not an atomic multi-key commit or a power-loss guarantee. Native/browser process termination may prevent a lifecycle save from finishing. Movement autosaves every two seconds, quest changes save immediately, and errors remain visible with retry. Storage quotas and browser clearing/private modes can remove progress. Production SQLite (or another durable cross-platform store) remains a separate decision.

## Next architecture work

Profile and playtest this authored loop before adding islands. A future generator needs stable island IDs, versioned terrain rules, deltas, migration/materialization of older islands, active chunk budgets, and bounded archives. Future authored events need explicit IDs, prerequisites, effects, repeat limits and fallback discoveries. Preserve the present separation so those systems do not live in rendering components.
