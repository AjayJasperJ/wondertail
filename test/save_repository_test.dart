import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wondertail/data/save_repository.dart';
import 'package:wondertail/domain/world_state.dart';

class MemoryStore implements SaveStore {
  final values = <String, String>{};
  bool failWrites = false;
  Completer<void>? blockFirst;
  int writes = 0;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('No storage space');
    if (writes++ == 0 && blockFirst != null) await blockFirst!.future;
    values[key] = value;
  }
}

void main() {
  test('fresh install loads without a save', () async {
    final loaded = await SaveRepository(MemoryStore()).load();
    expect(loaded.state.cloudRescued, isFalse);
    expect(loaded.notice, isNull);
  });

  test('state survives a new repository instance', () async {
    final store = MemoryStore();
    final state = WorldState(x: 540, y: 340, cloudRescued: true);
    await SaveRepository(store).save(state);
    final loaded = await SaveRepository(store).load();
    expect(loaded.state.toJson(), state.toJson());
  });

  test('corrupt primary recovers a valid backup', () async {
    final store = MemoryStore();
    store.values[SaveRepository.currentKey] = '{broken';
    store.values[SaveRepository.backupKey] =
        WorldState(cloudRescued: true).encode();
    final loaded = await SaveRepository(store).load();
    expect(loaded.state.cloudRescued, isTrue);
    expect(loaded.notice, contains('Recovered'));
  });

  test(
    'corruption in both slots creates a fresh state with a notice',
    () async {
      final store = MemoryStore();
      store.values[SaveRepository.currentKey] = 'bad';
      store.values[SaveRepository.backupKey] = 'bad';
      final loaded = await SaveRepository(store).load();
      expect(loaded.state.cloudRescued, isFalse);
      expect(loaded.notice, contains('could not be read'));
    },
  );

  test(
    'overlapping saves preserve request order and capture snapshots',
    () async {
      final store = MemoryStore()..blockFirst = Completer<void>();
      final repo = SaveRepository(store);
      final world = WorldState();
      final first = repo.save(world);
      world.cloudRescued = true;
      final second = repo.save(world);
      world.groveGrown = true;
      store.blockFirst!.complete();
      await Future.wait([first, second]);
      final loaded = await SaveRepository(store).load();
      expect(loaded.state.cloudRescued, isTrue);
      expect(loaded.state.groveGrown, isFalse);
      final backup = WorldState.decode(store.values[SaveRepository.backupKey]!);
      expect(backup.cloudRescued, isFalse);
    },
  );

  test(
    'failed writes preserve last good data and later retry succeeds',
    () async {
      final store = MemoryStore();
      final repo = SaveRepository(store);
      await repo.save(WorldState());
      store.failWrites = true;
      await expectLater(
        repo.save(WorldState(cloudRescued: true)),
        throwsStateError,
      );
      expect((await SaveRepository(store).load()).state.cloudRescued, isFalse);
      store.failWrites = false;
      await repo.save(WorldState(cloudRescued: true));
      expect((await SaveRepository(store).load()).state.cloudRescued, isTrue);
    },
  );
}
