import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:wondertail/domain/world_state.dart';

void main() {
  test('jump has two impulses, stamina costs, gravity, and safe landing', () {
    final w = WorldState();
    expect(ActionRules.jump(w), isTrue);
    expect(ActionRules.jump(w), isTrue);
    expect(ActionRules.jump(w), isFalse);
    expect(w.vitals.stamina, 66);
    for (var i = 0; i < 120; i++) {
      ActionRules.tick(w, 1 / 60);
    }
    expect(w.vitals.z, 0);
    expect(w.vitals.jumps, 0);
    expect(w.vitals.health, 100);
    w.vitals.stamina = 0;
    expect(ActionRules.jump(w), isFalse);
  });
  test('damage has immunity, shield mitigation, and lossless campsite recovery',
      () {
    final w = WorldState(bag: ExpeditionBag(crystals: 7));
    expect(ActionRules.damage(w, 30), isFalse);
    expect(w.vitals.health, 70);
    ActionRules.damage(w, 30);
    expect(w.vitals.health, 70);
    w.vitals.invulnerable = 0;
    w.bag.shield = true;
    ActionRules.damage(w, 30);
    expect(w.vitals.health, 52);
    w.vitals.invulnerable = 0;
    expect(ActionRules.damage(w, 200), isTrue);
    expect(w.vitals.health, 100);
    expect(w.position.distanceTo(w.map.arrival), 0);
    expect(w.bag.crystals, 7);
  });
  test('lava hurts grounded players and a high jump avoids it', () {
    final w = WorldState();
    final lava = w.map.lava(0);
    w.x = lava.x;
    w.y = lava.y;
    ActionRules.tick(w, .01);
    expect(w.vitals.health, 75);
    w.vitals.invulnerable = 0;
    w.vitals.z = 60;
    ActionRules.tick(w, .01);
    expect(w.vitals.health, 75);
  });
  test('attack is limited by stamina and cooldown; strength changes damage',
      () {
    final results = <double>[];
    for (var c = 0; c < 3; c++) {
      final w = WorldState(character: c);
      final enemy = Hostile(w.position, w.position, 100);
      w.hostiles.add(enemy);
      expect(ActionRules.attack(w), isTrue);
      expect(ActionRules.attack(w), isFalse);
      results.add(enemy.health);
    }
    expect(results[1], greaterThan(results[0]));
    expect(results[2], lessThan(results[0]));
  });
  test('crafting is transactional, items are usable, old saves get defaults',
      () {
    final w = WorldState(bag: ExpeditionBag(crystals: 5, herbs: 5));
    expect(w.bag.craft(Recipe.shield), isTrue);
    expect(w.bag.craft(Recipe.shield), isFalse);
    expect(w.bag.crystals, 2);
    expect(w.bag.craft(Recipe.tonic), isTrue);
    w.vitals.health = 30;
    expect(w.bag.useTonic(w.vitals), isTrue);
    expect(w.vitals.health, 80);
    expect(w.bag.useTonic(w.vitals), isFalse);
    final restored = WorldState.decode(w.encode());
    expect(restored.bag.toJson(), w.bag.toJson());
    expect(restored.vitals.health, 80);
    final old = w.toJson()
      ..remove('bag')
      ..remove('vitals');
    expect(WorldState.decode(jsonEncode(old)).vitals.health, 100);
    expect(WorldState.decode(jsonEncode(old)).bag.crystals, 0);
  });
  test('gathering is saved once and normal bags are isolated from trial bags',
      () {
    final w = WorldState();
    for (var i = 0; i < 6; i++) {
      final p = w.map.resource(i);
      w.x = p.x;
      w.y = p.y;
      ActionRules.gather(w);
    }
    expect(w.bag.crystals, 3);
    expect(w.bag.herbs, 6);
    final restored = WorldState.decode(w.encode());
    final p = restored.map.resource(0);
    restored.x = p.x;
    restored.y = p.y;
    expect(ActionRules.gather(restored), 0);
    final trial = WorldState(profile: w.profile, run: TrailRun());
    trial.bag.crystals = 90;
    expect(w.bag.crystals, 3);
  });
  test('mountain and trunk feet block movement while landmarks stay reachable',
      () {
    for (var i = 0; i < 80; i++) {
      final w = WorldState(
          seed: 4271 + i ~/ 40,
          islandIndex: i % 40,
          highestVisited: i % 40,
          highestUnlocked: i % 40,
          run: i.isOdd ? TrailRun() : null);
      expect(w.map.canStand(w.map.arrival), isTrue);
      for (final trail in w.map.trails) {
        for (var j = 1; j < trail.length; j++) {
          for (var t = 0; t <= 10; t++) {
            expect(
                w.map.canStand(
                    trail[j - 1] + (trail[j] - trail[j - 1]) * (t / 10)),
                isTrue,
                reason: 'Island $i trail segment $j');
          }
        }
      }
    }
    final w = WorldState();
    w.x = w.map.cave.x;
    w.y = w.map.cave.y + 20;
    for (var i = 0; i < 120; i++) {
      WorldRules.move(w, 0, -1, 1 / 60);
    }
    expect(w.y, greaterThanOrEqualTo(w.map.cave.y - 20));
  });
  test('all three puzzle families have validated solutions over 90 seeds', () {
    for (var index = 0; index < 90; index++) {
      final p = GatewayPuzzle(4271 + index, index);
      expect(p.solved, isFalse);
      switch (p.kind) {
        case PuzzleKind.rope:
          for (var i = 0; i < 6; i++) {
            final a = i * math.pi / 3;
            p.nodes[i] = Point2(.5 + math.cos(a) * .38, .5 + math.sin(a) * .38);
          }
        case PuzzleKind.maze:
          final parent = <int, int>{0: -1}, q = <int>[0];
          for (var i = 0; i < q.length; i++) {
            final a = q[i];
            for (final e in p.mazeEdges) {
              final x = e ~/ 100, y = e % 100;
              final b = x == a
                  ? y
                  : y == a
                      ? x
                      : -1;
              if (b >= 0 && !parent.containsKey(b)) {
                parent[b] = a;
                q.add(b);
              }
            }
          }
          final route = <int>[];
          for (var n = 24; n != 0; n = parent[n]!) {
            route.add(n);
          }
          for (final n in route.reversed) {
            expect(p.mazeMove(n), isTrue);
          }
        case PuzzleKind.coloring:
          bool solve(int i) {
            if (i == 9) return p.coloringSolved;
            for (var c = 0; c < 4; c++) {
              p.colors[i] = c;
              if (p.borders
                      .every((e) => e % 100 != i || p.colors[e ~/ 100] != c) &&
                  solve(i + 1)) {
                return true;
              }
            }
            p.colors[i] = -1;
            return false;
          }
          expect(solve(0), isTrue);
      }
      expect(p.solved, isTrue, reason: 'Puzzle $index');
    }
  });
  test('gateway requires correct solved board and main restoration', () {
    final w = WorldState();
    final p = GatewayPuzzle(w.seed, 0);
    w.x = w.map.gate.x;
    w.y = w.map.gate.y;
    expect(ActionRules.clearGateway(w, p), isFalse);
    w.progress.stage = 3;
    ActionRules.unlock(w);
    expect(w.highestUnlocked, 0);
    expect(ActionRules.clearGateway(w, p), isFalse);
    for (var i = 0; i < 6; i++) {
      p.nodes[i] = Point2(.5 + .38 * math.cos(i * math.pi / 3),
          .5 + .38 * math.sin(i * math.pi / 3));
    }
    expect(ActionRules.clearGateway(w, p), isTrue);
    expect(w.highestUnlocked, 1);
    expect(WorldState.decode(w.encode()).progress.puzzleCleared, isTrue);
  });
}
