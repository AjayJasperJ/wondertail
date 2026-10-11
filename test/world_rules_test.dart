import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:wondertail/domain/world_state.dart';

void moveTo(WorldState world, Landmark mark) {
  world.x = mark.x;
  world.y = mark.y;
}

void main() {
  test(
    'complete consequence chain is ordered and each reward happens once',
    () {
      final world = WorldState();
      moveTo(world, IslandMap.bridge);
      expect(WorldRules.act(world, Encounter.bridge), isFalse);
      moveTo(world, IslandMap.grove);
      expect(WorldRules.act(world, Encounter.grove), isFalse);
      moveTo(world, IslandMap.cloud);
      expect(WorldRules.study(world), isTrue);
      expect(WorldRules.study(world), isFalse);
      expect(WorldRules.act(world, Encounter.cloud), isTrue);
      expect(WorldRules.act(world, Encounter.cloud), isFalse);
      expect(WorldRules.advanceRain(world, 3), isFalse);
      expect(world.groveGrown, isFalse);
      expect(WorldRules.advanceRain(world, 1), isTrue);
      expect(WorldRules.advanceRain(world, 10), isFalse);
      moveTo(world, IslandMap.grove);
      expect(WorldRules.act(world, Encounter.grove), isTrue);
      expect(world.pocketSeeds, 1);
      expect(WorldRules.act(world, Encounter.grove), isFalse);
      moveTo(world, IslandMap.bridge);
      expect(WorldRules.act(world, Encounter.bridge), isTrue);
      expect(world.pocketSeeds, 0);
      expect(WorldRules.act(world, Encounter.bridge), isFalse);
      moveTo(world, IslandMap.lookout);
      expect(WorldRules.act(world, Encounter.lookout), isTrue);
      expect(WorldRules.act(world, Encounter.lookout), isFalse);
      expect(world.journal, hasLength(7));
      expect(world.kindnessCount, 2);
    },
  );

  test('rescuing without studying remains possible', () {
    final world = WorldState(x: 540, y: 340);
    expect(WorldRules.act(world, Encounter.cloud), isTrue);
    expect(world.studiedCrystal, isFalse);
  });

  test('remote interactions are rejected', () {
    final world = WorldState();
    expect(WorldRules.act(world, Encounter.cloud), isFalse);
    expect(WorldRules.study(world), isFalse);
    expect(WorldRules.nearby(world), isNull);
  });

  test('saved rain resumes and cannot reward twice', () {
    final world = WorldState(x: 540, y: 340);
    WorldRules.act(world, Encounter.cloud);
    WorldRules.advanceRain(world, 2.5);
    final restored = WorldState.decode(world.encode());
    expect(restored.rainSeconds, 2.5);
    expect(WorldRules.advanceRain(restored, 1.5), isTrue);
    final again = WorldState.decode(restored.encode());
    expect(WorldRules.advanceRain(again, 1.5), isFalse);
    expect(
      again.journal.where((entry) => entry.contains('back to life')),
      hasLength(1),
    );
  });

  test(
    'save round-trip preserves position, seed and completed consequences',
    () {
      final world = WorldState(
        seed: 91,
        x: 1070,
        y: 235,
        studiedCrystal: true,
        cloudRescued: true,
        rainSeconds: 4,
        groveGrown: true,
        seedCollected: true,
        bridgeGrown: true,
        lookoutReached: true,
      );
      expect(WorldState.decode(world.encode()).toJson(), world.toJson());
    },
  );

  test('invalid data and incompatible save versions are rejected', () {
    for (final patch
        in <String, Object>{
          'schemaVersion': 50,
          'generatorVersion': 50,
          'x': 'bad',
          'seed': 2.5,
          'cloudRescued': 'yes',
          'bridgeGrown': true,
        }.entries) {
      final json = WorldState().toJson()..[patch.key] = patch.value;
      expect(() => WorldState.decode(jsonEncode(json)), throwsFormatException);
    }
    expect(() => WorldState.decode('not json'), throwsFormatException);
    expect(() => WorldState.decode('[]'), throwsFormatException);
  });

  test('unsafe saved position returns to the arrival point', () {
    final world = WorldState(x: -999, y: 9999);
    final restored = WorldState.decode(world.encode());
    expect((restored.x, restored.y), (370, 485));
  });

  test('diagonal movement has the same speed and frame spikes are bounded', () {
    final a = WorldState();
    final b = WorldState();
    WorldRules.move(a, 1, 0, 0.05);
    WorldRules.move(b, 1, 1, 0.05);
    double travelled(WorldState w) =>
        math.sqrt(math.pow(w.x - 370, 2) + math.pow(w.y - 485, 2));
    expect(travelled(a), closeTo(travelled(b), 0.00001));
    final spike = WorldState();
    WorldRules.move(spike, 1, 0, 12);
    expect(travelled(spike), closeTo(7.5, 0.00001));
  });

  test('shore, pond and rock collisions stop the player', () {
    expect(IslandMap.canStand(0, 0, false), isFalse);
    expect(IslandMap.canStand(310, 610, false), isFalse);
    expect(IslandMap.canStand(440, 555, false), isFalse);
    final world = WorldState(x: 475, y: 555);
    WorldRules.move(world, -1, 0, 0.05);
    expect(world.x, 475);
  });

  test(
    'bridge is blocked before planting and traversable along its full length',
    () {
      expect(IslandMap.canStand(885, 315, false), isFalse);
      for (var i = 0; i <= 100; i++) {
        final t = i / 100;
        expect(
          IslandMap.canStand(795 + t * 180, 350 - t * 70, true),
          isTrue,
          reason: 'bridge step $i',
        );
      }
    },
  );

  test('all quest landmarks are reachable through valid movement', () {
    // Breadth-first search of a 10-unit navigation grid proves the authored
    // level has a continuous route, including both bridge landings.
    for (final hasBridge in [false, true]) {
      final queue = <(int, int)>[(370, 480)];
      final seen = <(int, int)>{queue.first};
      for (var cursor = 0; cursor < queue.length; cursor++) {
        final (x, y) = queue[cursor];
        for (final (dx, dy) in [(10, 0), (-10, 0), (0, 10), (0, -10)]) {
          final next = (x + dx, y + dy);
          if (!seen.contains(next) &&
              IslandMap.canStand(
                next.$1.toDouble(),
                next.$2.toDouble(),
                hasBridge,
              )) {
            seen.add(next);
            queue.add(next);
          }
        }
      }
      for (final mark in [
        IslandMap.cloud,
        IslandMap.grove,
        IslandMap.bridge,
        if (hasBridge) IslandMap.lookout,
      ]) {
        expect(
          seen.any(
            (p) =>
                IslandMap.distance(p.$1.toDouble(), p.$2.toDouble(), mark) < 30,
          ),
          isTrue,
          reason: mark.title,
        );
      }
      if (!hasBridge) expect(seen.any((p) => p.$1 > 930), isFalse);
    }
  });

  test('decoration is deterministic for a seed and varies across seeds', () {
    expect(IslandMap.flowers(42), IslandMap.flowers(42));
    expect(IslandMap.flowers(42), isNot(IslandMap.flowers(43)));
    expect(IslandMap.flowers(42), isNotEmpty);
  });
}
