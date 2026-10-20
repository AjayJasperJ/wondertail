part of 'world_state.dart';

enum Season { spring, summer, autumn, winter }

extension WorldEcology on IslandMap {
  Season get season => Season.values[(index ~/ 3 + variationSeed) % 4];
  Point2 secretPoint(int n) {
    return secretLocations[n];
  }

  Point2 _secretPoint(int n) {
    final trail = trails[n == 0 ? 8 : 7];
    final anchor = trail[(trail.length * (n == 0 ? .65 : .4)).floor()];
    final candidates = [
      for (final delta in [
        const Point2(130, 90),
        const Point2(-130, 90),
        const Point2(0, 120),
        const Point2(0, -120),
        const Point2(220, 0),
        const Point2(-220, 0),
        const Point2(0, 220),
        const Point2(0, -220),
      ])
        anchor + delta,
      if (n == 0) ...flowers
    ];
    for (final point in candidates) {
      if (!canStand(point)) continue;
      if (n == 0 &&
          (!onLand(point, margin: 75) ||
              trails
                  .any((route) => route.any((p) => p.distanceTo(point) < 90)) ||
              [
                const Point2(-40, -30),
                const Point2(40, -30),
                const Point2(-40, 30),
                const Point2(40, 30)
              ].any((d) => !canStand(point + d)))) {
        continue;
      }
      return point;
    }
    return anchor;
  }

  int get mobLimit => expanded ? 9 : 3;
  Point2 channelDirection(int i) {
    final trail = trails[i == 0 ? 2 : 4];
    final k = (trail.length * (i == 0 ? .54 : .63))
        .floor()
        .clamp(0, trail.length - 1);
    final d =
        trail[math.min(trail.length - 1, k + 1)] - trail[math.max(0, k - 1)];
    return d.length > 0 ? d * (1 / d.length) : const Point2(0, 1);
  }
}

/// Persistent per-map passability cache; bounded by the island, including
/// negative coordinates. A* avoids sweeping a 3x map for every short mob chase.
class NavigationGrid {
  NavigationGrid(this.map) {
    step = map.expanded ? 40 : 20;
    left = (IslandMap.center.x - IslandMap.radiusX * map.scaleX * 1.3) / step;
    top = (IslandMap.center.y - IslandMap.radiusY * map.scaleY * 1.3) / step;
    origin = Point2(left.floor() * step, top.floor() * step);
    width = (IslandMap.radiusX * map.scaleX * 2.6 / step).ceil() + 2;
    height = (IslandMap.radiusY * map.scaleY * 2.6 / step).ceil() + 2;
  }
  final IslandMap map;
  late final double step, left, top;
  late final Point2 origin;
  late final int width, height;
  final Map<int, bool> cells = {};
  Point2 point(int k) =>
      origin + Point2((k % width) * step, (k ~/ width) * step);
  int cell(Point2 p) =>
      ((p.y - origin.y) / step).round() * width +
      ((p.x - origin.x) / step).round();
  bool passable(int k) =>
      k >= 0 &&
      k < width * height &&
      cells.putIfAbsent(
          k,
          () =>
              map.canStand(point(k)) &&
              !map.obstacles
                  .any((o) => point(k).distanceTo(o.center) < o.radius + 18));
  bool segment(Point2 a, Point2 b) {
    final n = math.max(1, (a.distanceTo(b) / 8).ceil());
    for (var i = 0; i <= n; i++) {
      if (!map.canStand(a + (b - a) * (i / n))) return false;
    }
    return true;
  }

  List<Point2> route(Point2 a, Point2 b) {
    int nearest(Point2 p) {
      final c = cell(p);
      for (var r = 0; r < 4; r++) {
        for (var y = -r; y <= r; y++) {
          for (var x = -r; x <= r; x++) {
            final k = c + y * width + x;
            if (passable(k) && segment(p, point(k))) return k;
          }
        }
      }
      return -1;
    }

    final start = nearest(a), end = nearest(b);
    if (start < 0 || end < 0) return [a];
    final parent = <int, int>{start: start}, g = <int, double>{start: 0};
    final open = <int>[start], closed = <int>{};
    double estimate(int k) =>
        (point(k).x - point(end).x).abs() + (point(k).y - point(end).y).abs();
    while (open.isNotEmpty && closed.length < width * height) {
      var at = 0;
      for (var i = 1; i < open.length; i++) {
        if (g[open[i]]! + estimate(open[i]) <
            g[open[at]]! + estimate(open[at])) {
          at = i;
        }
      }
      final current = open.removeAt(at);
      if (current == end) {
        final back = <Point2>[b];
        var c = end;
        while (c != start) {
          back.add(point(c));
          c = parent[c]!;
        }
        return [a, point(start), ...back.reversed];
      }
      closed.add(current);
      for (final d in [-1, 1, -width, width]) {
        final next = current + d;
        if (closed.contains(next) ||
            !passable(next) ||
            !segment(point(current), point(next))) {
          continue;
        }
        final cost = g[current]! + step;
        if (cost < (g[next] ?? double.infinity)) {
          parent[next] = current;
          g[next] = cost;
          if (!open.contains(next)) open.add(next);
        }
      }
    }
    return [a];
  }
}

class WorldGenerator {
  static List<Point2> route(IslandMap map, Point2 a, Point2 b) =>
      map.navigation.route(a, b);
  static void populate(IslandMap map, SeededRandom random) {
    final marks = [
      map.arrival,
      map.friend,
      map.wonder,
      map.gate,
      ...map.collectibles,
      map.cave,
      map.lodge,
      map.ruins
    ];
    for (var i = 0; i < 200 && map.obstacles.length < 28; i++) {
      final p = map.terrainPoint(Point2(
          250 + random.nextDouble() * 780, 220 + random.nextDouble() * 520));
      if (!map.onLand(p, margin: 70) ||
          marks.any((m) => m.distanceTo(p) < 135) ||
          map.obstacles.any((o) => o.center.distanceTo(p) < 110)) {
        continue;
      }
      map.obstacles.add(Obstacle(p, 20 + random.nextDouble() * 16));
    }
    for (var i = 0; i < 36; i++) {
      final p = map.shorePoint(i * math.pi * 2 / 36, inset: 70);
      if (marks.every((m) => m.distanceTo(p) > 80)) map.trees.add(p);
    }
  }

  static bool inLava(WorldState w, Point2 p, int i) {
    final center = w.map.lava(i), d = p - center;
    // A narrow channel crosses the path; jumping clears its 44-unit width.
    final forward = w.map.channelDirection(i);
    final across = d.x * forward.x + d.y * forward.y;
    final along = -d.x * forward.y + d.y * forward.x;
    if (w.progress.secrets & 128 != 0 && i == 0 && along.abs() < 18) {
      return false;
    }
    return across.abs() < 22 && along.abs() < (w.map.expanded ? 105 : 45);
  }

  static bool bridge(WorldState w) {
    if (w.room != 0 ||
        !w.map.expanded ||
        w.progress.secrets & 128 != 0 ||
        w.position.distanceTo(w.map.lava(0)) > 155 ||
        w.bag.crystals < 2 ||
        w.bag.herbs < 2) {
      return false;
    }
    w.bag.crystals -= 2;
    w.bag.herbs -= 2;
    w.progress.secrets |= 128;
    return true;
  }

  static void breach(WorldState w, Point2 at) {
    if (w.map.expanded && at.distanceTo(w.map.secretPoint(0)) < 150) {
      w.progress.secrets |= 1;
    }
  }

  static String? interact(WorldState w) {
    if (w.room == 3) {
      if (w.position.distanceTo(const Point2(640, 380)) > 60) {
        return 'Follow the vault tiles to the sealed chest.';
      }
      if (w.progress.secrets & 2 != 0) {
        return 'This vault has already been collected.';
      }
      w.progress.secrets |= 2;
      w.loadout.owned |= 1 << Weapon.hammer.index;
      w.loadout.ammo = math.min(500, w.loadout.ammo + 20);
      w.bag.boosters = math.min(99, w.bag.boosters + 1);
      return 'Vault restored! Hammer schematic, +20 ammo and a booster.';
    }
    if (w.room != 0) return null;
    var nearest = -1, nearestDistance = 55.0;
    for (var i = 0; i < w.passives.length; i++) {
      final d = w.passives[i].position.distanceTo(w.position);
      if (d < nearestDistance) {
        nearest = i;
        nearestDistance = d;
      }
    }
    final nearSecret = w.map.expanded &&
        (w.position.distanceTo(w.map.secretPoint(0)) < nearestDistance ||
            w.position.distanceTo(w.map.secretPoint(1)) < nearestDistance);
    if (nearest >= 0 && !nearSecret) {
      final i = nearest;
      final flag = 1 << (i + 4);
      if (w.progress.secrets & flag != 0) {
        return 'Your forage friend has already shared its gift on this island.';
      }
      if (w.progress.secrets & flag == 0 &&
          w.passives[i].position.distanceTo(w.position) < 55 &&
          w.bag.weight + 2 <=
              ExplorerStats.forCharacter(w.character).capacity) {
        w.progress.secrets |= flag;
        w.bag.herbs += 2;
        return 'A peaceful forage gift: +2 herbs.';
      }
    }
    if (!w.map.expanded) return null;
    if (w.position.distanceTo(w.map.secretPoint(1)) < 60 &&
        w.progress.secrets & 4 == 0) {
      w.progress.secrets |= 4;
      w.progress.secrets |= 1;
      return 'A lore tablet reveals the wall switch. The hidden vault is open!';
    }
    if (w.position.distanceTo(w.map.secretPoint(0)) < 65) {
      if (w.progress.secrets & 1 == 0) {
        return 'A cracked vault wall. Find its switch or use a grenade / timer charge.';
      }
      if (w.hostiles.any((m) => m.kind == MobKind.elite && m.alive)) {
        return 'The vault guardian is still defending this treasure.';
      }
      if (w.progress.secrets & 2 != 0) {
        return 'This vault has already been collected.';
      }
      w.room = 3;
      w.chamber = 0;
      w.x = 640;
      w.y = 610;
      w.vitals.land();
      return 'A stairway opens into the hidden vault. Explore its sealed chest.';
    }
    if (bridge(w)) return 'A crystal bridge spans the channel.';
    return null;
  }

  static bool environment(WorldState w, double dt) {
    if (w.room != 0) return false;
    final cold = w.map.biome == Biome.winter ||
        (w.map.expanded &&
            w.map.season == Season.winter &&
            w.map.biome != Biome.devils &&
            w.map.biome != Biome.underground);
    final safe = w.position.distanceTo(w.map.arrival) < 160 ||
        w.position.distanceTo(w.map.lodge) < 100;
    w.vitals.warmth =
        (w.vitals.warmth + (safe || !cold ? 8 : -.8) * dt).clamp(0, 100);
    if (w.vitals.warmth <= 0) return ActionRules.damage(w, 6);
    return false;
  }
}
