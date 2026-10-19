import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wondertail/data/save_repository.dart';
import 'package:wondertail/domain/world_state.dart';
import 'package:wondertail/main.dart';
import 'package:wondertail/ui/game_screen.dart';

class MemoryStore implements SaveStore {
  final data = <String, String>{};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async {
    data[key] = value;
  }
}

Future<void> frames(WidgetTester tester, [int count = 30]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('workshop purchase is permanent and equippable from the lobby',
      (tester) async {
    tester.view.physicalSize = const Size(740, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final saves = SaveRepository(MemoryStore());
    final world = WorldState();
    world.profile.coins = 48;
    world.profile.cores = 2;
    await tester
        .pumpWidget(WondertailApp(saves: saves, loaded: LoadResult(world)));
    await tester.ensureVisible(find.byKey(const ValueKey('open-workshop')));
    await tester.tap(find.byKey(const ValueKey('open-workshop')));
    await frames(tester);
    final cape = find.byKey(const ValueKey('workshop-0'));
    await tester.ensureVisible(cape);
    await tester.tap(cape);
    await frames(tester);
    expect(world.profile.coins, 36);
    expect(world.profile.cape, 1);
    expect(
        (await saves.load()).state.profile.owns(WorkshopItem.starCape), isTrue);
    await tester.tap(cape);
    await frames(tester);
    expect(world.profile.coins, 36);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Trailblazer timer expires without changing the normal world',
      (tester) async {
    tester.view.physicalSize = const Size(740, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final saves = SaveRepository(MemoryStore());
    final world = WorldState(highestUnlocked: 3);
    await tester
        .pumpWidget(WondertailApp(saves: saves, loaded: LoadResult(world)));
    await tester.ensureVisible(find.byKey(const ValueKey('open-trailblazer')));
    await tester.tap(find.byKey(const ValueKey('open-trailblazer')));
    await frames(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('start-trailblazer')));
    await tester.tap(find.byKey(const ValueKey('start-trailblazer')));
    await frames(tester);
    final trial =
        tester.widget<GameScreen>(find.byType(GameScreen)).loaded.state;
    expect(trial.run, isNotNull);
    trial.run!.tick(420);
    await frames(tester);
    expect(find.text('The starlight settled'), findsOneWidget);
    await tester.ensureVisible(find.text('Return to lobby').last);
    await tester.tap(find.text('Return to lobby').last);
    await frames(tester);
    final original = (await saves.load()).state;
    expect((
      original.islandIndex,
      original.highestUnlocked,
      original.profile.coins
    ), (
      0,
      3,
      0
    ));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'lobby saves explorer/settings and opens selected unlocked island',
      (tester) async {
    tester.view.physicalSize = const Size(740, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final saves = SaveRepository(MemoryStore());
    final world = WorldState(highestUnlocked: 1);
    await tester
        .pumpWidget(WondertailApp(saves: saves, loaded: LoadResult(world)));
    expect(find.byType(GameScreen), findsNothing);
    await tester.tap(find.byKey(const ValueKey('lobby-tab-1')));
    await tester.pump();
    await tester
        .ensureVisible(find.byKey(const ValueKey('choose-character-1')));
    await tester.tap(find.byKey(const ValueKey('choose-character-1')));
    await frames(tester);
    expect(world.character, 1);
    await tester.tap(find.byKey(const ValueKey('lobby-tab-2')));
    await tester.pump();
    await tester.ensureVisible(find.byType(Switch).first);
    await tester.tap(find.byType(Switch).first);
    await frames(tester);
    expect(world.sound, isFalse);
    final restored = await saves.load();
    expect((restored.state.character, restored.state.sound), (1, false));
    await tester.tap(find.byKey(const ValueKey('lobby-tab-3')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('select-island-2')));
    await tester.tap(find.byKey(const ValueKey('select-island-2')));
    await tester.pump();
    expect(find.text('Play island 1'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('select-island-1')));
    await tester.tap(find.byKey(const ValueKey('select-island-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('start-adventure')));
    await frames(tester);
    expect(world.islandIndex, 1);
    expect(find.byType(GameScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Return to lobby'));
    await frames(tester);
    expect(find.byType(GameScreen), findsNothing);
    expect(world.character, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cave can be entered and exited from landscape controls',
      (tester) async {
    tester.view.physicalSize = const Size(740, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final world = WorldState();
    world.x = world.map.cave.x;
    world.y = world.map.cave.y;
    await tester.pumpWidget(WondertailApp(
        startInGame: true,
        saves: SaveRepository(MemoryStore()),
        loaded: LoadResult(world)));
    await frames(tester);
    await tester.tap(find.text('Enter crystal cave'));
    await frames(tester);
    await tester.ensureVisible(find.text('Explore the cave'));
    await tester.tap(find.text('Explore the cave'));
    await frames(tester);
    expect(world.room, 1);
    world.x = WorldRules.roomExit.x;
    world.y = WorldRules.roomExit.y;
    await frames(tester);
    await tester.tap(find.text('Return outside'));
    await frames(tester);
    await tester.tap(find.text('Return outside').last);
    await frames(tester);
    expect(world.room, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
