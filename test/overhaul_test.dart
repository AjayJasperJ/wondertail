import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:wondertail/domain/world_state.dart';

void main() {
  test('closed vault geometry blocks traversal and melee; breach opens it', () {
    final w = WorldState(islandIndex: 6, highestVisited: 6, highestUnlocked: 6);
    final p = w.map.secretPoint(0);
    expect(ActionRules.groundedClear(w, p), isFalse);
    WorldGenerator.breach(w, p);
    expect(ActionRules.groundedClear(w, p), isTrue);
    final room = WorldState();
    room.map.obstacles.clear();
    room.x = 640;
    room.y = 480;
    room.map.obstacles.add(Obstacle(const Point2(675, 480), 12));
    final mob = Hostile(const Point2(710, 480), const Point2(710, 480), 100);
    room.hostiles.add(mob);
    CombatRules.attack(room);
    expect(mob.health, 100);
  });
  test('forage respects consumable weight without spending its saved gift', () {
    final w = WorldState(bag: ExpeditionBag(herbs: 43, tonics: 2));
    MobAI.ensureSpawns(w);
    w.x = w.passives.first.position.x;
    w.y = w.passives.first.position.y;
    WorldGenerator.interact(w);
    expect(w.bag.weight, 45);
    expect(w.progress.secrets & 16, 0);
    w.bag.tonics = 0;
    WorldGenerator.interact(w);
    expect(w.bag.herbs, 45);
    expect(w.progress.secrets & 16, 16);
  });
  test('melee strikes face forward and chain damage without hitting behind',
      () {
    final w = WorldState();
    w.x = 640;
    w.y = 480;
    final front = Hostile(const Point2(690, 480), const Point2(690, 480), 500);
    final back = Hostile(const Point2(590, 480), const Point2(590, 480), 500);
    w.hostiles.addAll([front, back]);
    expect(CombatRules.attack(w), isTrue);
    expect(front.health, 465);
    expect(back.health, 500);
    w.vitals.attackCooldown = 0;
    expect(CombatRules.attack(w), isTrue);
    expect(w.loadout.combo, 1);
    expect(front.health, 423);
    expect(CombatRules.attack(w), isFalse);
  });
  test('ranged ammo is consumed once and swept projectile hits a mob', () {
    final w = WorldState();
    w.x = 640;
    w.y = 480;
    w.loadout.owned |= 1 << Weapon.gun.index;
    w.loadout.selected = Weapon.gun.index;
    final enemy = Hostile(const Point2(730, 480), const Point2(730, 480), 100);
    w.hostiles.add(enemy);
    expect(CombatRules.attack(w), isTrue);
    expect(w.loadout.ammo, 23);
    CombatRules.tick(w, .15);
    expect(enemy.health, 70);
    expect(w.projectiles.length, 0);
    w.vitals.attackCooldown = 0;
    w.loadout.ammo = 0;
    expect(CombatRules.attack(w), isFalse);
  });
  test('solid geometry blocks fast projectiles before an enemy', () {
    final w = WorldState();
    w.x = 640;
    w.y = 480;
    w.map.obstacles.clear();
    w.map.obstacles.add(Obstacle(const Point2(690, 480), 20));
    final enemy = Hostile(const Point2(730, 480), const Point2(730, 480), 100);
    w.hostiles.add(enemy);
    w.projectiles.add(Projectile(w.position, const Point2(900, 0), 60, 1));
    CombatRules.tick(w, .15);
    expect(enemy.health, 100);
    expect(w.projectiles.length, 0);
  });
  test('throwables fuse, apply area damage, and consume finite supplies', () {
    final w = WorldState();
    w.x = 640;
    w.y = 480;
    final enemy = Hostile(const Point2(700, 480), const Point2(700, 480), 200);
    w.hostiles.add(enemy);
    expect(CombatRules.throwGear(w), isTrue);
    expect(w.loadout.supplies[0], 2);
    for (var i = 0; i < 9; i++) {
      CombatRules.tick(w, .15);
    }
    expect(enemy.health, 100);
    expect(w.ordnance.single.detonated, isTrue);
    w.loadout.supplies[0] = 0;
    expect(CombatRules.throwGear(w), isFalse);
  });
  test('powers respect energy, cooldown, room boundaries and collisions', () {
    final w = WorldState();
    w.x = 640;
    w.y = 480;
    w.map.obstacles.clear();
    w.map.obstacles.add(Obstacle(const Point2(700, 480), 30));
    expect(CombatRules.power(w), isTrue);
    expect(w.map.canStand(w.position), isTrue);
    expect(w.loadout.energy, 60);
    expect(CombatRules.power(w), isFalse);
    w.loadout.powerCooldown = 0;
    w.loadout.power = 1;
    expect(CombatRules.power(w), isTrue);
    expect(w.vitals.invulnerable, 3);
    w.room = 1;
    w.loadout.powerCooldown = 0;
    w.loadout.energy = 100;
    expect(CombatRules.power(w), isFalse);
    expect(w.loadout.energy, 100);
  });
  test('equipment crafting and save migration retain a validated loadout', () {
    final w = WorldState(bag: ExpeditionBag(crystals: 9, herbs: 9));
    expect(w.loadout.craftWeapon(w, Weapon.gun), isFalse);
    w.room = 2;
    expect(w.loadout.craftWeapon(w, Weapon.gun), isTrue);
    expect(w.bag.crystals, 5);
    expect(w.loadout.craftWeapon(w, Weapon.gun), isFalse);
    expect(w.loadout.restock(w, ammunition: true), isTrue);
    final saved = WorldState.decode(w.encode());
    expect(saved.loadout.toJson(), w.loadout.toJson());
    final old = w.toJson()
      ..['generatorVersion'] = 4
      ..remove('loadout')
      ..remove('expansionStart');
    final legacy = WorldState.decode(jsonEncode(old));
    expect(legacy.loadout.owns(Weapon.sword), isTrue);
    expect(legacy.map.expanded, isFalse);
    expect(legacy.expansionStart, 3);
  });
  test(
      'archetypes have health, load and knockback differences; gathering respects weight',
      () {
    final scout = WorldState(character: 1), heavy = WorldState(character: 2);
    expect(scout.vitals.maxHealth, 80);
    expect(heavy.vitals.maxHealth, 125);
    expect(ExplorerStats.forCharacter(2).knockback,
        lessThan(ExplorerStats.forCharacter(1).knockback));
    scout.bag.herbs = 30;
    final point = scout.map.resource(0);
    scout.x = point.x;
    scout.y = point.y;
    expect(ActionRules.gather(scout), 0);
    expect(scout.progress.gathered, 0);
    expect(WorldState.decode(heavy.encode()).vitals.health, 125);
  });
  test(
      'expanded maps are three times wider, cover every realm and keep routes connected',
      () {
    final biomes = <Biome>{};
    for (var i = 3; i < 19; i++) {
      final m = IslandMap.generate(4271 + i * 79, i, expanded: true);
      final old = IslandMap.generate(4271 + i * 79, i);
      expect(m.scaleX / old.scaleX, closeTo(3, .00001));
      biomes.add(m.biome);
      final targets = [
        m.friend,
        m.wonder,
        m.gate,
        ...m.collectibles,
        m.cave,
        m.lodge,
        m.ruins
      ];
      for (var t = 0; t < m.trails.length; t++) {
        final trail = m.trails[t];
        expect(trail.last.distanceTo(targets[t]), lessThan(.01),
            reason: 'Island $i target $t');
        for (var j = 1; j < trail.length; j++) {
          expect(m.navigation.segment(trail[j - 1], trail[j]), isTrue);
        }
      }
    }
    expect(biomes.length, 8);
  });
  test('biome mobs have distinct behavior and remain capped', () {
    for (final index in [6, 7, 8, 9, 10]) {
      final w = WorldState(
          islandIndex: index, highestVisited: index, highestUnlocked: index);
      MobAI.ensureSpawns(w);
      expect(w.hostiles.length, lessThanOrEqualTo(9));
      expect(w.passives.length, 3);
      expect(w.hostiles.any((m) => m.kind == MobKind.elite), isTrue);
      final before = w.hostiles.length;
      MobAI.ensureSpawns(w);
      expect(w.hostiles.length, before);
      if (index == 6 || index == 8) {
        expect(w.hostiles.first.kind, MobKind.burrower);
      }
      if (index == 10) expect(w.hostiles.first.kind, MobKind.flier);
    }
  });
  test(
      'vault requires breach and guardian defeat, rewards and forage pay only once',
      () {
    final w = WorldState(islandIndex: 6, highestVisited: 6, highestUnlocked: 6);
    MobAI.ensureSpawns(w);
    final p = w.map.secretPoint(0);
    w.x = p.x;
    w.y = p.y;
    WorldGenerator.breach(w, p);
    final before = w.loadout.ammo;
    WorldGenerator.interact(w);
    expect(w.loadout.ammo, before);
    for (final mob in w.hostiles) {
      mob.health = 0;
    }
    WorldGenerator.interact(w);
    expect(w.room, 3);
    w.x = 640;
    w.y = 380;
    WorldGenerator.interact(w);
    expect(w.loadout.ammo, before + 20);
    WorldGenerator.interact(w);
    expect(w.loadout.ammo, before + 20);
    expect(WorldState.decode(w.encode()).progress.secrets & 2, 2);
    final normal = WorldState();
    MobAI.ensureSpawns(normal);
    normal.x = normal.passives.first.position.x;
    normal.y = normal.passives.first.position.y;
    WorldGenerator.interact(normal);
    expect(normal.bag.herbs, 2);
    WorldGenerator.interact(normal);
    expect(normal.bag.herbs, 2);
  });
  test('winter thermal exposure and a crafted bridge affect hazards', () {
    final w = WorldState(
        islandIndex: 7,
        highestVisited: 7,
        highestUnlocked: 7,
        bag: ExpeditionBag(crystals: 3, herbs: 3));
    w.x = 640;
    w.y = 480;
    final warmth = w.vitals.warmth;
    WorldGenerator.environment(w, 1);
    expect(w.vitals.warmth, lessThan(warmth));
    final lava = w.map.lava(0);
    w.x = lava.x;
    w.y = lava.y;
    expect(WorldGenerator.inLava(w, w.position, 0), isTrue);
    expect(WorldGenerator.bridge(w), isTrue);
    expect(WorldGenerator.inLava(w, w.position, 0), isFalse);
    expect(WorldGenerator.bridge(w), isFalse);
    expect(w.bag.crystals, 1);
  });
}
