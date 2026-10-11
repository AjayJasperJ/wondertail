import 'dart:convert';
import 'dart:math' as math;

/// One versioned, authoritative snapshot. Rendering never owns quest progress.
class WorldState {
  WorldState({
    this.seed = 4271,
    this.x = 370,
    this.y = 485,
    this.studiedCrystal = false,
    this.cloudRescued = false,
    this.rainSeconds = 0,
    this.groveGrown = false,
    this.seedCollected = false,
    this.bridgeGrown = false,
    this.lookoutReached = false,
  });

  static const schemaVersion = 1;
  static const generatorVersion = 1;
  final int seed;
  double x;
  double y;
  bool studiedCrystal;
  bool cloudRescued;
  double rainSeconds;
  bool groveGrown;
  bool seedCollected;
  bool bridgeGrown;
  bool lookoutReached;

  int get kindnessCount => (cloudRescued ? 1 : 0) + (bridgeGrown ? 1 : 0);
  int get pocketSeeds => seedCollected && !bridgeGrown ? 1 : 0;

  List<String> get journal => [
    'You arrived at Little Drift with a backpack and a curious compass.',
    if (studiedCrystal)
      'The crystal hums when you listen. Something gentle is inside.',
    if (cloudRescued)
      'You opened the crystal. Pip the cloud is free and calls you a friend.',
    if (groveGrown)
      'You helped Pip, so Pip’s rain brought the sleepy grove back to life.',
    if (seedCollected) 'The grateful grove gave you one bright seed.',
    if (bridgeGrown)
      'Your seed grew a living bridge. A new island is within reach!',
    if (lookoutReached)
      'You and Pip reached the Lantern Lookout. Little Drift remembers you.',
  ];

  Map<String, Object> toJson() => {
    'schemaVersion': schemaVersion,
    'generatorVersion': generatorVersion,
    'seed': seed,
    'x': x,
    'y': y,
    'studiedCrystal': studiedCrystal,
    'cloudRescued': cloudRescued,
    'rainSeconds': rainSeconds,
    'groveGrown': groveGrown,
    'seedCollected': seedCollected,
    'bridgeGrown': bridgeGrown,
    'lookoutReached': lookoutReached,
  };

  String encode() => jsonEncode(toJson());

  factory WorldState.decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> ||
        decoded['schemaVersion'] != schemaVersion ||
        decoded['generatorVersion'] != generatorVersion) {
      throw const FormatException('Unsupported Wondertail save.');
    }
    double number(String key) {
      final value = decoded[key];
      if (value is! num || !value.isFinite) {
        throw FormatException('Invalid $key in save.');
      }
      return value.toDouble();
    }

    bool flag(String key) {
      final value = decoded[key];
      if (value is! bool) throw FormatException('Invalid $key in save.');
      return value;
    }

    final seed = decoded['seed'];
    if (seed is! int) throw const FormatException('Invalid world seed.');
    final state = WorldState(
      seed: seed,
      x: number('x'),
      y: number('y'),
      studiedCrystal: flag('studiedCrystal'),
      cloudRescued: flag('cloudRescued'),
      rainSeconds: number('rainSeconds').clamp(0, 4),
      groveGrown: flag('groveGrown'),
      seedCollected: flag('seedCollected'),
      bridgeGrown: flag('bridgeGrown'),
      lookoutReached: flag('lookoutReached'),
    );
    if ((state.groveGrown && !state.cloudRescued) ||
        (state.seedCollected && !state.groveGrown) ||
        (state.bridgeGrown && !state.seedCollected) ||
        (state.lookoutReached && !state.bridgeGrown)) {
      throw const FormatException('Inconsistent quest progress.');
    }
    // A future map correction must never leave a child stuck in the sky.
    if (!IslandMap.canStand(state.x, state.y, state.bridgeGrown) ||
        (!state.bridgeGrown && state.x > 900)) {
      state.x = 370;
      state.y = 485;
    }
    return state;
  }
}

enum Encounter { cloud, grove, bridge, lookout }

class Landmark {
  const Landmark(this.x, this.y, this.title);
  final double x;
  final double y;
  final String title;
}

class IslandMap {
  static const cloud = Landmark(540, 340, 'The lost cloud');
  static const grove = Landmark(640, 590, 'The sleepy grove');
  static const bridge = Landmark(795, 350, 'The seed hollow');
  static const lookout = Landmark(1070, 235, 'Lantern Lookout');
  static const bridgeStart = Landmark(795, 350, '');
  static const bridgeEnd = Landmark(975, 280, '');
  static const rocks = [(440.0, 555.0, 29.0), (335.0, 365.0, 22.0)];

  static double distance(double x, double y, Landmark landmark) =>
      math.sqrt(math.pow(x - landmark.x, 2) + math.pow(y - landmark.y, 2));

  static bool _ellipse(
    double x,
    double y,
    double cx,
    double cy,
    double rx,
    double ry,
  ) => math.pow((x - cx) / rx, 2) + math.pow((y - cy) / ry, 2) <= 1;

  static bool _ground(double x, double y, bool hasBridge) {
    if (_ellipse(x, y, 475, 480, 375, 285) ||
        _ellipse(x, y, 1080, 250, 155, 130)) {
      return true;
    }
    if (!hasBridge) return false;
    const dx = 180.0;
    const dy = -70.0;
    final t = (((x - bridgeStart.x) * dx + (y - bridgeStart.y) * dy) /
            (dx * dx + dy * dy))
        .clamp(0.0, 1.0);
    return math.pow(x - (bridgeStart.x + t * dx), 2) +
            math.pow(y - (bridgeStart.y + t * dy), 2) <=
        34 * 34;
  }

  static bool canStand(double x, double y, bool hasBridge) {
    // Sample the footprint, not only its center, at the island boundary.
    for (final (dx, dy) in const [
      (0.0, 0.0),
      (12.0, 0.0),
      (-12.0, 0.0),
      (0.0, 12.0),
      (0.0, -12.0),
    ]) {
      if (!_ground(x + dx, y + dy, hasBridge)) return false;
    }
    for (final (rx, ry, radius) in rocks) {
      if (math.pow(x - rx, 2) + math.pow(y - ry, 2) <
          math.pow(radius + 12, 2)) {
        return false;
      }
    }
    return !_ellipse(x, y, 310, 610, 65, 44);
  }

  /// Stable integer arithmetic rather than runtime-specific random sequences.
  static List<(double, double)> flowers(int seed) {
    var value = seed & 0x7fffffff;
    final result = <(double, double)>[];
    for (var i = 0; i < 100; i++) {
      value = (value * 1664525 + 1013904223) & 0x7fffffff;
      final x = 160.0 + value % 620;
      value = (value * 1664525 + 1013904223) & 0x7fffffff;
      final y = 235.0 + value % 480;
      if (canStand(x, y, false)) result.add((x, y));
    }
    return result;
  }
}

class WorldRules {
  static Landmark target(WorldState state) {
    if (!state.cloudRescued) return IslandMap.cloud;
    if (!state.seedCollected) return IslandMap.grove;
    if (!state.bridgeGrown) return IslandMap.bridge;
    return IslandMap.lookout;
  }

  static String objective(WorldState state) {
    if (!state.cloudRescued) return 'Find the little cloud in the crystal';
    if (!state.groveGrown) return 'Watch Pip’s rain wake the grove';
    if (!state.seedCollected) return 'Visit the grove and collect a seed';
    if (!state.bridgeGrown) return 'Plant your seed at the island’s edge';
    if (!state.lookoutReached) return 'Cross your bridge to Lantern Lookout';
    return 'Little Drift remembers your kindness';
  }

  static Encounter? nearby(WorldState state) {
    for (final (encounter, landmark) in [
      (Encounter.cloud, IslandMap.cloud),
      (Encounter.grove, IslandMap.grove),
      (Encounter.bridge, IslandMap.bridge),
      (Encounter.lookout, IslandMap.lookout),
    ]) {
      if (IslandMap.distance(state.x, state.y, landmark) < 78) return encounter;
    }
    return null;
  }

  static bool study(WorldState state) {
    if (nearby(state) != Encounter.cloud || state.studiedCrystal) return false;
    state.studiedCrystal = true;
    return true;
  }

  static bool act(WorldState state, Encounter encounter) {
    if (nearby(state) != encounter) return false;
    switch (encounter) {
      case Encounter.cloud:
        if (state.cloudRescued) return false;
        state.cloudRescued = true;
      case Encounter.grove:
        if (!state.groveGrown || state.seedCollected) return false;
        state.seedCollected = true;
      case Encounter.bridge:
        if (!state.seedCollected || state.bridgeGrown) return false;
        state.bridgeGrown = true;
      case Encounter.lookout:
        if (!state.bridgeGrown || state.lookoutReached) return false;
        state.lookoutReached = true;
    }
    return true;
  }

  static bool advanceRain(WorldState state, double seconds) {
    if (!state.cloudRescued || state.groveGrown) return false;
    state.rainSeconds = (state.rainSeconds + seconds).clamp(0, 4);
    if (state.rainSeconds < 4) return false;
    state.groveGrown = true;
    return true;
  }

  static bool move(WorldState state, double dx, double dy, double seconds) {
    final length = math.sqrt(dx * dx + dy * dy);
    if (length == 0 || seconds <= 0) return false;
    final distance = 150 * seconds.clamp(0, 0.05);
    final oldX = state.x;
    final oldY = state.y;
    final nextX = state.x + dx / math.max(1, length) * distance;
    final nextY = state.y + dy / math.max(1, length) * distance;
    // Axis-separated stepping permits sliding along rocks and shorelines.
    if (IslandMap.canStand(nextX, state.y, state.bridgeGrown)) state.x = nextX;
    if (IslandMap.canStand(state.x, nextY, state.bridgeGrown)) state.y = nextY;
    return state.x != oldX || state.y != oldY;
  }
}
