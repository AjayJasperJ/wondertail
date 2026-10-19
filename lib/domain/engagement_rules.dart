part of 'world_state.dart';

extension IslandVariation on IslandMap {
  IslandMutator get mutator => index < 3
      ? IslandMutator.calm
      : IslandMutator.values[1 +
          SeededRandom((variationSeed ^ (index * 7919)) & 0x7fffffff)
              .nextInt(3)];
  int get variant => index < 3 ? 0 : (index + variationSeed) % 3;
  String get condition => [
        'Clear skies',
        'Breezy currents',
        'Misty shroud',
        'Overgrown paths'
      ][mutator.index];
  String get conditionHint => switch (mutator) {
        IslandMutator.calm => 'Explore at your own pace.',
        IslandMutator.breeze => 'Blue wind lanes boost movement and push east.',
        IslandMutator.mist =>
          'Visibility is reduced. Your compass still works.',
        IslandMutator.overgrowth =>
          'Find the shears near camp to clear the vine gate, or walk around.',
      };
  List<int> get collectionOrder => variant == 0
      ? [0, 1, 2]
      : variant == 1
          ? [2, 0, 1]
          : [1, 2, 0];
  int get chambers => 2 + (index + variationSeed) % 2;
  int solution(int branch) => 1 + (variationSeed + index + branch) % 3;
  Point2 get shears => trails.first[(trails.first.length * 0.18).floor()];
  Point2 get vineGate => trails.first[(trails.first.length * 0.62).floor()];
  Point2 get windLane => trails[1][(trails[1].length * 0.55).floor()];
  Point2 get hiddenCache => trails.last[(trails.last.length * 0.68).floor()];
  Point2 crystalPoint(int i) => Point2(
      500 + ((index + variationSeed + i) % 3) * 115.0,
      360 + ((index + i) % 2) * 50.0);
  double inset(int chamber) => ((index + variationSeed + chamber) % 3) * 10.0;
  int crystalRoom(int i) => i == 0
      ? 0
      : chambers == 2
          ? 1
          : i;
  Point2 get mirrorPoint => Point2(620 + (index % 3) * 20.0, 445);
  Point2 get scoutPoint => Point2(610 + (index % 3) * 30.0, 380);
}

class EngagementRules {
  static bool cacheVisible(WorldState w) =>
      w.progress.cacheOpened ||
      w.profile.archives > 0 ||
      (w.profile.rank(Adventure.lantern) >= 2 &&
          w.map.biome == Biome.twilight) ||
      w.profile.rank(Adventure.lantern) == 3 ||
      w.profile.rank(Adventure.garden) >= 2;

  static bool passable(WorldState w, Point2 point) =>
      w.map.canStand(point) &&
      !(w.map.mutator == IslandMutator.overgrowth &&
          !w.progress.vinesCleared &&
          point.distanceTo(w.map.vineGate) < 23 + IslandMap.playerRadius);

  static bool favor(WorldState w) {
    if (w.run != null ||
        w.room != 0 ||
        w.position.distanceTo(w.map.friend) >= 88 ||
        !w.progress.complete ||
        w.progress.favorGiven ||
        w.profile.seeds < 1) {
      return false;
    }
    w.progress.favorGiven = true;
    w.profile.reconcile(w);
    return true;
  }

  static bool glide(WorldState w) {
    if (w.room != 0 ||
        w.profile.cape != 2 ||
        !w.profile.owns(WorkshopItem.gliderCape)) {
      return false;
    }
    if (!passable(w, w.position)) return false;
    for (final pond in w.map.obstacles.where((o) => o.pond)) {
      final delta = w.position - pond.center;
      if (delta.length < pond.radius + 14 || delta.length > pond.radius + 100) {
        continue;
      }
      final direction = delta * (-1 / delta.length);
      for (final angle in [0.0, 0.35, -0.35, 0.7, -0.7, 1.0, -1.0]) {
        final rotated = Point2(
            direction.x * math.cos(angle) - direction.y * math.sin(angle),
            direction.x * math.sin(angle) + direction.y * math.cos(angle));
        final landing = pond.center + rotated * (pond.radius + 35);
        if (!passable(w, landing)) continue;
        final segment = landing - w.position;
        final t = (-(delta.x * segment.x + delta.y * segment.y) /
                (segment.x * segment.x + segment.y * segment.y))
            .clamp(0.0, 1.0);
        if ((delta + segment * t).length >= pond.radius - 3) continue;
        w.x = landing.x;
        w.y = landing.y;
        return true;
      }
    }
    return false;
  }

  static Encounter? nearby(WorldState w) {
    if (w.room == 1) {
      if (w.chamber == 0) {
        if (w.position.distanceTo(w.map.mirrorPoint) < 65) {
          return Encounter.mirror;
        }
        if (w.position.distanceTo(const Point2(475, 500)) < 65) {
          return Encounter.passageLeft;
        }
        if (w.map.chambers == 3 &&
            w.position.distanceTo(const Point2(805, 500)) < 65) {
          return Encounter.passageRight;
        }
      }
      return null;
    }
    if (w.room != 0) return null;
    if (w.map.mutator == IslandMutator.overgrowth) {
      if (!w.progress.toolFound && w.position.distanceTo(w.map.shears) < 60) {
        return Encounter.tool;
      }
      if (!w.progress.vinesCleared &&
          w.position.distanceTo(w.map.vineGate) < 80) {
        return Encounter.vines;
      }
    }
    if (!w.progress.cacheOpened &&
        cacheVisible(w) &&
        w.position.distanceTo(w.map.hiddenCache) < 65) {
      return Encounter.cache;
    }
    if (w.profile.cape == 2 &&
        w.map.obstacles.any((o) =>
            o.pond && w.position.distanceTo(o.center) < o.radius + 100)) {
      return Encounter.glide;
    }
    return null;
  }

  static bool act(WorldState w, Encounter e) {
    switch (e) {
      case Encounter.tool:
        w.progress.toolFound = true;
        return true;
      case Encounter.vines:
        if (!w.progress.toolFound) return false;
        w.progress.vinesCleared = true;
        return true;
      case Encounter.cache:
        if (w.progress.cacheOpened || !cacheVisible(w)) return false;
        w.progress.cacheOpened = true;
        w.profile.reconcile(w);
        return true;
      case Encounter.mirror:
        w.progress.mirror = (w.progress.mirror + 1) % 4;
        return true;
      case Encounter.passageLeft:
      case Encounter.passageRight:
        final branch = e == Encounter.passageLeft ? 1 : 2;
        if (branch >= w.map.chambers ||
            w.progress.mirror != w.map.solution(branch)) {
          return false;
        }
        w.chamber = branch;
        w.x = 640;
        w.y = 610;
        return true;
      case Encounter.glide:
        return glide(w);
      default:
        return false;
    }
  }
}
