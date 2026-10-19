part of 'world_state.dart';

/// Feet use a grounded box; the rendered body and jump height are independent.
class ExplorerStats {
  const ExplorerStats(this.speed, this.width, this.depth, this.strength,
      this.jumpSpeed, this.bodyX, this.bodyY);
  final double speed, width, depth, strength, jumpSpeed, bodyX, bodyY;
  static ExplorerStats forCharacter(int character) => const [
        ExplorerStats(1, 22, 16, 1, 330, 1, 1),
        ExplorerStats(1.12, 18, 14, .8, 365, .84, 1.12),
        ExplorerStats(.92, 28, 20, 1.4, 310, 1.2, .9),
      ][character];
}

class PlayerVitals {
  PlayerVitals({this.health = 100, this.stamina = 100});
  double health, stamina;
  double z = 0, velocityZ = 0, invulnerable = 0, attackCooldown = 0;
  int jumps = 0;
  bool get airborne => z > 0 || velocityZ > 0;
  void land() {
    z = 0;
    velocityZ = 0;
    jumps = 0;
  }

  bool jump(ExplorerStats stats) {
    final cost = jumps == 0 ? 12.0 : 22.0;
    if (jumps >= 2 || stamina < cost) return false;
    stamina -= cost;
    velocityZ = stats.jumpSpeed;
    z = math.max(1, z);
    jumps++;
    return true;
  }

  Map<String, Object> toJson() => {'health': health, 'stamina': stamina};
  factory PlayerVitals.fromJson(dynamic value) {
    if (value == null) return PlayerVitals();
    if (value is! Map) throw const FormatException('Invalid vitals.');
    for (final key in ['health', 'stamina']) {
      final n = value[key];
      if (n is! num || !n.isFinite || n < 0 || n > 100) {
        throw const FormatException('Invalid vitals.');
      }
    }
    // Loading at zero is equivalent to the campsite recovery.
    return PlayerVitals(
        health:
            value['health'] == 0 ? 100 : (value['health'] as num).toDouble(),
        stamina: (value['stamina'] as num).toDouble());
  }
}

enum Recipe { tonic, booster, shield }

class ExpeditionBag {
  ExpeditionBag(
      {this.crystals = 0,
      this.herbs = 0,
      this.tonics = 0,
      this.boosters = 0,
      this.shield = false});
  int crystals, herbs, tonics, boosters;
  bool shield;
  bool craft(Recipe recipe) {
    final c = recipe == Recipe.shield ? 3 : 1;
    final h = recipe == Recipe.tonic ? 2 : 1;
    if ((recipe == Recipe.shield && shield) ||
        crystals < c ||
        herbs < h ||
        (recipe == Recipe.tonic && tonics >= 99) ||
        (recipe == Recipe.booster && boosters >= 99)) return false;
    crystals -= c;
    herbs -= h;
    switch (recipe) {
      case Recipe.tonic:
        tonics++;
      case Recipe.booster:
        boosters++;
      case Recipe.shield:
        shield = true;
    }
    return true;
  }

  bool useTonic(PlayerVitals v) {
    if (tonics == 0 || v.health >= 100) return false;
    tonics--;
    v.health = math.min(100, v.health + 50);
    return true;
  }

  bool useBooster(PlayerVitals v) {
    if (boosters == 0 || v.stamina >= 100) return false;
    boosters--;
    v.stamina = 100;
    return true;
  }

  Map<String, Object> toJson() => {
        'crystals': crystals,
        'herbs': herbs,
        'tonics': tonics,
        'boosters': boosters,
        'shield': shield
      };
  factory ExpeditionBag.fromJson(dynamic value) {
    if (value == null) return ExpeditionBag();
    if (value is! Map || value['shield'] is! bool) {
      throw const FormatException('Invalid backpack.');
    }
    for (final key in ['crystals', 'herbs', 'tonics', 'boosters']) {
      final n = value[key];
      if (n is! int ||
          n < 0 ||
          n > (key == 'tonics' || key == 'boosters' ? 99 : 999999)) {
        throw const FormatException('Invalid backpack count.');
      }
    }
    return ExpeditionBag(
        crystals: value['crystals'],
        herbs: value['herbs'],
        tonics: value['tonics'],
        boosters: value['boosters'],
        shield: value['shield']);
  }
}

class SolidBox {
  const SolidBox(this.left, this.top, this.right, this.bottom);
  final double left, top, right, bottom;
  bool contains(Point2 p, ExplorerStats s) =>
      p.x + s.width / 2 > left &&
      p.x - s.width / 2 < right &&
      p.y + s.depth / 2 > top &&
      p.y - s.depth / 2 < bottom;
}

extension AdventureZones on IslandMap {
  Point2 resource(int i) =>
      trails[i % trails.length]
          [(trails[i % trails.length].length * .28).floor()] +
      Point2(i.isEven ? 14 : -14, 0);
  Point2 get arena => trails[2][(trails[2].length * .54).floor()];
  int get difficulty => math.min(8, 1 + index ~/ 3);
  Point2 lava(int i) =>
      i == 0 ? arena : trails[4][(trails[4].length * .63).floor()];
  int get lavaCount => index < 3 ? 1 : 2;
}

class Hostile {
  Hostile(this.position, this.home, this.health);
  Point2 position;
  final Point2 home;
  double health;
  bool get alive => health > 0;
}

class ActionRules {
  static void unlock(WorldState w) {
    if (w.progress.complete && (w.run != null || w.progress.puzzleCleared)) {
      w.highestUnlocked = math.max(w.highestUnlocked, w.islandIndex + 1);
    }
  }

  static bool clearGateway(WorldState w, GatewayPuzzle p) {
    if (!w.progress.complete ||
        p.seed != w.seed ||
        p.index != w.islandIndex ||
        !p.solved ||
        w.room != 0 ||
        w.position.distanceTo(w.map.gate) > 88) return false;
    w.progress.puzzleCleared = true;
    unlock(w);
    return true;
  }

  static bool groundedClear(WorldState w, Point2 p) => !w.map.solidBoxes
      .any((b) => b.contains(p, ExplorerStats.forCharacter(w.character)));
  static Point2 solidSlide(WorldState w, Point2 from, Point2 next) {
    if (groundedClear(w, next)) return next;
    final x = Point2(next.x, from.y), y = Point2(from.x, next.y);
    if (groundedClear(w, x)) return x;
    if (groundedClear(w, y)) return y;
    return from;
  }

  static bool jump(WorldState w) =>
      w.vitals.jump(ExplorerStats.forCharacter(w.character));
  static int gather(WorldState w) {
    if (w.room != 0 || w.vitals.airborne) return 0;
    var count = 0;
    for (var i = 0; i < 6; i++) {
      if (w.progress.gathered & (1 << i) != 0 ||
          w.position.distanceTo(w.map.resource(i)) > 30) continue;
      w.progress.gathered |= 1 << i;
      if (i.isEven) {
        w.bag.crystals = math.min(999999, w.bag.crystals + 1);
      } else {
        w.bag.herbs = math.min(999999, w.bag.herbs + 2);
      }
      count++;
    }
    return count;
  }

  static bool attack(WorldState w) {
    final v = w.vitals;
    if (v.attackCooldown > 0 || v.stamina < 8) return false;
    v.stamina -= 8;
    v.attackCooldown = .45;
    w.attackFlash = .22;
    final strength = ExplorerStats.forCharacter(w.character).strength;
    for (final enemy in w.hostiles) {
      if (enemy.alive && enemy.position.distanceTo(w.position) < 90) {
        enemy.health -= 35 * strength;
        final d = enemy.position - w.position;
        final next = enemy.position + d * (32 / math.max(1, d.length));
        if (w.map.canStand(next) && groundedClear(w, next))
          enemy.position = next;
      }
    }
    return true;
  }

  static bool damage(WorldState w, double amount) {
    if (w.vitals.invulnerable > 0) return false;
    w.vitals.health =
        math.max(0, w.vitals.health - amount * (w.bag.shield ? .6 : 1));
    w.vitals.invulnerable = 1.2;
    if (w.vitals.health == 0) {
      w.room = 0;
      w.chamber = 0;
      w.x = w.map.arrival.x;
      w.y = w.map.arrival.y;
      w.vitals.health = 100;
      w.vitals.stamina = 100;
      w.vitals.land();
      w.hostiles.clear();
      w.encounterIsland = -1;
      return true;
    }
    return false;
  }

  /// Returns a campsite-respawn event. All clocks stop when the game is paused.
  static bool tick(WorldState w, double seconds,
      {bool sprint = false, bool moving = false}) {
    final dt = seconds.clamp(0.0, .15), v = w.vitals;
    v.invulnerable = math.max(0, v.invulnerable - dt);
    v.attackCooldown = math.max(0, v.attackCooldown - dt);
    w.attackFlash = math.max(0, w.attackFlash - dt);
    v.stamina = (v.stamina +
            (sprint && moving && v.stamina > 1
                    ? -28
                    : moving
                        ? 12
                        : 24) *
                dt)
        .clamp(0, 100);
    if (v.airborne) {
      v.velocityZ -= 780 * dt;
      v.z += v.velocityZ * dt;
      if (v.z <= 0) v.land();
    }
    if (w.encounterIsland != w.islandIndex) {
      w.encounterIsland = w.islandIndex;
      w.hostiles.clear();
      for (var i = 0; i < math.min(3, w.map.difficulty); i++) {
        final home =
            w.map.trails[2 + i][(w.map.trails[2 + i].length * .75).floor()];
        w.hostiles.add(Hostile(home, home, 60 + w.map.difficulty * 5.0));
      }
    }
    if (w.room != 0) {
      if (w.room == 1 &&
          w.chamber > 0 &&
          v.z < 26 &&
          w.position.distanceTo(const Point2(700, 560)) < 34)
        return damage(w, 25);
      return false;
    }
    if (v.z < 20 &&
        w.map.obstacles.any(
            (o) => o.pond && w.position.distanceTo(o.center) < o.radius + 8)) {
      // A missed pond jump is a fall, with a guaranteed safe landing at camp.
      v.health = 1;
      v.invulnerable = 0;
      return damage(w, 100);
    }
    for (var i = 0; i < w.map.lavaCount; i++) {
      if (v.z < 26 && w.position.distanceTo(w.map.lava(i)) < 27) {
        if (damage(w, 25)) return true;
      }
    }
    for (final enemy in w.hostiles) {
      if (!enemy.alive) continue;
      final chase = enemy.position.distanceTo(w.position) < 210 &&
          enemy.home.distanceTo(w.position) < 270;
      final target = chase ? w.position : enemy.home;
      final delta = target - enemy.position;
      if (delta.length > 2) {
        final next = w.map.slide(
            enemy.position,
            delta *
                (math.min(delta.length, (72 + w.map.difficulty * 7) * dt) /
                    delta.length));
        enemy.position = solidSlide(w, enemy.position, next);
      }
      if (v.z < 30 && enemy.position.distanceTo(w.position) < 27) {
        if (damage(w, 12 + w.map.difficulty * 2.0)) return true;
      }
    }
    return false;
  }
}

enum PuzzleKind { rope, maze, coloring }

/// Each puzzle has a constructive solution; validators inspect the player's
/// actual board, rather than trusting a UI completion button.
class GatewayPuzzle {
  GatewayPuzzle(this.seed, this.index) : kind = PuzzleKind.values[index % 3] {
    final r = SeededRandom((seed ^ (index * 104729)) & 0x7fffffff);
    // A cycle starts scrambled. A convex polygon always untangles this graph.
    nodes = List.generate(6, (i) {
      final a = (i * 5 % 6) * math.pi / 3 + .3;
      return Point2(.5 + math.cos(a) * .38, .5 + math.sin(a) * .38);
    });
    final swap = nodes[1];
    nodes[1] = nodes[3];
    nodes[3] = swap;
    for (var i = 5; i > 0; i--) {
      final j = r.nextInt(i + 1), temp = nodes[i];
      nodes[i] = nodes[j];
      nodes[j] = temp;
    }
    if (ropeSolved) {
      final temp = nodes[1];
      nodes[1] = nodes[3];
      nodes[3] = temp;
    }
    // DFS carves a connected perfect maze on a 5x5 cell graph.
    mazeEdges = <int>{};
    final seen = <int>{0}, stack = <int>[0];
    while (stack.isNotEmpty) {
      final a = stack.last;
      final next = [
        if (a % 5 > 0) a - 1,
        if (a % 5 < 4) a + 1,
        if (a >= 5) a - 5,
        if (a < 20) a + 5
      ].where((b) => !seen.contains(b)).toList();
      if (next.isEmpty) {
        stack.removeLast();
        continue;
      }
      final b = next[r.nextInt(next.length)];
      mazeEdges.add(edge(a, b));
      seen.add(b);
      stack.add(b);
    }
    // 3x3 tiled planar map; random diagonals increase the constraint variety.
    borders = <int>{};
    for (var i = 0; i < 9; i++) {
      if (i % 3 < 2) borders.add(edge(i, i + 1));
      if (i < 6) borders.add(edge(i, i + 3));
      if (i < 6 && i % 3 < 2 && r.nextInt(2) == 0) borders.add(edge(i, i + 4));
    }
  }
  final PuzzleKind kind;
  final int seed, index;
  late final List<Point2> nodes;
  late final Set<int> mazeEdges, borders;
  final List<int> colors = List.filled(9, -1);
  int mazeCell = 0;
  static int edge(int a, int b) => math.min(a, b) * 100 + math.max(a, b);
  bool mazeMove(int next) {
    if (next < 0 || next >= 25 || !mazeEdges.contains(edge(mazeCell, next)))
      return false;
    mazeCell = next;
    return true;
  }

  static double cross(Point2 a, Point2 b, Point2 c) =>
      (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
  bool get ropeSolved {
    for (var i = 0; i < 6; i++) {
      if (nodes[i].distanceTo(nodes[(i + 1) % 6]) < .08) return false;
      for (var j = i + 1; j < 6; j++) {
        if (nodes[i].distanceTo(nodes[j]) < .08) return false;
        if (j == i + 1 || (i == 0 && j == 5)) continue;
        final a = nodes[i],
            b = nodes[(i + 1) % 6],
            c = nodes[j],
            d = nodes[(j + 1) % 6];
        if (cross(a, b, c) * cross(a, b, d) <= 0 &&
            cross(c, d, a) * cross(c, d, b) <= 0) return false;
      }
    }
    return true;
  }

  bool get coloringSolved =>
      colors.every((c) => c >= 0 && c < 4) &&
      borders.every((e) => colors[e ~/ 100] != colors[e % 100]);
  bool get solved => switch (kind) {
        PuzzleKind.rope => ropeSolved,
        PuzzleKind.maze => mazeCell == 24,
        PuzzleKind.coloring => coloringSolved,
      };
}
