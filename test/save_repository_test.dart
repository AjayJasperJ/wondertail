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
  test('fresh load and active island snapshot round-trip', () async {
    final store = MemoryStore();
    final repo = SaveRepository(store);
    expect((await repo.load()).state.islandIndex, 0);
    final world = WorldState(
        progress: IslandProgress(
            stage: 2, collected: 3, listened: true, rainTime: 2.4));
    await repo.save(world);
    expect((await SaveRepository(store).load()).state.toJson(), world.toJson());
  });
  test('revisits load the exact saved island memory after restart', () async {
    final store = MemoryStore();
    final repo = SaveRepository(store);
    final world = WorldState(
        highestUnlocked: 4,
        progress: IslandProgress(stage: 3, collected: 7, listened: true));
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
  test('movement checkpoint cost does not grow with the visited trail',
      () async {
    final store = MemoryStore();
    final repo = SaveRepository(store);
    final world = WorldState(highestUnlocked: 10000, highestVisited: 10000);
    await repo.save(world);
    store.writes.clear();
    for (var i = 0; i < 5; i++) {
      world.x += 1;
      await repo.save(world);
    }
    expect(
        store.writes.every((key) =>
            key == SaveRepository.currentKey ||
            key == SaveRepository.backupKey),
        isTrue);
    expect(store.values[SaveRepository.currentKey]!.length, lessThan(250));
  });
  test('overlapping snapshots are serialized and captured at request time',
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
  });
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
  test('a recovered island backup survives a failed write after recovery',
      () async {
    final store = MemoryStore();
    final key = SaveRepository.islandKey(0);
    store.values[key] = '{broken';
    store.values['$key.backup'] =
        jsonEncode(IslandProgress(stage: 2, collected: 1).toJson());
    final repo = SaveRepository(store);
    final recovered = await repo.loadIsland(0);
    expect(recovered.stage, 2);
    store.failingKey = key;
    await expectLater(
        repo.save(WorldState(progress: recovered)), throwsStateError);
    expect((await SaveRepository(store).loadIsland(0)).collected, 1);
  });
  test('failed writes do not poison retries or advance the checkpoint',
      () async {
    final store = MemoryStore();
    final repo = SaveRepository(store);
    await repo.save(WorldState());
    store.failWrites = true;
    await expectLater(repo.save(WorldState(progress: IslandProgress(stage: 1))),
        throwsStateError);
    store.failWrites = false;
    expect((await SaveRepository(store).load()).state.progress.stage, 0);
    await repo.save(WorldState(progress: IslandProgress(stage: 1)));
    expect((await SaveRepository(store).load()).state.progress.stage, 1);
  });
}
