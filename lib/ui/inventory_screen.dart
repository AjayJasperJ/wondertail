import 'package:flutter/material.dart';
import '../domain/world_state.dart';

class InventoryPanel extends StatelessWidget {
  const InventoryPanel(
      {super.key,
      required this.world,
      required this.onChanged,
      required this.onClose});
  final WorldState world;
  final VoidCallback onChanged, onClose;
  @override
  Widget build(BuildContext context) {
    final bag = world.bag;
    void act(bool Function() action) {
      if (action()) onChanged();
    }

    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Expanded(
                child: Text('EXPEDITION BAG',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            IconButton(onPressed: onClose, icon: const Icon(Icons.close))
          ]),
          Text('${bag.crystals} crystals · ${bag.herbs} herbs'),
          const SizedBox(height: 10),
          Text(
              'Health ${world.vitals.health.round()}/${world.vitals.maxHealth.round()} · Booster ${world.vitals.stamina.round()}/100'),
          Text(
              'Pack ${bag.crystals + bag.herbs + bag.tonics + bag.boosters}/${ExplorerStats.forCharacter(world.character).capacity} · ammo ${world.loadout.ammo}'),
          TextButton(
              onPressed: () => act(() => bag.useTonic(world.vitals)),
              child: Text('Drink tonic (${bag.tonics}) · +50 health')),
          TextButton(
              onPressed: () => act(() => bag.useBooster(world.vitals)),
              child: Text('Drink booster (${bag.boosters}) · refill stamina')),
          const Divider(),
          Text(world.room == 2
              ? 'COLLECTION HUT · CRAFTING'
              : 'Visit a scout lodge to craft.'),
          for (final recipe in Recipe.values)
            TextButton(
                onPressed:
                    world.room != 2 ? null : () => act(() => bag.craft(recipe)),
                child: Text(switch (recipe) {
                  Recipe.tonic => 'Brew tonic · 1 crystal + 2 herbs',
                  Recipe.booster => 'Brew booster · 1 crystal + 1 herb',
                  Recipe.shield => bag.shield
                      ? 'Guard charm equipped · 40% less damage'
                      : 'Craft guard charm · 3 crystals + 1 herb',
                })),
          const Divider(),
          const Text('ARSENAL · equip owned gear; forge new gear at a lodge'),
          for (final weapon in Weapon.values)
            TextButton(
                onPressed: world.loadout.owns(weapon)
                    ? () {
                        world.loadout.selected = weapon.index;
                        onChanged();
                      }
                    : world.room == 2
                        ? () =>
                            act(() => world.loadout.craftWeapon(world, weapon))
                        : null,
                child: Text(
                    '${weapon.name.toUpperCase()} · ${world.loadout.owns(weapon) ? "Equip" : "${weapon == Weapon.gun ? 4 : weapon == Weapon.hammer ? 3 : 2} crystals + 1 herb"}')),
          TextButton(
              onPressed: world.room == 2
                  ? () =>
                      act(() => world.loadout.restock(world, ammunition: true))
                  : null,
              child: const Text('Craft 10 ammo · 1 crystal + 1 herb')),
          TextButton(
              onPressed: world.room == 2
                  ? () => act(() => world.loadout.restock(world))
                  : null,
              child: Text(
                  'Craft ${ThrowableKind.values[world.loadout.throwable].name} · 1 crystal + 1 herb')),
          const Text(
              'Materials persist across islands. Camp recovery keeps your bag.',
              style: TextStyle(fontSize: 11)),
        ]);
  }
}
