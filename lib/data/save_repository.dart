import 'dart:convert';

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

/// Constant-size travel/position checkpoint plus independent island memories.
/// Moving never serializes or rewrites the trail of previously visited islands.
class SaveRepository {
  SaveRepository(this.store);
  final SaveStore store;
  static const currentKey = 'wondertail.world.v2';
  static const backupKey = 'wondertail.world.v2.backup';
  static String islandKey(int index) => 'wondertail.island.v2.$index';
  Future<void> _pending = Future<void>.value();
  String? _lastGoodHeader;
  int? _cachedIndex;
  String? _cachedProgress;

  Future<IslandProgress> loadIsland(int index) async {
    for (final key in [islandKey(index), '${islandKey(index)}.backup']) {
      final raw = await store.read(key);
      if (raw == null) continue;
      try {
        final json = jsonDecode(raw);
        if (json is! Map<String, dynamic>) continue;
        return IslandProgress.fromJson(json);
      } on FormatException {
        continue;
      }
    }
    return IslandProgress();
  }

  Future<LoadResult> load() async {
    var damaged = false;
    try {
      for (final key in [currentKey, backupKey]) {
        final raw = await store.read(key);
        if (raw == null) continue;
        try {
          final json = jsonDecode(raw);
          if (json is! Map<String, dynamic> || json['islandIndex'] is! int)
            throw const FormatException('Invalid checkpoint.');
          final memory = await loadIsland(json['islandIndex'] as int);
          final state = WorldState.decode(
              jsonEncode({...json, 'progress': memory.toJson()}));
          _lastGoodHeader = raw;
          return LoadResult(state,
              notice: damaged
                  ? 'Your trail was recovered from its last checkpoint.'
                  : null);
        } on FormatException {
          damaged = true;
        }
      }
      for (final key in ['wondertail.world.v1', 'wondertail.world.v1.backup']) {
        final raw = await store.read(key);
        if (raw == null) continue;
        try {
          return LoadResult(WorldState.decode(raw),
              notice:
                  'Little Drift remembers you. A whole sky of islands is waiting!');
        } on FormatException {
          damaged = true;
        }
      }
      return LoadResult(WorldState(),
          notice: damaged
              ? 'That memory could not be read. A new trail is ready.'
              : null);
    } catch (_) {
      return LoadResult(WorldState(),
          notice:
              'This device cannot save yet. Your adventure can still begin.');
    }
  }

  Future<void> save(WorldState state) {
    final index = state.islandIndex;
    final header = jsonEncode(state.headerJson());
    final memory = jsonEncode(state.progress.toJson());
    final write = _pending.then((_) async {
      if (_cachedIndex != index || _cachedProgress != memory) {
        final key = islandKey(index);
        final previous = await store.read(key);
        if (previous != null) {
          try {
            final json = jsonDecode(previous);
            if (json is Map<String, dynamic>) {
              IslandProgress.fromJson(json);
              await store.write('$key.backup', previous);
            }
          } on FormatException {/* Preserve an existing valid recovery slot. */}
        }
        await store.write(key, memory);
        _cachedIndex = index;
        _cachedProgress = memory;
      }
      if (_lastGoodHeader != null)
        await store.write(backupKey, _lastGoodHeader!);
      await store.write(currentKey, header);
      _lastGoodHeader = header;
    });
    _pending = write.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return write;
  }
}
