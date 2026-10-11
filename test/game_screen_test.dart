import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wondertail/data/save_repository.dart';
import 'package:wondertail/domain/world_state.dart';
import 'package:wondertail/main.dart';

class _Store implements SaveStore {
  final Map<String, String> data = {};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async {
    data[key] = value;
  }
}

void main() {
  testWidgets('phone layout, keyboard movement and journal pause work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final world = WorldState();
    await tester.pumpWidget(
      WondertailApp(saves: SaveRepository(_Store()), loaded: LoadResult(world)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Little Drift'), findsOneWidget);
    expect(find.text('Follow your compass'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
    expect(world.x, greaterThan(370));
    await tester.tap(find.byTooltip('Your journal (J)'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Your little book of wonders'), findsOneWidget);
    final x = world.x;
    await tester.pump(const Duration(seconds: 1));
    expect(world.x, x);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Back to the island'));
    await tester.pump(const Duration(milliseconds: 300));
    tester.view.physicalSize = const Size(320, 640);
    await tester.pump();
    final moveRight = tester.getRect(find.byIcon(Icons.keyboard_arrow_right));
    final action = tester.getRect(find.ancestor(
      of: find.text('Follow your compass'),
      matching: find.byWidgetPredicate((widget) => widget is FilledButton),
    ));
    expect(moveRight.overlaps(action), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cloud encounter allows curiosity followed by rescue', (
    tester,
  ) async {
    final world = WorldState(x: 540, y: 340);
    await tester.pumpWidget(
      WondertailApp(saves: SaveRepository(_Store()), loaded: LoadResult(world)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Meet the cloud'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Listen first'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(world.studiedCrystal, isTrue);
    expect(world.cloudRescued, isFalse);
    await tester.tap(find.text('Meet the cloud'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Open the crystal'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(world.cloudRescued, isTrue);
    expect(find.text('Talk to Pip'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
