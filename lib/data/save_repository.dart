import 'package:shared_preferences/shared_preferences.dart';

import '../domain/world_state.dart';

abstract class SaveStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class PreferencesSaveStore implements SaveStore {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  @override
  Future<String?> read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);
}

class LoadResult {
  const LoadResult(this.state, {this.notice});
  final WorldState state;
  final String? notice;
}

class SaveRepository {
  SaveRepository(this.store);
  final SaveStore store;
  static const currentKey = 'wondertail.world.v1';
  static const backupKey = 'wondertail.world.v1.backup';
  Future<void> _pending = Future<void>.value();
  String? _lastGood;

  Future<LoadResult> load() async {
    var damaged = false;
    try {
      for (final key in [currentKey, backupKey]) {
        final raw = await store.read(key);
        if (raw == null) continue;
        try {
          final state = WorldState.decode(raw);
          _lastGood = raw;
          return LoadResult(
            state,
            notice: damaged ? 'Recovered your previous local save.' : null,
          );
        } on FormatException {
          damaged = true;
        }
      }
      return LoadResult(
        WorldState(),
        notice: damaged
            ? 'Your save could not be read. A fresh Little Drift is ready.'
            : null,
      );
    } catch (_) {
      return LoadResult(
        WorldState(),
        notice: 'Local storage is unavailable. Progress may not be saved.',
      );
    }
  }

  Future<void> save(WorldState state) {
    // Capture now, then serialize writes so older asynchronous saves cannot win.
    final snapshot = state.encode();
    final write = _pending.then((_) async {
      if (_lastGood != null) await store.write(backupKey, _lastGood!);
      await store.write(currentKey, snapshot);
      _lastGood = snapshot;
    });
    // One failed write must not poison all future retry attempts.
    _pending = write.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return write;
  }
}
