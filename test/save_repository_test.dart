import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wondertail/data/save_repository.dart';
import 'package:wondertail/domain/world_state.dart';

class MemoryStore implements SaveStore {
  final values = <String, String>{};
  final writes = <String>[];
  bool failWrites = false;
  String? failingKey;
  Completer<void>? blocked;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (failWrites || key == failingKey) throw StateError('Storage failure');
    if (blocked != null) {
      final wait = blocked!;
      blocked = null;
      await wait.future;
    }
    writes.add(key);
    values[key] = value;
  }
}

void main() {
  test(
      'a challenge victory saves rewards while retaining the normal checkpoint',
      () async {
    final store = MemoryStore();
    final repo = SaveRepository(store);
    final normal = WorldState(highestUnlocked: 3, x: 380, y: 540);
    normal.bag.crystals = 7;
    normal.vitals.health = 62;
    await repo.save(normal);
    final attempt = WorldState(
        seed: 987,
        islandIndex: 3,
        highestVisited: 3,
        highestUnlocked: 3,
        profile: normal.profile,
        run: TrailRun());
    attempt.bag.crystals = 99;
    attempt.vitals.health = 1;
    attempt.run!.tick(100);
    attempt.run!.finish(attempt.profile);
    await repo.saveRunReward(attempt.profile);
    final recovered = (await SaveRepository(store).load()).state;
    expect((recovered.seed, recovered.islandIndex, recovered.x),
        (normal.seed, 0, 380));
    expect((recovered.profile.coins, recovered.profile.cores), (24, 2));
    expect(recovered.profile.owns(WorkshopItem.runnerCape), isTrue);
    expect(recovered.bag.crystals, 7);
    expect(recovered.vitals.health, 62);
  });
  test('fresh load and active island snapshot round-trip', () async {
    final store = MemoryStore();
    final repo = SaveRepository(store);
    expect((await repo.load()).state.islandIndex, 0);
    final world = WorldState(
      progress: IslandProgress(
        stage: 2,
        collected: 3,
        listened: true,
        rainTime: 2.4,
      ),
    );
    await repo.save(world);
    expect((await SaveRepository(store).load()).state.toJson(), world.toJson());
  });
  test('revisits load the exact saved island memory after restart', () async {
    final store = MemoryStore();
    final repo = SaveRepository(store);
    final world = WorldState(
      highestUnlocked: 4,
      progress: IslandProgress(stage: 3, collected: 7, listened: true),
    );
    await repo.save(world);
    world.travel(4, IslandProgress(stage: 1, collected: 2));
    await repo.save(world);
    final next = SaveRepository(store);
    final loaded = (await next.load()).state;
    expect(loaded.islandIndex, 4);
    expect(loaded.progress.collected, 2);
    final old = await next.loadIsland(0);
    loaded.travel(0, old);
    expect(loaded.progress.complete, isTrue);
    expect(loaded.progress.listened, isTrue);
  });
  test(
    'movement checkpoints do not rewrite historical island caches',
    () async {
      final store = MemoryStore();
      final repo = SaveRepository(store);
      final world = WorldState(highestUnlocked: 10000, highestVisited: 10000);
      await repo.save(world);
      final initialBytes = store.values[SaveRepository.currentKey]!.length;
      store.writes.clear();
      for (var i = 0; i < 5; i++) {
        world.x += 1;
        await repo.save(world);
      }
      expect(
        store.writes.every(
          (key) =>
              key == SaveRepository.currentKey ||
              key == SaveRepository.backupKey,
        ),
        isTrue,
      );
      expect(store.values[SaveRepository.currentKey]!.length,
          lessThanOrEqualTo(initialBytes + 10));
    },
  );
  test(
    'overlapping snapshots are serialized and captured at request time',
    () async {
      final store = MemoryStore();
      final blocker = Completer<void>();
      store.blocked = blocker;
      final repo = SaveRepository(store);
      final world = WorldState();
      final first = repo.save(world);
      world.progress.listened = true;
      final second = repo.save(world);
      world.x += 20;
      blocker.complete();
      await Future.wait([first, second]);
      final restored = (await SaveRepository(store).load()).state;
      expect(restored.progress.listened, isTrue);
      expect(restored.x, world.x - 20);
    },
  );
  test('a corrupt checkpoint recovers the prior header', () async {
    final store = MemoryStore();
    final repo = SaveRepository(store);
    final world = WorldState();
    await repo.save(world);
    world.x += 10;
    await repo.save(world);
    store.values[SaveRepository.currentKey] = 'broken';
    final result = await SaveRepository(store).load();
    expect(result.notice, contains('recovered'));
    expect(result.state.x, world.x - 10);
  });
  test('failed wallet commit recovers atomically without minting coins twice',
      () async {
    final store = MemoryStore();
    final repo = SaveRepository(store);
    final world = WorldState();
    await repo.save(world);
    world.progress.coins = 4095;
    store.failingKey = SaveRepository.currentKey;
    await expectLater(repo.save(world), throwsStateError);
    store.failingKey = null;
    final restart = SaveRepository(store);
    final recovered = (await restart.load()).state;
    expect((recovered.profile.coins, recovered.progress.coins), (0, 0));
    // A stale ahead-of-checkpoint island cache is reconciled once, not lost.
    recovered.progress = await restart.loadIsland(0);
    await restart.save(recovered);
    expect((recovered.profile.coins, recovered.profile.cores), (12, 1));
    await restart.save(recovered);
    expect((await SaveRepository(store).load()).state.profile.coins, 12);
  });
  test('old per-island-only coin saves import once into the global wallet',
      () async {
    final store = MemoryStore();
    final old = WorldState(progress: IslandProgress(coins: 4095));
    final header = old.headerJson()..remove('profile');
    store.values[SaveRepository.currentKey] = jsonEncode(header);
    store.values[SaveRepository.islandKey(0)] =
        jsonEncode(old.progress.toJson());
    final repo = SaveRepository(store);
    final imported = (await repo.load()).state;
    expect((imported.profile.coins, imported.profile.cores), (12, 1));
    await repo.save(imported);
    expect((await SaveRepository(store).load()).state.profile.cores, 1);
  });
  test(
    'a recovered island backup survives a failed write after recovery',
    () async {
      final store = MemoryStore();
      final key = SaveRepository.islandKey(0);
      store.values[key] = '{broken';
      store.values['$key.backup'] = jsonEncode(
        IslandProgress(stage: 2, collected: 1).toJson(),
      );
      final repo = SaveRepository(store);
      final recovered = await repo.loadIsland(0);
      expect(recovered.stage, 2);
      store.failingKey = key;
      await expectLater(
        repo.save(WorldState(progress: recovered)),
        throwsStateError,
      );
      expect((await SaveRepository(store).loadIsland(0)).collected, 1);
    },
  );
  test(
    'failed writes do not poison retries or advance the checkpoint',
    () async {
      final store = MemoryStore();
      final repo = SaveRepository(store);
      await repo.save(WorldState());
      store.failWrites = true;
      await expectLater(
        repo.save(WorldState(progress: IslandProgress(stage: 1))),
        throwsStateError,
      );
      store.failWrites = false;
      expect((await SaveRepository(store).load()).state.progress.stage, 0);
      await repo.save(WorldState(progress: IslandProgress(stage: 1)));
      expect((await SaveRepository(store).load()).state.progress.stage, 1);
    },
  );
}
