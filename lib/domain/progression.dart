part of 'world_state.dart';

enum WorkshopItem { starCape, sparkTrail, companionHat, gliderCape, runnerCape }

extension WorkshopDetails on WorkshopItem {
  String get title => [
        'Starweave Cape',
        'Comet Trail',
        'Companion Crown',
        'Glider Cape',
        'Trailblazer Cape'
      ][index];
  int get coins => [12, 24, 18, 36, 0][index];
  int get cores => [0, 1, 1, 2, 0][index];
  String get description => [
        'A permanent golden explorer cape.',
        'Leave a short trail of starlight while walking.',
        'A little crown for your creature companion.',
        'Hop across a pond from a safe nearby bank.',
        'Earned by finishing a three-island Trailblazer run.'
      ][index];
}

/// Reward receipts live with the wallet in the authoritative checkpoint.
/// Re-entering an island or replaying a failed write cannot mint its rewards twice.
class PlayerProfile {
  int coins = 0, cores = 0, seeds = 0, owned = 0, cape = 0;
  bool trail = false, hat = false;
  final List<int> bonds = [0, 0, 0];
  final Map<String, int> receipts = {};
  int runsStarted = 0, bestRunMillis = 0;
  bool runWon = false;
  bool owns(WorkshopItem item) => (owned & (1 << item.index)) != 0;
  int rank(Adventure creature) => bonds[creature.index] >= 4
      ? 3
      : bonds[creature.index] >= 2
          ? 2
          : 1;
  int get archives =>
      receipts.values.where((value) => (value & (1 << 13)) != 0).length;
  double get coinRadius => 28 + math.min(archives, 3) * 8.0;

  bool purchase(WorkshopItem item) {
    if (item == WorkshopItem.runnerCape ||
        owns(item) ||
        coins < item.coins ||
        cores < item.cores) {
      return false;
    }
    coins -= item.coins;
    cores -= item.cores;
    owned |= 1 << item.index;
    equip(item);
    return true;
  }

  void equip(WorkshopItem item) {
    if (!owns(item)) return;
    switch (item) {
      case WorkshopItem.starCape:
        cape = 1;
      case WorkshopItem.gliderCape:
        cape = 2;
      case WorkshopItem.runnerCape:
        cape = 3;
      case WorkshopItem.sparkTrail:
        trail = !trail;
      case WorkshopItem.companionHat:
        hat = !hat;
    }
  }

  void reconcile(WorldState world) {
    if (world.run != null) return;
    final p = world.progress;
    final key = '${world.seed}:${world.islandIndex}';
    var paid = receipts[key] ?? 0;
    final newCoins = p.coins & ~(paid & 4095);
    coins += newCoins.toRadixString(2).replaceAll('0', '').length;
    paid |= p.coins;
    if (p.coins == 4095 && (paid & (1 << 12)) == 0) {
      cores++;
      paid |= 1 << 12;
    }
    if (p.ruinsRestored && (paid & (1 << 13)) == 0) {
      paid |= 1 << 13;
    }
    if (p.complete && (paid & (1 << 14)) == 0) {
      bonds[world.map.adventure.index]++;
      paid |= 1 << 14;
    }
    if (p.favorGiven && (paid & (1 << 15)) == 0) {
      if (seeds > 0) {
        seeds--;
        bonds[world.map.adventure.index]++;
        paid |= 1 << 15;
      }
    }
    if (world.map.adventure == Adventure.rain &&
        p.stage >= 2 &&
        rank(Adventure.rain) >= 2 &&
        (paid & (1 << 16)) == 0) {
      coins += rank(Adventure.rain) == 3 ? 3 : 1;
      paid |= 1 << 16;
    }
    if (p.cacheOpened && (paid & (1 << 17)) == 0) {
      coins += 3;
      seeds += rank(Adventure.garden) == 3 ? 2 : 1;
      paid |= 1 << 17;
    }
    if (paid != 0) receipts[key] = paid;
  }

  Map<String, Object> toJson() => {
        'coins': coins,
        'cores': cores,
        'seeds': seeds,
        'owned': owned,
        'cape': cape,
        'trail': trail,
        'hat': hat,
        'bonds': bonds,
        'receipts': receipts,
        'runsStarted': runsStarted,
        'bestRunMillis': bestRunMillis,
        'runWon': runWon,
      };

  factory PlayerProfile.fromJson(Object? value) {
    if (value == null) return PlayerProfile();
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid profile.');
    }
    final p = PlayerProfile();
    int integer(String key, [int max = 0x7fffffff]) {
      final v = value[key];
      if (v is! int || v < 0 || v > max) {
        throw FormatException('Invalid profile $key.');
      }
      return v;
    }

    bool boolean(String key) {
      final v = value[key];
      if (v is! bool) throw FormatException('Invalid profile $key.');
      return v;
    }

    p.coins = integer('coins');
    p.cores = integer('cores');
    p.seeds = integer('seeds');
    p.owned = integer('owned', 31);
    p.cape = integer('cape', 3);
    p.trail = boolean('trail');
    p.hat = boolean('hat');
    p.runsStarted = integer('runsStarted');
    p.bestRunMillis = integer('bestRunMillis');
    p.runWon = boolean('runWon');
    final bonds = value['bonds'], receipts = value['receipts'];
    if (bonds is! List ||
        bonds.length != 3 ||
        bonds.any((v) => v is! int || v < 0) ||
        receipts is! Map<String, dynamic>) {
      throw const FormatException('Invalid profile rewards.');
    }
    for (var i = 0; i < 3; i++) {
      p.bonds[i] = bonds[i] as int;
    }
    for (final entry in receipts.entries) {
      if (!RegExp(r'^\d+:\d+$').hasMatch(entry.key) ||
          entry.value is! int ||
          entry.value < 0 ||
          entry.value > 262143) {
        throw const FormatException('Invalid reward receipt.');
      }
      p.receipts[entry.key] = entry.value as int;
    }
    if ((p.cape == 1 && !p.owns(WorkshopItem.starCape)) ||
        (p.cape == 2 && !p.owns(WorkshopItem.gliderCape)) ||
        (p.cape == 3 && !p.owns(WorkshopItem.runnerCape)) ||
        (p.trail && !p.owns(WorkshopItem.sparkTrail)) ||
        (p.hat && !p.owns(WorkshopItem.companionHat))) {
      throw const FormatException('Unearned workshop equipment.');
    }
    return p;
  }
  PlayerProfile();
}

class TrailRun {
  double elapsed = 0;
  bool finished = false, won = false;
  static const limit = 420.0;
  double get remaining => math.max(0, limit - elapsed);
  void tick(double seconds) {
    if (finished) return;
    elapsed += seconds;
    if (remaining == 0) finished = true;
  }

  void finish(PlayerProfile profile) {
    if (finished) return;
    finished = won = true;
    final millis = (elapsed * 1000).round();
    if (profile.bestRunMillis == 0 || millis < profile.bestRunMillis) {
      profile.bestRunMillis = millis;
    }
    if (!profile.runWon) {
      profile.runWon = true;
      profile.owned |= 1 << WorkshopItem.runnerCape.index;
      profile.coins += 24;
      profile.cores += 2;
    }
  }
}
