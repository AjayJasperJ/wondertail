import 'dart:convert';
import 'dart:math' as math;

part 'progression.dart';
part 'engagement_rules.dart';

class Point2 {
  const Point2(this.x, this.y);
  final double x;
  final double y;
  Point2 operator +(Point2 other) => Point2(x + other.x, y + other.y);
  Point2 operator -(Point2 other) => Point2(x - other.x, y - other.y);
  Point2 operator *(double scale) => Point2(x * scale, y * scale);
  double get length => math.sqrt(x * x + y * y);
  double distanceTo(Point2 other) => (this - other).length;
}

enum Biome { meadow, twilight, coral }

enum Adventure { rain, lantern, garden }

enum IslandMutator { calm, breeze, mist, overgrowth }

enum Encounter {
  friend,
  wonder,
  gate,
  bedOne,
  bedTwo,
  bedThree,
  cave,
  lodge,
  ruins,
  exitRoom,
  scout,
  tool,
  vines,
  cache,
  mirror,
  passageLeft,
  passageRight,
  glide
}

class IslandProgress {
  IslandProgress({
    this.stage = 0,
    this.collected = 0,
    this.listened = false,
    this.rainTime = 0,
    this.coins = 0,
    this.shards = 0,
    this.scoutMet = false,
    this.ruinsRestored = false,
    this.favorGiven = false,
    this.cacheOpened = false,
    this.vinesCleared = false,
    this.toolFound = false,
    this.mirror = 0,
  });
  int shards;
  bool scoutMet, ruinsRestored;
  bool favorGiven, cacheOpened, vinesCleared, toolFound;
  int mirror;
  int get shardCount => shards.toRadixString(2).replaceAll('0', '').length;
  int coins;
  int get coinCount => coins.toRadixString(2).replaceAll('0', '').length;
  int stage;
  int collected;
  bool listened;
  double rainTime;
  int get count =>
      (collected & 1) + ((collected >> 1) & 1) + ((collected >> 2) & 1);
  bool get complete => stage == 3;
  Map<String, Object> toJson() => {
        'stage': stage,
        'collected': collected,
        'listened': listened,
        'rainTime': rainTime,
        'coins': coins,
        'shards': shards,
        'scoutMet': scoutMet,
        'ruinsRestored': ruinsRestored,
        'favorGiven': favorGiven,
        'cacheOpened': cacheOpened,
        'vinesCleared': vinesCleared,
        'toolFound': toolFound,
        'mirror': mirror,
      };
  factory IslandProgress.fromJson(Map<String, dynamic> json) {
    final shards = json['shards'] ?? 0;
    final scout = json['scoutMet'] ?? false;
    final ruins = json['ruinsRestored'] ?? false;
    for (final key in [
      'favorGiven',
      'cacheOpened',
      'vinesCleared',
      'toolFound'
    ]) {
      if ((json[key] ?? false) is! bool) throw FormatException('Invalid $key.');
    }
    final mirror = json['mirror'] ?? 0;
    if (mirror is! int || mirror < 0 || mirror > 3) {
      throw const FormatException('Invalid mirror.');
    }
    if (shards is! int ||
        shards < 0 ||
        shards > 7 ||
        scout is! bool ||
        ruins is! bool ||
        (ruins && shards != 7)) {
      throw const FormatException('Invalid discovery memory.');
    }
    final coins = json['coins'] ?? 0;
    if (coins is! int || coins < 0 || coins > 4095) {
      throw const FormatException('Invalid coin memory.');
    }
    final stage = json['stage'];
    final collected = json['collected'];
    final time = json['rainTime'];
    if (stage is! int ||
        stage < 0 ||
        stage > 3 ||
        collected is! int ||
        collected < 0 ||
        collected > 7 ||
        json['listened'] is! bool ||
        time is! num ||
        !time.isFinite ||
        time < 0 ||
        time > 2.4) {
      throw const FormatException('Invalid island memory.');
    }
    return IslandProgress(
      shards: shards,
      scoutMet: scout,
      ruinsRestored: ruins,
      favorGiven: json['favorGiven'] ?? false,
      cacheOpened: json['cacheOpened'] ?? false,
      vinesCleared: json['vinesCleared'] ?? false,
      toolFound: json['toolFound'] ?? false,
      mirror: mirror,
      coins: coins,
      stage: stage,
      collected: collected,
      listened: json['listened'] as bool,
      rainTime: time.toDouble(),
    );
  }
}

/// Only the active island is kept in memory. SaveRepository loads earlier
/// island memories on travel; header autosaves stay constant in size.
class WorldState {
  WorldState({
    this.seed = 4271,
    this.character = 0,
    this.sound = true,
    this.calm = false,
    this.guide = true,
    this.islandIndex = 0,
    this.highestUnlocked = 0,
    this.highestVisited = 0,
    double? x,
    double? y,
    IslandProgress? progress,
    PlayerProfile? profile,
    this.run,
  })  : profile = profile ?? PlayerProfile(),
        progress = progress ?? IslandProgress() {
    map = IslandMap.generate(seed, islandIndex, compact: run != null);
    this.x = x ?? map.arrival.x;
    this.y = y ?? map.arrival.y;
  }
  static const schemaVersion = 2;
  static const generatorVersion = 3;
  int character;
  bool sound, calm, guide;
  int room = 0; // 0 outdoors, 1 crystal cave, 2 scout lodge.
  int chamber = 0;
  final PlayerProfile profile;
  final TrailRun? run;
  final int seed;
  int islandIndex;
  int highestUnlocked;
  int highestVisited;
  late double x;
  late double y;
  late IslandMap map;
  IslandProgress progress;
  Point2 get position => Point2(x, y);
  int get kindnessCount => highestUnlocked;

  bool travel(int index, IslandProgress memory) {
    if (run != null && (index != islandIndex + 1 || index > 5)) return false;
    if (index < 0 || index > highestUnlocked || index == islandIndex) {
      return false;
    }
    room = 0;
    chamber = 0;
    islandIndex = index;
    highestVisited = math.max(highestVisited, index);
    map = IslandMap.generate(seed, index, compact: run != null);
    progress = memory;
    x = map.arrival.x;
    y = map.arrival.y;
    return true;
  }

  Map<String, Object> headerJson() => {
        'schemaVersion': schemaVersion,
        'generatorVersion': generatorVersion,
        'seed': seed,
        'islandIndex': islandIndex,
        'highestUnlocked': highestUnlocked,
        'highestVisited': highestVisited,
        'character': character,
        'sound': sound,
        'calm': calm,
        'guide': guide,
        'profile': profile.toJson(),
        'x': room == 0 ? x : (room == 1 ? map.cave.x : map.lodge.x),
        'y': room == 0 ? y : (room == 1 ? map.cave.y : map.lodge.y),
      };
  Map<String, Object> toJson() => {
        ...headerJson(),
        'progress': progress.toJson(),
      };
  String encode() => jsonEncode(toJson());

  factory WorldState.decode(String raw) {
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid save.');
    }
    if (json['schemaVersion'] == 1) return WorldState._fromLegacy(json);
    if (json['schemaVersion'] != schemaVersion ||
        ![2, generatorVersion].contains(json['generatorVersion'])) {
      throw const FormatException('Unsupported Wondertail save.');
    }
    for (final key in [
      'seed',
      'islandIndex',
      'highestUnlocked',
      'highestVisited',
    ]) {
      if (json[key] is! int || (json[key] as int) < 0) {
        throw FormatException('Invalid $key.');
      }
    }
    for (final key in ['x', 'y']) {
      if (json[key] is! num || !(json[key] as num).isFinite) {
        throw FormatException('Invalid $key.');
      }
    }
    if (json['islandIndex'] > json['highestVisited'] ||
        json['highestVisited'] > json['highestUnlocked']) {
      throw const FormatException('Invalid island trail.');
    }
    final progress = json['progress'];
    if (progress is! Map<String, dynamic>) {
      throw const FormatException('Missing island memory.');
    }
    final character = json['character'] ?? 0;
    if (character is! int ||
        character < 0 ||
        character > 2 ||
        (json['sound'] ?? true) is! bool ||
        (json['calm'] ?? false) is! bool ||
        (json['guide'] ?? true) is! bool) {
      throw const FormatException('Invalid explorer settings.');
    }
    final world = WorldState(
      character: character,
      sound: json['sound'] ?? true,
      calm: json['calm'] ?? false,
      guide: json['guide'] ?? true,
      seed: json['seed'],
      islandIndex: json['islandIndex'],
      highestUnlocked: json['highestUnlocked'],
      highestVisited: json['highestVisited'],
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      progress: IslandProgress.fromJson(progress),
      profile: PlayerProfile.fromJson(json['profile']),
    );
    if (!world.map.canStand(world.position)) {
      world.x = world.map.arrival.x;
      world.y = world.map.arrival.y;
    }
    return world;
  }

  factory WorldState._fromLegacy(Map<String, dynamic> json) {
    if (json['generatorVersion'] != 1 || json['seed'] is! int) {
      throw const FormatException('Invalid old save.');
    }
    for (final key in [
      'studiedCrystal',
      'cloudRescued',
      'groveGrown',
      'seedCollected',
      'bridgeGrown',
      'lookoutReached',
    ]) {
      if (json[key] is! bool) {
        throw const FormatException('Invalid old progress.');
      }
    }
    if ((json['groveGrown'] && !json['cloudRescued']) ||
        (json['seedCollected'] && !json['groveGrown']) ||
        (json['bridgeGrown'] && !json['seedCollected'])) {
      throw const FormatException('Invalid old progress.');
    }
    final done = json['bridgeGrown'] == true;
    return WorldState(
      seed: json['seed'],
      highestUnlocked: done ? 1 : 0,
      progress: IslandProgress(
        stage: done
            ? 3
            : json['groveGrown'] == true
                ? 2
                : json['cloudRescued'] == true
                    ? 1
                    : 0,
        collected: json['seedCollected'] == true ? 7 : 0,
        listened: json['studiedCrystal'] == true,
        rainTime: json['groveGrown'] == true ? 2.4 : 0,
      ),
    );
  }

  List<String> get journal => [
        'Island ${islandIndex + 1} · ${map.name}',
        if (progress.listened) map.story,
        if (progress.stage > 0) '${map.friendName} remembers your kindness.',
        if (progress.count > 0)
          'Found ${progress.count} of 3 ${map.collectibleName}.',
        if (progress.complete) map.consequence,
        '$highestUnlocked restored island${highestUnlocked == 1 ? '' : 's'} along your trail. Every island keeps its own memories.',
      ];
}

class SeededRandom {
  SeededRandom(int seed) : _value = seed & 0x7fffffff;
  int _value;
  int nextInt(int max) {
    _value = (_value * 1664525 + 1013904223) & 0x7fffffff;
    return _value % max;
  }

  double nextDouble() => nextInt(1000000) / 1000000;
}

class Obstacle {
  const Obstacle(this.center, this.radius,
      {this.pond = false, this.structure = false});
  final Point2 center;
  final double radius;
  final bool pond;
  final bool structure;
}

class IslandMap {
  IslandMap._({
    required this.variationSeed,
    this.compact = false,
    required this.index,
    required this.name,
    required this.biome,
    required this.adventure,
    required this.friend,
    required this.wonder,
    required this.gate,
    required this.collectibles,
    required this.obstacles,
    required this.flowers,
    required this.trees,
  });
  final int index;
  final int variationSeed;
  final bool compact;
  final String name;
  final Biome biome;
  final Adventure adventure;
  final Point2 friend;
  final Point2 wonder;
  final Point2 gate;
  final List<Point2> collectibles;
  final List<Obstacle> obstacles;
  final List<Point2> flowers;
  final List<Point2> trees;
  static const center = Point2(640, 480);
  static const radiusX = 440.0;
  static const radiusY = 330.0;
  static const playerRadius = 13.0;
  double get scaleX =>
      [1.0, 1.32, 0.94, 1.18, 1.42][index % 5] * (compact ? 0.82 : 1);
  double get scaleY =>
      [1.0, 0.94, 1.26, 1.18, 1.08][index % 5] * (compact ? 0.82 : 1);
  String get landform => [
        'Three Capes',
        'Long Ridge',
        'Highland',
        'Split Crown',
        'Great Basin'
      ][index % 5];
  double coast(double angle) {
    final phase = index * 0.63;
    return 1 +
        0.13 * math.cos(3 * angle + phase) +
        0.075 * math.sin(5 * angle - phase) +
        0.04 * math.cos(7 * angle);
  }

  Point2 terrainPoint(Point2 p) => Point2(center.x + (p.x - center.x) * scaleX,
      center.y + (p.y - center.y) * scaleY);
  Point2 get arrival => terrainPoint(const Point2(370, 545));
  Point2 get cave => terrainPoint(const Point2(800, 340));
  Point2 get lodge => terrainPoint(const Point2(400, 390));
  Point2 get ruins => terrainPoint(const Point2(570, 675));
  Point2 shorePoint(double angle, {double inset = 0, double drop = 0}) =>
      Point2(
          center.x +
              math.cos(angle) * (radiusX * scaleX * coast(angle) - inset),
          center.y +
              math.sin(angle) * (radiusY * scaleY * coast(angle) - inset) +
              drop);

  factory IslandMap.generate(int seed, int index, {bool compact = false}) {
    // Bounded integer arithmetic is identical on Dart VM and JavaScript.
    final random = SeededRandom((seed + index * 104729) & 0x7fffffff);
    final biome = Biome.values[(index + (index ~/ 9) + seed % 3) % 3];
    // A nine-island rotation crosses every adventure with every biome. A
    // seeded phase changes the later trail; the migrated first island is rain.
    final phase = (seed ~/ 7) % 2;
    final adventure =
        Adventure.values[index == 0 ? 0 : (index + index ~/ 3 + phase) % 3];
    final rotation = index == 0 ? 0.0 : (random.nextDouble() - 0.5) * 0.85;
    Point2 rotate(double x, double y) => Point2(
          center.x + x * math.cos(rotation) - y * math.sin(rotation),
          center.y + (x * math.sin(rotation) + y * math.cos(rotation)) * 0.8,
        );
    final friend = rotate(-65, -110);
    final wonder = rotate(100, 120);
    final gate = rotate(310, -50);
    final items = [rotate(-150, 140), rotate(15, -260), rotate(245, 100)];
    final landmarks = [
      friend,
      wonder,
      gate,
      ...items,
      const Point2(370, 545),
      const Point2(800, 340),
      const Point2(400, 390),
      const Point2(570, 675)
    ];
    final obstacles = <Obstacle>[];
    for (var i = 0; i < 80 && obstacles.length < 5; i++) {
      final point = Point2(
        350 + random.nextDouble() * 590,
        265 + random.nextDouble() * 420,
      );
      final radius = obstacles.isEmpty ? 40.0 : 19.0 + random.nextInt(12);
      if (landmarks.any((mark) => mark.distanceTo(point) < radius + 94) ||
          obstacles.any(
            (rock) => rock.center.distanceTo(point) < rock.radius + radius + 65,
          )) {
        continue;
      }
      obstacles.add(Obstacle(point, radius, pond: obstacles.isEmpty));
    }
    final flowers = List.generate(
      90,
      (_) => Point2(
        300 + random.nextDouble() * 680,
        255 + random.nextDouble() * 450,
      ),
    );
    final trees = List.generate(14, (i) {
      final angle = (i / 14) * math.pi * 2 + random.nextDouble() * 0.1;
      return Point2(
        center.x + math.cos(angle) * 392,
        center.y + math.sin(angle) * 277,
      );
    });
    const prefixes = [
      'Wistful',
      'Honey',
      'Velvet',
      'Mossy',
      'Star',
      'Peach',
      'Willow',
      'Silver',
      'Clover',
      'Moon',
    ];
    const suffixes = [
      'Hollow',
      'Drift',
      'Cove',
      'Meadow',
      'Reach',
      'Harbor',
      'Glen',
      'Garden',
    ];
    final name = index == 0
        ? 'Little Drift'
        : '${prefixes[random.nextInt(prefixes.length)]} ${suffixes[random.nextInt(suffixes.length)]}';
    final map = IslandMap._(
      variationSeed: seed,
      compact: compact,
      index: index,
      name: name,
      biome: biome,
      adventure: adventure,
      friend: friend,
      wonder: wonder,
      gate: gate,
      collectibles: items,
      obstacles: obstacles,
      flowers: flowers,
      trees: trees,
    );
    Point2 scaled(Point2 p) => map.terrainPoint(p);
    final result = IslandMap._(
      variationSeed: seed,
      compact: compact,
      index: index,
      name: name,
      biome: biome,
      adventure: adventure,
      friend: scaled(friend),
      wonder: scaled(wonder),
      gate: scaled(gate),
      collectibles: items.map(scaled).toList(),
      obstacles: obstacles
          .map((o) => Obstacle(scaled(o.center), o.radius, pond: o.pond))
          .toList(),
      flowers:
          flowers.map(scaled).where((p) => map.onLand(p, margin: 24)).toList(),
      trees: List.generate(
          18, (i) => map.shorePoint(i * math.pi * 2 / 18, inset: 48)),
    );
    result.obstacles.addAll([
      Obstacle(result.cave + const Point2(0, -110), 28, structure: true),
      Obstacle(result.lodge + const Point2(0, -65), 28, structure: true),
    ]);
    return result;
  }

  String get friendName => switch (adventure) {
        Adventure.rain => 'Pip',
        Adventure.lantern => 'Luma',
        Adventure.garden => 'Moss',
      };
  String get collectibleName => switch (adventure) {
        Adventure.rain => 'sunseeds',
        Adventure.lantern => 'trail lights',
        Adventure.garden => 'garden beds',
      };
  String get title => switch (adventure) {
        Adventure.rain => 'A cloud’s promise',
        Adventure.lantern => 'The scattered stars',
        Adventure.garden => 'A garden for a wanderer',
      };
  String get story => switch (adventure) {
        Adventure.rain =>
          'Pip used to water this island. The crystal closed during a storm, and the trees have been dreaming of rain ever since.',
        Adventure.lantern =>
          'Luma’s lantern fell asleep. Its three stepping lights remember a song: first one, then two, then three. Follow their order to carry the song home.',
        Adventure.garden =>
          'Moss carries a whole garden on a tiny shell. A watering can and three little seed beds could make a home for every wandering creature.',
      };
  String get consequence => switch (adventure) {
        Adventure.rain =>
          'Because you freed Pip, rain grew a forest. Your sunseeds made a living skyway.',
        Adventure.lantern =>
          'You followed the song of three lights. Luma lit the beacon and made a star path through the clouds.',
        Adventure.garden =>
          'You watered Moss’s seeds. A flowering garden grew a new path for every wanderer.',
      };
  String get wonderName => switch (adventure) {
        Adventure.rain => 'The seed grove',
        Adventure.lantern => 'The star lantern',
        Adventure.garden => 'The wandering garden',
      };

  // Cached routes use the same collision map as movement.
  late final List<List<Point2>> trails = [
    for (final target in [
      friend,
      wonder,
      gate,
      ...collectibles,
      cave,
      lodge,
      ruins
    ])
      route(arrival, target),
  ];
  late final List<Point2> coins = [
    for (final trail in trails.take(6))
      for (final fraction in [0.4, 0.72])
        trail[(fraction * (trail.length - 1)).round()],
  ];

  List<Point2> route(Point2 from, Point2 to) {
    const step = 20.0;
    int key(int x, int y) => y * 96 + x;
    Point2 point(int k) => Point2((k % 96) * step, (k ~/ 96) * step);
    final start = key((from.x / step).round(), (from.y / step).round());
    final end = key((to.x / step).round(), (to.y / step).round());
    final queue = <int>[start];
    final parent = <int, int>{start: start};
    for (var cursor = 0; cursor < queue.length; cursor++) {
      final current = queue[cursor];
      if (current == end) break;
      for (final offset in [-1, 1, -96, 96]) {
        final next = current + offset;
        if (next < 0 || next >= 96 * 80 || parent.containsKey(next)) continue;
        if (!canStand(point(next))) continue;
        // Leave a little space around rocks for the visible path.
        if (obstacles
            .any((o) => point(next).distanceTo(o.center) < o.radius + 18)) {
          continue;
        }
        parent[next] = current;
        queue.add(next);
      }
    }
    if (!parent.containsKey(end)) return [from, to];
    final reversed = <Point2>[to];
    var cursor = end;
    while (cursor != start) {
      reversed.add(point(cursor));
      cursor = parent[cursor]!;
    }
    return [from, ...reversed.reversed];
  }

  bool onLand(Point2 point, {double margin = playerRadius}) {
    final dx = (point.x - center.x) / (radiusX * scaleX);
    final dy = (point.y - center.y) / (radiusY * scaleY);
    final r = math.sqrt(dx * dx + dy * dy);
    return r <=
        coast(math.atan2(dy, dx)) - margin / (radiusY * scaleY) + 0.000001;
  }

  bool canStand(Point2 point) =>
      onLand(point) &&
      !obstacles.any((rock) =>
          point.distanceTo(rock.center) < rock.radius + playerRadius - 0.05);

  Point2 _insideShore(Point2 point) {
    final dx = (point.x - center.x) / (radiusX * scaleX);
    final dy = (point.y - center.y) / (radiusY * scaleY);
    final r = math.sqrt(dx * dx + dy * dy);
    final limit = coast(math.atan2(dy, dx)) - playerRadius / (radiusY * scaleY);
    if (r <= limit) return point;
    return Point2(center.x + dx / r * limit * radiusX * scaleX,
        center.y + dy / r * limit * radiusY * scaleY);
  }

  /// Project against contact normals, then preserve tangential movement. Small
  /// substeps prevent tunnelling; gentle head-on assistance removes dead zones.
  Point2 slide(Point2 from, Point2 delta) {
    var point = _insideShore(from + delta);
    for (var pass = 0; pass < 3; pass++) {
      for (final rock in obstacles) {
        final difference = point - rock.center;
        final distance = difference.length;
        final limit = rock.radius + playerRadius + 0.05;
        if (distance >= limit) continue;
        final normal = distance < 0.0001
            ? const Point2(0, -1)
            : difference * (1 / distance);
        var tangent = Point2(-normal.y, normal.x);
        var along = delta.x * tangent.x + delta.y * tangent.y;
        if (along.abs() < delta.length * 0.25) {
          // Predictable gentle assist when the intended direction meets a rock
          // almost square-on. No permanent collision-side state can get stuck.
          along = delta.length * 0.65;
        }
        if (along < 0) tangent = tangent * -1;
        point = rock.center + normal * limit + tangent * along.abs();
      }
      point = _insideShore(point);
    }
    return point;
  }
}

class WorldRules {
  static int collectCoins(WorldState world) {
    if (world.room != 0) return 0;
    var count = 0;
    for (var i = 0; i < world.map.coins.length; i++) {
      if ((world.progress.coins & (1 << i)) == 0 &&
          world.position.distanceTo(world.map.coins[i]) <
              world.profile.coinRadius) {
        world.progress.coins |= 1 << i;
        count++;
      }
    }
    world.profile.reconcile(world);
    return count;
  }

  static const roomExit = Point2(640, 680);
  static const scoutPosition = Point2(640, 380);
  static const caveCrystals = [
    Point2(490, 390),
    Point2(790, 410),
    Point2(640, 320)
  ];
  static Point2 encounterPoint(WorldState world, Encounter encounter) =>
      switch (encounter) {
        Encounter.friend => world.map.friend,
        Encounter.wonder => world.map.wonder,
        Encounter.gate => world.map.gate,
        Encounter.cave => world.map.cave,
        Encounter.lodge => world.map.lodge,
        Encounter.ruins => world.map.ruins,
        Encounter.exitRoom => roomExit,
        Encounter.scout => world.map.scoutPoint,
        Encounter.tool => world.map.shears,
        Encounter.vines => world.map.vineGate,
        Encounter.cache => world.map.hiddenCache,
        Encounter.mirror => world.map.mirrorPoint,
        Encounter.passageLeft => const Point2(475, 500),
        Encounter.passageRight => const Point2(805, 500),
        Encounter.glide => world.position,
        _ => world.map.collectibles[bedIndex(encounter)!],
      };
  static bool collectShards(WorldState world) {
    if (world.room != 1) return false;
    final before = world.progress.shards;
    for (var i = 0; i < 3; i++) {
      if (world.map.crystalRoom(i) == world.chamber &&
          world.position.distanceTo(world.map.crystalPoint(i)) < 35) {
        world.progress.shards |= 1 << i;
      }
    }
    return before != world.progress.shards;
  }

  static String objective(WorldState world) {
    if (world.room == 1) {
      return world.progress.shards == 7
          ? 'Return outside · restore the ancient ruins'
          : 'Chamber ${world.chamber + 1}/${world.map.chambers} · crystals ${world.progress.shardCount}/3 · align the mirror to open branches';
    }
    if (world.room == 2) {
      return world.progress.scoutMet
          ? 'Scout’s clue: cave crystals power the ancient ruins'
          : 'Speak to the scout at the map table';
    }
    final p = world.progress;
    if (p.complete) return 'The skyway is open — another island awaits';
    switch (world.map.adventure) {
      case Adventure.rain:
        if (p.stage == 0) return 'Free Pip from the crystal';
        if (p.stage == 1) return 'Pip is waking the island with rain…';
        if (p.count < 3) {
          return world.map.variant == 2
              ? 'Gather sunseed ${world.map.collectionOrder[p.count] + 1} · press the action beside it'
              : 'Find sunseeds · ${p.count}/3';
        }
        return 'Bring your sunseeds to the grove';
      case Adventure.lantern:
        if (p.count < 3) {
          return 'Follow the lights · next: ${world.map.collectionOrder[p.count] + 1}';
        }
        if (p.stage == 0) return 'Bring the lights back to Luma';
        return 'Kindle the star lantern';
      case Adventure.garden:
        if (p.stage == 0) return 'Meet Moss, the wandering turtle';
        if (p.stage == 1) return 'Fill your can at the sleepy garden';
        return 'Plant bed ${world.map.collectionOrder[p.count] + 1} · ${p.count}/3';
    }
  }

  static bool itemsActive(WorldState world) => switch (world.map.adventure) {
        Adventure.rain => world.progress.stage >= 2,
        Adventure.lantern => true,
        Adventure.garden => world.progress.stage >= 2,
      };

  static Point2 target(WorldState world) {
    if (world.room == 2) {
      return world.progress.scoutMet ? roomExit : world.map.scoutPoint;
    }
    if (world.room == 1) {
      for (var i = 0; i < 3; i++) {
        if ((world.progress.shards & (1 << i)) == 0 &&
            world.map.crystalRoom(i) == world.chamber) {
          return world.map.crystalPoint(i);
        }
      }
      if (world.chamber == 0 && world.progress.shards != 7) {
        return world.map.mirrorPoint;
      }
      return roomExit;
    }
    final p = world.progress;
    if (p.complete) {
      if (world.profile.archives > 0 && !p.cacheOpened && world.run == null) {
        return world.map.hiddenCache;
      }
      return world.map.gate;
    }
    if (itemsActive(world) && p.count < 3) {
      var target = world.map.collectibles.first;
      var distance = double.infinity;
      for (var i = 0; i < 3; i++) {
        if ((p.collected & (1 << i)) != 0) continue;
        if ((world.map.adventure == Adventure.lantern ||
                world.map.variant != 0) &&
            i != world.map.collectionOrder[p.count]) {
          continue;
        }
        final d = world.position.distanceTo(world.map.collectibles[i]);
        if (d < distance) {
          distance = d;
          target = world.map.collectibles[i];
        }
      }
      return target;
    }
    if (p.stage == 0) return world.map.friend;
    return world.map.wonder;
  }

  static Encounter? nearby(WorldState world) {
    if (world.room != 0) {
      final special = EngagementRules.nearby(world);
      if (special != null) return special;
      if (world.position.distanceTo(roomExit) < 65) return Encounter.exitRoom;
      if (world.room == 2 &&
          world.position.distanceTo(world.map.scoutPoint) < 80) {
        return Encounter.scout;
      }
      return null;
    }
    if ((world.map.adventure == Adventure.garden &&
            world.progress.stage == 2) ||
        (world.map.adventure == Adventure.rain &&
            world.map.variant == 2 &&
            world.progress.stage == 2)) {
      for (var i = 0; i < 3; i++) {
        if ((world.progress.collected & (1 << i)) == 0 &&
            world.position.distanceTo(world.map.collectibles[i]) < 70) {
          return Encounter.values[3 + i];
        }
      }
    }
    final position = world.position;
    if (world.progress.stage == 0 &&
        position.distanceTo(world.map.friend) < 88 &&
        (world.map.adventure != Adventure.lantern ||
            world.progress.count == 3)) {
      return Encounter.friend;
    }
    if (position.distanceTo(world.map.wonder) < 88 &&
        !world.progress.complete &&
        (world.progress.count == 3 ||
            (world.map.adventure == Adventure.garden &&
                world.progress.stage == 1))) {
      return Encounter.wonder;
    }
    if (world.progress.complete && position.distanceTo(world.map.gate) < 88) {
      return Encounter.gate;
    }
    for (final encounter in [
      Encounter.cave,
      Encounter.lodge,
      Encounter.ruins
    ]) {
      if (world.position.distanceTo(encounterPoint(world, encounter)) < 58) {
        return encounter;
      }
    }
    final special = EngagementRules.nearby(world);
    if (special != null) return special;
    if (position.distanceTo(world.map.friend) < 88) return Encounter.friend;
    if (position.distanceTo(world.map.wonder) < 88) return Encounter.wonder;
    if (position.distanceTo(world.map.gate) < 88) return Encounter.gate;
    return null;
  }

  static int? bedIndex(Encounter encounter) =>
      encounter.index >= 3 && encounter.index <= 5 ? encounter.index - 3 : null;

  static bool listen(WorldState world) {
    if (nearby(world) != Encounter.friend || world.progress.listened) {
      return false;
    }
    world.progress.listened = true;
    return true;
  }

  static bool act(WorldState world, Encounter encounter) {
    if (nearby(world) != encounter) return false;
    if (EngagementRules.act(world, encounter)) return true;
    final p = world.progress;
    if (encounter == Encounter.cave || encounter == Encounter.lodge) {
      world.room = encounter == Encounter.cave ? 1 : 2;
      world.chamber = 0;
      world.x = 640;
      world.y = 610;
      return true;
    }
    if (encounter == Encounter.exitRoom) {
      if (world.room == 1 && world.chamber != 0) {
        world.chamber = 0;
        world.x = 640;
        world.y = 610;
        return true;
      }
      final exit = world.room == 1 ? world.map.cave : world.map.lodge;
      world.room = 0;
      world.x = exit.x;
      world.y = exit.y + 25;
      return true;
    }
    if (encounter == Encounter.scout && !p.scoutMet) {
      p.scoutMet = true;
      return true;
    }
    if (encounter == Encounter.ruins && p.shards == 7 && !p.ruinsRestored) {
      p.ruinsRestored = true;
      world.profile.reconcile(world);
      return true;
    }
    if (encounter == Encounter.friend && p.stage == 0) {
      if (world.map.adventure == Adventure.lantern && p.count < 3) return false;
      p.stage = 1;
      return true;
    }
    final bed = bedIndex(encounter);
    if (bed != null &&
        world.map.adventure == Adventure.rain &&
        world.map.variant == 2 &&
        p.stage == 2 &&
        p.count < 3 &&
        bed == world.map.collectionOrder[p.count]) {
      p.collected |= 1 << bed;
      return true;
    }
    if (bed != null &&
        world.map.adventure == Adventure.garden &&
        p.stage == 2 &&
        (world.map.variant == 0 ||
            (p.count < 3 && bed == world.map.collectionOrder[p.count])) &&
        (p.collected & (1 << bed)) == 0) {
      p.collected |= 1 << bed;
      if (p.count == 3) {
        p.stage = 3;
        world.highestUnlocked = math.max(
          world.highestUnlocked,
          world.islandIndex + 1,
        );
        world.profile.reconcile(world);
      }
      return true;
    }
    if (encounter == Encounter.wonder &&
        world.map.adventure == Adventure.garden &&
        p.stage == 1) {
      p.stage = 2;
      return true;
    }
    if (encounter == Encounter.wonder &&
        p.stage > 0 &&
        p.stage < 3 &&
        p.count == 3) {
      if (world.map.adventure == Adventure.rain && p.stage < 2) return false;
      p.stage = 3;
      world.highestUnlocked = math.max(
        world.highestUnlocked,
        world.islandIndex + 1,
      );
      world.profile.reconcile(world);
      return true;
    }
    return false;
  }

  /// Returns collected item indices; persistence/UI are updated only on change.
  static List<int> collect(WorldState world) {
    if (world.room != 0) return const [];
    if (world.map.adventure == Adventure.rain && world.map.variant == 2) {
      return const [];
    }
    if (world.map.adventure == Adventure.garden ||
        !itemsActive(world) ||
        world.progress.count == 3) {
      return const [];
    }
    List<int> collected = const [];
    for (var i = 0; i < 3; i++) {
      if (world.progress.count == 3) break;
      if (world.map.adventure == Adventure.lantern &&
          i != world.map.collectionOrder[world.progress.count]) {
        continue;
      }
      if ((world.progress.collected & (1 << i)) == 0 &&
          world.position.distanceTo(world.map.collectibles[i]) < 34) {
        world.progress.collected |= 1 << i;
        collected = [...collected, i];
      }
    }
    return collected;
  }

  static bool advance(WorldState world, double dt) {
    final p = world.progress;
    if (world.room != 0 ||
        world.map.adventure != Adventure.rain ||
        p.stage != 1) {
      return false;
    }
    p.rainTime = (p.rainTime + dt).clamp(0, 2.4);
    if (p.rainTime < 2.4) return false;
    p.stage = 2;
    world.profile.reconcile(world);
    return true;
  }

  static bool move(
    WorldState world,
    double dx,
    double dy,
    double seconds, {
    bool sprint = false,
  }) {
    if (!dx.isFinite || !dy.isFinite || !seconds.isFinite || seconds <= 0) {
      return false;
    }
    final length = math.sqrt(dx * dx + dy * dy);
    if (length < 0.001) return false;
    final duration = seconds.clamp(0.0, 0.15);
    final steps = math.max(1, (duration / (1 / 90)).ceil());
    var delta = Point2(dx, dy) *
        ((sprint ? 260 : 205) * duration / steps / math.max(1, length));
    if (world.room == 0 &&
        world.map.mutator == IslandMutator.breeze &&
        world.position.distanceTo(world.map.windLane) < 110) {
      delta = delta * 1.35 + Point2(35 * duration / steps, 0);
    }
    final before = world.position;
    var position = before;
    for (var i = 0; i < steps; i++) {
      if (world.room == 0) {
        final next = world.map.slide(position, delta);
        position = EngagementRules.passable(world, next) ? next : position;
      } else {
        final inset = world.map.inset(world.chamber);
        position = Point2(
            (position.x + delta.x).clamp(437 + inset, 843 - inset),
            (position.y + delta.y).clamp(297 + inset, 707));
      }
    }
    world.x = position.x;
    world.y = position.y;
    return before.distanceTo(position) > 0.0001;
  }
}
