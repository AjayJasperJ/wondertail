part of 'world_state.dart';

enum Weapon { sword, dagger, hammer, gun, bow, slingshot }

enum ThrowableKind { grenade, gas, charge }

enum PlayerPower { dash, shield, burst }

class WeaponStats {
  const WeaponStats(
      this.damage, this.reach, this.cooldown, this.cost, this.speed);
  final double damage, reach, cooldown, cost, speed;
  static WeaponStats of(Weapon w) => const [
        WeaponStats(35, 90, .45, 8, 0),
        WeaponStats(22, 65, .22, 5, 0),
        WeaponStats(65, 120, .9, 16, 0),
        WeaponStats(30, 650, .28, 2, 650),
        WeaponStats(42, 560, .65, 8, 420),
        WeaponStats(18, 400, .4, 6, 360),
      ][w.index];
}

class CombatLoadout {
  CombatLoadout();
  int owned = 33, ammo = 24, selected = 0, throwable = 0, power = 0;
  final List<int> supplies = [3, 1, 1];
  double energy = 100, powerCooldown = 0, shieldTime = 0, comboTime = 0;
  int combo = 0;
  Weapon get weapon => Weapon.values[selected];
  bool owns(Weapon w) => owned & (1 << w.index) != 0;
  bool craftWeapon(WorldState w, Weapon weapon) {
    if (w.room != 2 || owns(weapon)) return false;
    final cost = weapon == Weapon.gun
        ? 4
        : weapon == Weapon.hammer
            ? 3
            : 2;
    if (w.bag.crystals < cost || w.bag.herbs < 1) return false;
    w.bag.crystals -= cost;
    w.bag.herbs--;
    owned |= 1 << weapon.index;
    selected = weapon.index;
    return true;
  }

  bool restock(WorldState w, {bool ammunition = false}) {
    if (w.room != 2 ||
        w.bag.crystals < 1 ||
        w.bag.herbs < 1 ||
        (ammunition ? ammo > 490 : supplies[throwable] >= 20)) {
      return false;
    }
    w.bag.crystals--;
    w.bag.herbs--;
    if (ammunition) {
      ammo += 10;
    } else {
      supplies[throwable]++;
    }
    return true;
  }

  void cycleWeapon() {
    do {
      selected = (selected + 1) % Weapon.values.length;
    } while (!owns(weapon));
  }

  Map<String, Object> toJson() => {
        'owned': owned,
        'ammo': ammo,
        'selected': selected,
        'throwable': throwable,
        'power': power,
        'supplies': supplies,
        'energy': energy
      };
  factory CombatLoadout.fromJson(dynamic j) {
    final l = CombatLoadout();
    if (j == null) return l;
    if (j is! Map) throw const FormatException('Invalid loadout.');
    for (final key in ['owned', 'ammo', 'selected', 'throwable', 'power']) {
      final n = j[key];
      if (n is! int ||
          n < 0 ||
          n >
              ({
                'owned': 63,
                'ammo': 500,
                'selected': 5,
                'throwable': 2,
                'power': 2
              }[key]!)) {
        throw const FormatException('Invalid equipment.');
      }
    }
    final s = j['supplies'], e = j['energy'];
    if (s is! List ||
        s.length != 3 ||
        s.any((v) => v is! int || v < 0 || v > 20) ||
        e is! num ||
        !e.isFinite ||
        e < 0 ||
        e > 100 ||
        (j['owned'] & 1) == 0 ||
        (j['owned'] & (1 << j['selected'])) == 0) {
      throw const FormatException('Invalid supplies.');
    }
    l.owned = j['owned'];
    l.ammo = j['ammo'];
    l.selected = j['selected'];
    l.throwable = j['throwable'];
    l.power = j['power'];
    l.energy = e.toDouble();
    for (var i = 0; i < 3; i++) {
      l.supplies[i] = s[i];
    }
    return l;
  }
}

class Projectile {
  Projectile(this.position, this.velocity, this.damage, this.life,
      {this.hostile = false});
  Point2 position;
  final Point2 velocity;
  final double damage;
  double life;
  final bool hostile;
}

class Ordnance {
  Ordnance(this.position, this.velocity, this.kind);
  Point2 position, velocity;
  final ThrowableKind kind;
  double age = 0, cloud = 0;
  bool detonated = false;
  double get fuse => kind == ThrowableKind.charge
      ? 2.3
      : kind == ThrowableKind.gas
          ? .65
          : 1.1;
}

class CombatRules {
  static bool attack(WorldState w) {
    if (w.room != 0 || w.vitals.attackCooldown > 0) return false;
    final l = w.loadout, s = WeaponStats.of(l.weapon);
    if (w.vitals.stamina < s.cost ||
        (s.speed > 0 && l.weapon != Weapon.slingshot && l.ammo == 0) ||
        (s.speed > 0 && w.projectiles.length >= 48)) {
      return false;
    }
    w.vitals.stamina -= s.cost;
    w.vitals.attackCooldown = s.cooldown;
    w.attackFlash = .18;
    if (s.speed > 0) {
      if (l.weapon != Weapon.slingshot) l.ammo--;
      w.projectiles.add(Projectile(
          w.position, w.facing * s.speed, s.damage, s.reach / s.speed));
      return true;
    }
    l.combo = l.comboTime > 0 ? (l.combo + 1) % 3 : 0;
    l.comboTime = 1.4;
    final strength = ExplorerStats.forCharacter(w.character).strength;
    for (final enemy in w.hostiles) {
      final d = enemy.position - w.position;
      if (enemy.alive &&
          d.length < s.reach &&
          (d.length < 20 ||
              (d.x * w.facing.x + d.y * w.facing.y) / d.length > .2)) {
        hit(w, enemy, s.damage * strength * (1 + l.combo * .2));
        final next = enemy.position + d * (30 / math.max(1, d.length));
        if (w.map.canStand(next) && ActionRules.groundedClear(w, next)) {
          enemy.position = next;
        }
      }
    }
    return true;
  }

  static void hit(WorldState w, Hostile enemy, double damage) {
    if (!enemy.alive) return;
    enemy.health -= damage;
    w.loadout.energy = math.min(100, w.loadout.energy + damage * .15);
  }

  static bool throwGear(WorldState w) {
    final l = w.loadout;
    if (w.room != 0 || l.supplies[l.throwable] == 0 || w.ordnance.length >= 8) {
      return false;
    }
    l.supplies[l.throwable]--;
    w.ordnance.add(Ordnance(
        w.position, w.facing * 220, ThrowableKind.values[l.throwable]));
    return true;
  }

  static bool power(WorldState w) {
    final l = w.loadout;
    if (w.room != 0 || l.energy < 40 || l.powerCooldown > 0) return false;
    l.energy -= 40;
    l.powerCooldown = 6;
    switch (PlayerPower.values[l.power]) {
      case PlayerPower.dash:
        w.vitals.invulnerable = math.max(w.vitals.invulnerable, .6);
        for (var i = 0; i < 20; i++) {
          final next = w.map.slide(w.position, w.facing * 9);
          if (!EngagementRules.passable(w, next)) break;
          w.x = next.x;
          w.y = next.y;
        }
      case PlayerPower.shield:
        l.shieldTime = 3;
        w.vitals.invulnerable = math.max(w.vitals.invulnerable, 3);
      case PlayerPower.burst:
        w.attackFlash = .5;
        for (final enemy in w.hostiles) {
          if (enemy.position.distanceTo(w.position) < 190) hit(w, enemy, 75);
        }
    }
    return true;
  }

  static void tick(WorldState w, double dt) {
    final l = w.loadout;
    l.powerCooldown = math.max(0, l.powerCooldown - dt);
    l.shieldTime = math.max(0, l.shieldTime - dt);
    l.comboTime = math.max(0, l.comboTime - dt);
    l.energy = math.min(100, l.energy + dt * 1.5);
    if (w.room != 0) return;
    // Swept substeps prevent fast shots tunnelling through solid scenery.
    for (final shot in w.projectiles.toList()) {
      final steps = math.max(1, (shot.velocity.length * dt / 8).ceil());
      for (var i = 0; i < steps && shot.life > 0; i++) {
        shot.life -= dt / steps;
        final next = shot.position + shot.velocity * (dt / steps);
        if (!w.map.onLand(next) ||
            !ActionRules.groundedClear(w, next) ||
            w.map.obstacles
                .any((o) => !o.pond && next.distanceTo(o.center) < o.radius)) {
          shot.life = 0;
          break;
        }
        shot.position = next;
        if (shot.hostile) {
          if (w.vitals.z < 35 && next.distanceTo(w.position) < 20) {
            ActionRules.damage(w, shot.damage);
            shot.life = 0;
          }
        } else {
          for (final enemy in w.hostiles) {
            if (enemy.alive && next.distanceTo(enemy.position) < 23) {
              hit(w, enemy, shot.damage);
              shot.life = 0;
              break;
            }
          }
        }
      }
    }
    w.projectiles.removeWhere((p) => p.life <= 0);
    for (final bomb in w.ordnance) {
      bomb.age += dt;
      if (!bomb.detonated) {
        final next = bomb.position + bomb.velocity * dt;
        if (w.map.onLand(next) &&
            ActionRules.groundedClear(w, next) &&
            !w.map.obstacles.any(
                (o) => !o.pond && next.distanceTo(o.center) < o.radius + 8)) {
          bomb.position = next;
        } else {
          bomb.velocity = const Point2(0, 0);
        }
        bomb.velocity = bomb.velocity * math.exp(-3 * dt);
        if (bomb.age >= bomb.fuse) {
          bomb.detonated = true;
          bomb.cloud = bomb.kind == ThrowableKind.gas ? 4 : .35;
          for (final enemy in w.hostiles) {
            if (enemy.position.distanceTo(bomb.position) < 125) {
              hit(w, enemy, bomb.kind == ThrowableKind.gas ? 0 : 100);
            }
          }
          if (bomb.kind != ThrowableKind.gas) {
            WorldGenerator.breach(w, bomb.position);
          }
        }
      } else {
        bomb.cloud -= dt;
        if (bomb.kind == ThrowableKind.gas) {
          for (final enemy in w.hostiles) {
            if (enemy.position.distanceTo(bomb.position) < 125) {
              hit(w, enemy, 18 * dt);
            }
          }
        }
      }
    }
    w.ordnance.removeWhere((b) => b.detonated && b.cloud <= 0);
  }
}
