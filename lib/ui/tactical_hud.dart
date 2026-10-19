import 'package:flutter/material.dart';
import '../domain/world_state.dart';

class TacticalHud extends StatelessWidget {
  const TacticalHud({super.key, required this.world, required this.changed});
  final WorldState world;
  final VoidCallback changed;
  @override
  Widget build(BuildContext context) {
    final l = world.loadout;
    Widget slot(String label, IconData icon, VoidCallback action) => Expanded(
        child: InkWell(
            onTap: () {
              action();
              changed();
            },
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 16, color: const Color(0xffffdeb0)),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 9))
                ]))));
    return Container(
        key: const ValueKey('tactical-hud'),
        padding: const EdgeInsets.fromLTRB(9, 6, 9, 2),
        decoration: BoxDecoration(
            color: const Color(0xdc203b46),
            borderRadius: BorderRadius.circular(9)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Icon(Icons.favorite, size: 11, color: Color(0xffefab98)),
            const SizedBox(width: 5),
            Expanded(
                child: LinearProgressIndicator(
                    value: (world.vitals.health / world.vitals.maxHealth)
                        .clamp(0, 1),
                    minHeight: 5,
                    color: const Color(0xffefab98),
                    backgroundColor: const Color(0xff48606a))),
            const SizedBox(width: 5),
            Text(
                '${world.vitals.health.round()}/${world.vitals.maxHealth.round()}',
                style: const TextStyle(color: Colors.white, fontSize: 9))
          ]),
          const SizedBox(height: 4),
          LinearProgressIndicator(
              value: world.vitals.stamina / 100,
              minHeight: 3,
              color: const Color(0xff9bd5c3),
              backgroundColor: const Color(0xff48606a)),
          Row(children: [
            slot(
                '${l.weapon.name} ${l.weapon == Weapon.slingshot ? "∞" : WeaponStats.of(l.weapon).speed > 0 ? l.ammo : ""}',
                Icons.sports_martial_arts,
                l.cycleWeapon),
            slot(
                '${ThrowableKind.values[l.throwable].name} ${l.supplies[l.throwable]}',
                Icons.circle_outlined,
                () => l.throwable = (l.throwable + 1) % 3),
            slot('${PlayerPower.values[l.power].name} ${l.energy.round()}%',
                Icons.auto_awesome, () => l.power = (l.power + 1) % 3)
          ]),
          if (world.map.biome == Biome.winter || world.vitals.warmth < 99)
            Text(
                'WARMTH ${world.vitals.warmth.round()}% · camp / lodge to warm up',
                style: const TextStyle(color: Color(0xffc4e5e9), fontSize: 8)),
        ]));
  }
}

class TacticalActions extends StatelessWidget {
  const TacticalActions(
      {super.key,
      required this.jump,
      required this.attack,
      required this.throwGear,
      required this.power,
      required this.bag,
      required this.sprint,
      required this.explore,
      required this.running});
  final VoidCallback jump, attack, throwGear, power, bag, sprint, explore;
  final bool running;
  @override
  Widget build(BuildContext context) {
    Widget button(String tip, IconData icon, VoidCallback action,
            {double size = 42, bool selected = false}) =>
        Container(
            width: size,
            height: size,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? const Color(0xee917544)
                    : const Color(0xcc294751),
                border: Border.all(color: const Color(0x99c3d4cc))),
            child: IconButton(
                tooltip: tip,
                padding: EdgeInsets.zero,
                onPressed: action,
                icon: Icon(icon,
                    color: const Color(0xffffe9c7), size: size * .45)));
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        button('Backpack', Icons.backpack_outlined, bag),
        button('Toggle sprint', Icons.directions_run, sprint,
            selected: running),
        button(
            'Forage / switch / vault / bridge', Icons.travel_explore, explore)
      ]),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        button('Jump / double jump', Icons.arrow_upward, jump, size: 54),
        button('Attack', Icons.gps_fixed, attack, size: 58)
      ]),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        button('Throw tactical gear', Icons.blur_circular, throwGear),
        button('Activate power', Icons.bolt, power)
      ]),
    ]);
  }
}
