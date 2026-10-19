part of 'world_state.dart';

enum MobKind { hunter, flier, burrower, elite }

class PassiveMob {
  PassiveMob(this.home, this.kind) : position = home;
  final Point2 home;
  Point2 position;
  final int kind;
  double clock = 0;
}

class MobAI {
  static void ensureSpawns(WorldState w) {
    if (w.encounterIsland == w.islandIndex) return;
    w.encounterIsland = w.islandIndex;
    w.hostiles.clear();
    w.passives.clear();
    final seasonal = w.map.season == Season.summer
        ? 1
        : w.map.season == Season.winter
            ? -1
            : 0;
    final count = w.map.expanded
        ? math.min(8, 3 + w.map.difficulty + seasonal)
        : math.min(3, w.map.difficulty);
    for (var i = 0; i < count; i++) {
      final trail = w.map.trails[(2 + i) % w.map.trails.length];
      final home = trail[(trail.length * .75).floor()];
      final enemy = Hostile(home, home, 60 + w.map.difficulty * 5.0);
      enemy.kind = w.map.expanded
          ? switch (w.map.biome) {
              Biome.desert || Biome.underground => MobKind.burrower,
              Biome.heaven || Biome.twilight => MobKind.flier,
              _ => i % 3 == 1 ? MobKind.flier : MobKind.hunter,
            }
          : MobKind.hunter;
      w.hostiles.add(enemy);
    }
    if (w.map.expanded && w.progress.secrets & 2 == 0) {
      final home = w.map.secretPoint(0) + const Point2(80, 0);
      w.hostiles.add(Hostile(home, home, 240 + w.map.difficulty * 15.0)
        ..kind = MobKind.elite);
    }
    for (var i = 0; i < 3; i++) {
      w.passives.add(PassiveMob(w.map.resource(i * 2 + 1), i));
    }
  }

  static bool tick(WorldState w, double dt) {
    if (w.room != 0) return false;
    for (final mob in w.passives) {
      mob.clock += dt;
      final next = mob.home +
          Point2(math.sin(mob.clock * .45 + mob.kind) * 24,
              math.cos(mob.clock * .4) * 16);
      if (w.map.canStand(next)) mob.position = next;
    }
    for (final enemy in w.hostiles) {
      if (!enemy.alive) continue;
      enemy.clock += dt;
      enemy.cooldown -= dt;
      final distance = enemy.position.distanceTo(w.position);
      final chase = distance < 340 && enemy.home.distanceTo(w.position) < 500;
      final target = chase ? w.position : enemy.home;
      var direction = target - enemy.position;
      var speed = 75 + w.map.difficulty * 6.0;
      if (enemy.kind == MobKind.burrower) {
        // Underground movement is visible as a dust ring; the surface bite is
        // telegraphed before its short damage window.
        final phase = enemy.clock % 4;
        enemy.telegraph = phase > 2.6 && phase < 3.1 ? .5 : 0;
        speed = phase < 2.6 ? 125 : 0;
      } else if (enemy.kind == MobKind.flier) {
        final phase = enemy.clock % 3.5;
        enemy.telegraph = phase > 2 && phase < 2.6 ? .6 : 0;
        if (phase < 2.6) {
          speed = 55;
        } else {
          speed = 240;
        }
      } else if (enemy.kind == MobKind.elite) {
        speed = distance < 190 ? 0 : 65;
        enemy.telegraph = enemy.cooldown < .5 ? .5 : 0;
        if (chase && enemy.cooldown <= 0 && w.projectiles.length < 48) {
          enemy.cooldown = 2.5;
          final d = w.position - enemy.position;
          if (d.length > 1) {
            w.projectiles.add(Projectile(
                enemy.position, d * (240 / d.length), 22, 2,
                hostile: true));
          }
        }
      }
      if (direction.length > 2 && speed > 0) {
        if (enemy.kind == MobKind.hunter || enemy.kind == MobKind.elite) {
          // Replan at most once per second, and only while pursuing nearby.
          enemy.telegraph -= dt;
          if (chase &&
              enemy.clock >= 1 &&
              enemy.pathIndex >= enemy.path.length) {
            enemy.clock = 0;
            if (!w.map.navigation.segment(enemy.position, target)) {
              enemy.path = w.map.route(enemy.position, target);
              enemy.pathIndex = 1;
            }
          }
          if (chase && enemy.pathIndex < enemy.path.length) {
            final waypoint = enemy.path[enemy.pathIndex];
            if (enemy.position.distanceTo(waypoint) < 18) enemy.pathIndex++;
            direction = waypoint - enemy.position;
          }
        }
        if (direction.length > 1) {
          final delta = direction *
              (math.min(direction.length, speed * dt) / direction.length);
          if (enemy.kind == MobKind.flier) {
            final next = enemy.position + delta;
            if (w.map.onLand(next)) enemy.position = next;
          } else {
            enemy.position = ActionRules.solidSlide(
                w, enemy.position, w.map.slide(enemy.position, delta));
          }
        }
      }
      final canBite = switch (enemy.kind) {
        MobKind.burrower => enemy.clock % 4 >= 3.1,
        MobKind.flier => enemy.clock % 3.5 >= 2.6,
        _ => true,
      };
      if (chase &&
          canBite &&
          w.vitals.z < 30 &&
          enemy.position.distanceTo(w.position) < 27) {
        final before = w.vitals.health;
        if (ActionRules.damage(w, 12 + w.map.difficulty * 2.0)) return true;
        if (before > w.vitals.health) {
          final d = w.position - enemy.position;
          final next = w.map.slide(
              w.position,
              d *
                  (18 *
                      ExplorerStats.forCharacter(w.character).knockback /
                      math.max(1, d.length)));
          if (EngagementRules.passable(w, next)) {
            w.x = next.x;
            w.y = next.y;
          }
        }
      }
    }
    return false;
  }
}
