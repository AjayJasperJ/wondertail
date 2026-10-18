import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wondertail/domain/world_state.dart';

void stand(WorldState world, Point2 point) {
  world.x = point.x;
  world.y = point.y;
}

void finish(WorldState world) {
  final map = world.map;
  if (map.adventure == Adventure.lantern) {
    for (final point in map.collectibles) {
      stand(world, point);
      WorldRules.collect(world);
    }
  }
  stand(world, map.friend);
  WorldRules.act(world, Encounter.friend);
  if (map.adventure == Adventure.rain) WorldRules.advance(world, 2.4);
  if (map.adventure == Adventure.garden) {
    stand(world, map.wonder);
    WorldRules.act(world, Encounter.wonder);
    for (var i = 0; i < 3; i++) {
      stand(world, map.collectibles[i]);
      WorldRules.act(world, Encounter.values[i + 3]);
    }
  } else {
    for (final point in map.collectibles) {
      stand(world, point);
      WorldRules.collect(world);
    }
    stand(world, map.wonder);
    WorldRules.act(world, Encounter.wonder);
  }
}

void main() {
  test('coin trails are reachable and coin memory survives encode and revisit',
      () {
    for (var island = 0; island < 40; island++) {
      final world = WorldState(
          islandIndex: island, highestUnlocked: island, highestVisited: island);
      for (final coin in world.map.coins) {
        expect(world.map.canStand(coin), isTrue);
        world.x = coin.x;
        world.y = coin.y;
        WorldRules.collectCoins(world);
      }
      expect(world.progress.coinCount, 12);
      final restored = WorldState.decode(world.encode());
      expect(restored.progress.coins, 4095);
      expect(WorldRules.collectCoins(restored), 0);
      for (final trail in world.map.trails) {
        for (var i = 1; i < trail.length; i++) {
          for (var step = 0; step <= 10; step++) {
            expect(
                world.map.canStand(
                    trail[i - 1] + (trail[i] - trail[i - 1]) * (step / 10)),
                isTrue);
          }
        }
      }
    }
  });

  test('the trail keeps generating and completing different adventures', () {
    final world = WorldState();
    final memories = <int, IslandProgress>{};
    final combinations = <String>{};
    for (var index = 0; index < 40; index++) {
      expect(world.islandIndex, index);
      combinations.add('${world.map.biome}/${world.map.adventure}');
      finish(world);
      expect(world.progress.complete, isTrue, reason: 'Island $index');
      expect(world.highestUnlocked, index + 1);
      memories[index] = world.progress;
      expect(world.travel(index + 1, IslandProgress()), isTrue);
    }
    expect(combinations, hasLength(9));
    expect(world.travel(3, memories[3]!), isTrue);
    expect(world.progress.complete, isTrue);
    expect(world.highestUnlocked, 40);
    expect(world.travel(41, IslandProgress()), isFalse);
  });

  test(
    'generation is deterministic and changes positions, obstacles and colors',
    () {
      final a = IslandMap.generate(123, 19),
          b = IslandMap.generate(123, 19),
          c = IslandMap.generate(123, 20);
      expect(a.name, b.name);
      expect(
        a.collectibles.map((p) => (p.x, p.y)),
        b.collectibles.map((p) => (p.x, p.y)),
      );
      expect(
        a.obstacles.map((o) => (o.center.x, o.center.y, o.radius)),
        b.obstacles.map((o) => (o.center.x, o.center.y, o.radius)),
      );
      expect((a.friend.x, a.friend.y), isNot((c.friend.x, c.friend.y)));
    },
  );

  test('generated landmarks and planting beds have continuous paths', () {
    for (var index = 0; index < 24; index++) {
      final map = IslandMap.generate(4271, index);
      final queue = <(int, int)>[(370, 545)];
      final seen = <(int, int)>{queue.first};
      for (var cursor = 0; cursor < queue.length; cursor++) {
        final point = queue[cursor];
        for (final (dx, dy) in [(20, 0), (-20, 0), (0, 20), (0, -20)]) {
          final next = (point.$1 + dx, point.$2 + dy);
          if (!seen.contains(next) &&
              map.canStand(Point2(next.$1.toDouble(), next.$2.toDouble()))) {
            seen.add(next);
            queue.add(next);
          }
        }
      }
      for (final landmark in [
        map.friend,
        map.wonder,
        map.gate,
        ...map.collectibles,
      ]) {
        expect(
          seen.any(
            (p) =>
                Point2(p.$1.toDouble(), p.$2.toDouble()).distanceTo(landmark) <
                27,
          ),
          isTrue,
          reason: 'Island $index landmark',
        );
      }
    }
  });

  test('head-on rocks slide smoothly instead of locking either axis', () {
    for (final direction in [-1.0, 1.0]) {
      final world = WorldState();
      final obstacle = world.map.obstacles.last;
      stand(
        world,
        Point2(
          obstacle.center.x - direction * (obstacle.radius + 18),
          obstacle.center.y,
        ),
      );
      for (var frame = 0; frame < 100; frame++) {
        WorldRules.move(world, direction, 0, 1 / 60);
        expect(
          world.map.canStand(world.position),
          isTrue,
          reason: 'Frame $frame',
        );
      }
      expect(
        (world.x - obstacle.center.x) * direction,
        greaterThan(obstacle.radius),
      );
    }
  });

  test(
    'shoreline diagonal input slides and backing away works immediately',
    () {
      final world = WorldState();
      world.map.obstacles.clear();
      stand(world, const Point2(1067, 480));
      for (var i = 0; i < 80; i++) {
        WorldRules.move(world, 1, 1, 1 / 60);
        expect(world.map.canStand(world.position), isTrue);
      }
      expect(world.y, greaterThan(590));
      final before = world.position;
      WorldRules.move(world, -1, -1, 0.1);
      expect(world.position.distanceTo(before), greaterThan(15));
    },
  );

  test('30 and 60 fps travel equal distances with normalized analog input', () {
    final a = WorldState(), b = WorldState(), slow = WorldState();
    for (final w in [a, b, slow]) {
      w.map.obstacles.clear();
      stand(w, IslandMap.center);
    }
    for (var i = 0; i < 60; i++) {
      WorldRules.move(a, 1, 1, 1 / 60);
    }
    for (var i = 0; i < 30; i++) {
      WorldRules.move(b, 1, 1, 1 / 30);
      WorldRules.move(slow, 0.5, 0, 1 / 30);
    }
    expect(a.position.distanceTo(b.position), lessThan(0.01));
    expect(slow.position.distanceTo(IslandMap.center), closeTo(102.5, 0.01));
  });

  test('a long stalled frame cannot tunnel through a blocker', () {
    final world = WorldState();
    final rock = world.map.obstacles.first;
    stand(world, Point2(rock.center.x - rock.radius - 15, rock.center.y));
    final before = world.position;
    WorldRules.move(world, 1, 0, 5);
    expect(world.map.canStand(world.position), isTrue);
    expect(world.position.distanceTo(before), lessThan(45));
  });

  test(
    'lantern lights must be followed in order without punishing mistakes',
    () {
      final world = WorldState(
        islandIndex: 1,
        highestUnlocked: 1,
        highestVisited: 1,
      );
      while (world.map.adventure != Adventure.lantern) {
        world.highestUnlocked++;
        world.travel(world.islandIndex + 1, IslandProgress());
      }
      stand(world, world.map.collectibles[2]);
      expect(WorldRules.collect(world), isEmpty);
      stand(world, world.map.collectibles[0]);
      expect(WorldRules.collect(world), [0]);
      stand(world, world.map.collectibles[2]);
      expect(WorldRules.collect(world), isEmpty);
      expect(world.progress.count, 1);
      stand(world, world.map.collectibles[1]);
      expect(WorldRules.collect(world), [1]);
      stand(world, world.map.collectibles[2]);
      expect(WorldRules.collect(world), [2]);
    },
  );

  test(
    'garden requires water and explicit planting; walking does not collect',
    () {
      final world = WorldState(
        islandIndex: 2,
        highestUnlocked: 2,
        highestVisited: 2,
      );
      while (world.map.adventure != Adventure.garden) {
        world.highestUnlocked++;
        world.travel(world.islandIndex + 1, IslandProgress());
      }
      stand(world, world.map.collectibles.first);
      expect(WorldRules.act(world, Encounter.bedOne), isFalse);
      stand(world, world.map.friend);
      expect(WorldRules.act(world, Encounter.friend), isTrue);
      stand(world, world.map.wonder);
      expect(WorldRules.act(world, Encounter.wonder), isTrue);
      stand(world, world.map.collectibles.first);
      expect(WorldRules.collect(world), isEmpty);
      expect(WorldRules.act(world, Encounter.bedOne), isTrue);
      expect(world.progress.count, 1);
      expect(WorldRules.act(world, Encounter.bedOne), isFalse);
    },
  );

  test(
    'rain resumes from a checkpoint and completed rewards are idempotent',
    () {
      final world = WorldState();
      stand(world, world.map.friend);
      WorldRules.act(world, Encounter.friend);
      WorldRules.advance(world, 1.2);
      final restored = WorldState.decode(world.encode());
      expect(WorldRules.advance(restored, 1.2), isTrue);
      finish(restored);
      final count = restored.highestUnlocked;
      expect(WorldRules.act(restored, Encounter.wonder), isFalse);
      expect(restored.highestUnlocked, count);
      expect(WorldState.decode(restored.encode()).toJson(), restored.toJson());
    },
  );

  test(
    'v1 cloud and completed bridge memories migrate without losing progress',
    () {
      final legacy = {
        'schemaVersion': 1,
        'generatorVersion': 1,
        'seed': 4271,
        'x': 1070,
        'y': 235,
        'studiedCrystal': true,
        'cloudRescued': true,
        'rainSeconds': 4,
        'groveGrown': true,
        'seedCollected': true,
        'bridgeGrown': true,
        'lookoutReached': true,
      };
      final world = WorldState.decode(jsonEncode(legacy));
      expect(world.map.adventure, Adventure.rain);
      expect(world.progress.complete, isTrue);
      expect(world.progress.listened, isTrue);
      expect(world.highestUnlocked, 1);
      expect(world.map.canStand(world.position), isTrue);
    },
  );

  test('corrupt or future saves are rejected and unsafe positions reset', () {
    final json = WorldState().toJson();
    expect(
      () => WorldState.decode(jsonEncode({...json, 'schemaVersion': 9})),
      throwsFormatException,
    );
    expect(
      () => WorldState.decode(jsonEncode({...json, 'islandIndex': 9})),
      throwsFormatException,
    );
    expect(
      () => WorldState.decode(
        jsonEncode({
          ...json,
          'progress': {'stage': 99},
        }),
      ),
      throwsFormatException,
    );
    final restored = WorldState.decode(jsonEncode({...json, 'x': -500}));
    expect(restored.x, restored.map.arrival.x);
  });
}
