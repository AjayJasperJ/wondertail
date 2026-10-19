import 'package:flutter_test/flutter_test.dart';
import 'package:wondertail/domain/world_state.dart';

void place(WorldState w, Point2 at) {
  w.x = at.x;
  w.y = at.y;
}

void main() {
  test(
      'a restored position inside new vines relocates; live movement can escape outward',
      () {
    var index = 3;
    while (
        IslandMap.generate(4271, index).mutator != IslandMutator.overgrowth) {
      index++;
    }
    final world = WorldState(
        islandIndex: index, highestVisited: index, highestUnlocked: index);
    place(world, world.map.vineGate);
    final loaded = WorldState.decode(world.encode());
    expect(EngagementRules.passable(loaded, loaded.position), isTrue);
    for (var i = 0; i < 40; i++) {
      WorldRules.move(world, 1, 0, 1 / 60);
    }
    expect(world.position.distanceTo(world.map.vineGate), greaterThan(36));
  });
  test(
      'wallet imports each pickup and core once; purchases survive serialization',
      () {
    final w = WorldState();
    w.progress.coins = 4095;
    w.profile.reconcile(w);
    w.profile.reconcile(w);
    expect((w.profile.coins, w.profile.cores), (12, 1));
    expect(w.profile.purchase(WorkshopItem.gliderCape), isFalse);
    expect(w.profile.purchase(WorkshopItem.starCape), isTrue);
    expect(w.profile.purchase(WorkshopItem.starCape), isFalse);
    w.profile.reconcile(w);
    expect(w.profile.coins, 0);
    final restored = WorldState.decode(w.encode());
    expect(restored.profile.owns(WorkshopItem.starCape), isTrue);
    expect(restored.profile.cape, 1);
  });

  test('archives increase pickup radius and caches fund one favor per island',
      () {
    final w = WorldState(
        progress: IslandProgress(stage: 3, shards: 7, ruinsRestored: true));
    w.profile.reconcile(w);
    expect(w.profile.coinRadius, 36);
    expect(WorldState.decode(w.encode()).profile.coinRadius, 36);
    expect(EngagementRules.cacheVisible(w), isTrue);
    place(w, w.map.hiddenCache);
    expect(WorldRules.act(w, Encounter.cache), isTrue);
    expect((w.profile.coins, w.profile.seeds), (3, 1));
    place(w, w.map.friend);
    expect(EngagementRules.favor(w), isTrue);
    expect(EngagementRules.favor(w), isFalse);
    expect((w.profile.rank(Adventure.rain), w.profile.seeds), (2, 0));
    w.profile.reconcile(w);
    final bank = w.profile.coins;
    w.profile.reconcile(w);
    expect(w.profile.coins, bank);
  });

  test('all post-tutorial mutators appear; vines have a clearable blocker', () {
    final seen = <IslandMutator>{};
    for (var i = 0; i < 20; i++) {
      final w =
          WorldState(islandIndex: i, highestUnlocked: i, highestVisited: i);
      if (i < 3) {
        expect(w.map.mutator, IslandMutator.calm);
        continue;
      }
      seen.add(w.map.mutator);
      if (w.map.mutator != IslandMutator.overgrowth) continue;
      expect(EngagementRules.passable(w, w.map.vineGate), isFalse);
      place(w, w.map.shears);
      expect(WorldRules.act(w, Encounter.tool), isTrue);
      place(w, w.map.vineGate);
      expect(WorldRules.act(w, Encounter.vines), isTrue);
      expect(EngagementRules.passable(w, w.map.vineGate), isTrue);
    }
    expect(seen.length, 3);
  });

  test('mirror branches are gated, generated, and return to the hub', () {
    final layouts = <String>{};
    for (var i = 0; i < 30; i++) {
      final w =
          WorldState(islandIndex: i, highestUnlocked: i, highestVisited: i);
      place(w, w.map.cave);
      WorldRules.act(w, Encounter.cave);
      layouts.add(
          '${w.map.chambers}/${w.map.crystalPoint(0).x}/${w.map.crystalPoint(0).y}');
      place(w, const Point2(475, 500));
      expect(WorldRules.act(w, Encounter.passageLeft), isFalse);
      for (var branch = 1; branch < w.map.chambers; branch++) {
        place(w, w.map.mirrorPoint);
        while (w.progress.mirror != w.map.solution(branch)) {
          WorldRules.act(w, Encounter.mirror);
        }
        place(w, branch == 1 ? const Point2(475, 500) : const Point2(805, 500));
        expect(
            WorldRules.act(w,
                branch == 1 ? Encounter.passageLeft : Encounter.passageRight),
            isTrue);
        for (var crystal = 0; crystal < 3; crystal++) {
          if (w.map.crystalRoom(crystal) != w.chamber) continue;
          place(w, w.map.crystalPoint(crystal));
          WorldRules.collectShards(w);
        }
        place(w, WorldRules.roomExit);
        WorldRules.act(w, Encounter.exitRoom);
        expect(w.chamber, 0);
      }
      place(w, w.map.crystalPoint(0));
      WorldRules.collectShards(w);
      expect(w.progress.shards, 7);
      expect(WorldState.decode(w.encode()).progress.mirror, w.progress.mirror);
    }
    expect(layouts.length, greaterThan(3));
  });

  test('glider requires ownership and lands beyond water on walkable ground',
      () {
    final w = WorldState();
    final pond = w.map.obstacles.firstWhere((o) => o.pond);
    var successful = false;
    w.profile.coins = 36;
    w.profile.cores = 2;
    expect(w.profile.purchase(WorkshopItem.gliderCape), isTrue);
    for (final direction in [
      const Point2(1, 0),
      const Point2(-1, 0),
      const Point2(0, 1),
      const Point2(0, -1)
    ]) {
      place(w, pond.center + direction * (pond.radius + 35));
      if (!w.map.canStand(w.position)) continue;
      final before = w.position;
      if (!EngagementRules.glide(w)) continue;
      expect(w.map.canStand(w.position), isTrue);
      expect(w.position.distanceTo(before), greaterThan(pond.radius * 2));
      successful = true;
      break;
    }
    expect(successful, isTrue);
  });

  test(
      'challenge rewards are once-only and run pickups do not reach the wallet',
      () {
    final profile = PlayerProfile();
    final trial = WorldState(
        islandIndex: 3,
        highestUnlocked: 3,
        highestVisited: 3,
        profile: profile,
        run: TrailRun());
    trial.progress.coins = 4095;
    profile.reconcile(trial);
    expect(profile.coins, 0);
    trial.run!.tick(80);
    trial.run!.finish(profile);
    expect(
        (profile.coins, profile.cores, profile.bestRunMillis), (24, 2, 80000));
    final again = TrailRun()..tick(60);
    again.finish(profile);
    expect(
        (profile.coins, profile.cores, profile.bestRunMillis), (24, 2, 60000));
    final expired = TrailRun()..tick(420);
    expired.finish(profile);
    expect(expired.won, isFalse);
    expect(profile.owns(WorkshopItem.runnerCape), isTrue);
  });
}
