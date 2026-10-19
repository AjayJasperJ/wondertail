import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wondertail/data/save_repository.dart';
import 'package:wondertail/domain/world_state.dart';
import 'package:wondertail/game/wondertail_game.dart';
import 'package:wondertail/main.dart';

class _Store implements SaveStore {
  final data = <String, String>{};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async {
    data[key] = value;
  }
}

Future<void> frames(WidgetTester tester, [int count = 12]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('tactical HUD stays below play and right controls operate gear',
      (tester) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final w = WorldState();
    await tester.pumpWidget(WondertailApp(
        startInGame: true,
        saves: SaveRepository(_Store()),
        loaded: LoadResult(w)));
    await frames(tester);
    final hud = tester.getRect(find.byKey(const ValueKey('tactical-hud')));
    final stick =
        tester.getRect(find.byKey(const ValueKey('movement-joystick')));
    final attack = tester.getRect(find.byTooltip('Attack'));
    expect(hud.height, lessThan(100));
    expect(hud.top, greaterThan(250));
    expect(stick.right, lessThan(hud.left));
    expect(hud.right, lessThan(attack.left));
    await tester.tap(find.byTooltip('Throw tactical gear'));
    await frames(tester, 2);
    expect(w.loadout.supplies[0], 2);
    await tester.tap(find.byTooltip('Activate power'));
    await frames(tester, 2);
    expect(w.loadout.energy, lessThan(70));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyQ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyQ);
    await frames(tester, 2);
    expect(w.loadout.weapon, Weapon.slingshot);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('bottom action controls jump and backpack pauses play',
      (tester) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final world = WorldState(bag: ExpeditionBag(tonics: 1));
    world.vitals.health = 40;
    await tester.pumpWidget(WondertailApp(
        startInGame: true,
        saves: SaveRepository(_Store()),
        loaded: LoadResult(world)));
    await frames(tester);
    await tester.tap(find.byTooltip('Jump / double jump'));
    await frames(tester, 5);
    expect(world.vitals.z, greaterThan(0));
    await tester.tap(find.byTooltip('Backpack'));
    await frames(tester);
    final pausedZ = world.vitals.z;
    await frames(tester, 20);
    expect(world.vitals.z, pausedZ);
    expect(find.text('EXPEDITION BAG'), findsOneWidget);
    await tester.tap(find.text('Drink tonic (1) · +50 health'));
    await frames(tester);
    expect(world.vitals.health, 90);
    expect(world.bag.tonics, 0);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('analog drag walks, release stops, themed journal pauses input', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final world = WorldState();
    await tester.pumpWidget(
      WondertailApp(
          startInGame: true,
          saves: SaveRepository(_Store()),
          loaded: LoadResult(world)),
    );
    await frames(tester);
    final joystick = find.byKey(const ValueKey('movement-joystick'));
    final center = tester.getCenter(joystick);
    final gesture = await tester.startGesture(center + const Offset(40, 0));
    await frames(tester, 20);
    expect(world.x, greaterThan(world.map.arrival.x + 25));
    await gesture.up();
    final cancelled = await tester.startGesture(center + const Offset(0, -35));
    await frames(tester, 5);
    await cancelled.cancel();
    final cancelledY = world.y;
    await frames(tester, 5);
    expect(world.y, cancelledY);
    final stopped = world.x;
    await frames(tester, 10);
    expect(world.x, stopped);
    await tester.tap(find.byTooltip('Your trail and journal'));
    await frames(tester);
    expect(find.text('Your endless trail'), findsOneWidget);
    final panel = tester.getRect(find.byKey(const ValueKey('adventure-panel')));
    expect(panel.width, lessThan(844 * 0.5));
    expect(panel.height, lessThan(390 * 0.8));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
    await frames(tester);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
    expect(world.x, stopped);
    await tester.tap(find.byTooltip('Close journal'));
    await frames(tester);
    tester.view.physicalSize = const Size(640, 360);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      tester
          .getRect(joystick)
          .overlaps(tester.getRect(find.text('Follow the compass'))),
      isFalse,
    );
    tester.view.physicalSize = const Size(844, 390);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Your trail and journal'));
    await frames(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close journal'));
    await frames(tester);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('cloud choices use an in-game card and preserve movement focus', (
    tester,
  ) async {
    final world = WorldState();
    world.x = world.map.friend.x;
    world.y = world.map.friend.y;
    await tester.pumpWidget(
      WondertailApp(
          startInGame: true,
          saves: SaveRepository(_Store()),
          loaded: LoadResult(world)),
    );
    await frames(tester);
    await tester.tap(find.text('Meet Pip'));
    await frames(tester);
    expect(find.text('Pip, the lost cloud'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.text('Open the crystal'));
    await frames(tester);
    expect(world.progress.stage, 1);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
    final before = world.x;
    await frames(tester);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
    expect(world.x, greaterThan(before));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('skyway opens a generated island and journal can revisit', (
    tester,
  ) async {
    final world = WorldState(
      highestUnlocked: 1,
      progress: IslandProgress(stage: 3, collected: 7, puzzleCleared: true),
    );
    world.x = world.map.gate.x;
    world.y = world.map.gate.y;
    await tester.pumpWidget(
      WondertailApp(
          startInGame: true,
          saves: SaveRepository(_Store()),
          loaded: LoadResult(world)),
    );
    await frames(tester);
    await tester.tap(find.text('Next adventure'));
    await frames(tester);
    await tester.tap(find.text('Sail to island 2'));
    await frames(tester);
    expect(world.islandIndex, 1);
    expect(world.progress.stage, 0);
    await tester.tap(find.byTooltip('Your trail and journal'));
    await frames(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('visit-island-0')));
    await tester.tap(find.byKey(const ValueKey('visit-island-0')));
    await frames(tester);
    expect(world.islandIndex, 0);
    expect(world.progress.complete, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  test('static drawing and HUD updates remain bounded during movement', () {
    final world = WorldState();
    world.progress.coins = 4095;
    world.progress.gathered = 63;
    final game = WondertailGame(state: world, onWorldChanged: (_) {});
    game.onGameResize(Vector2(390, 844));
    game.inputX = 1;
    for (var i = 0; i < 120; i++) {
      game.update(1 / 60);
      final recorder = ui.PictureRecorder();
      game.render(Canvas(recorder));
      recorder.endRecording().dispose();
    }
    expect(game.terrainBuildCount, 1);
    expect(game.hudUpdateCount, lessThan(30));
    expect(game.revision.value, 0);
    game.onRemove();
  });
}
