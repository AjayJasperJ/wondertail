import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wondertail/domain/world_state.dart';
import 'package:wondertail/ui/puzzles/puzzle_screen.dart';

void main() {
  testWidgets('maze board responds to legal neighboring taps at phone size',
      (tester) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final p = GatewayPuzzle(4271, 1);
    await tester.pumpWidget(MaterialApp(home: PuzzleScreen(puzzle: p)));
    final rect = tester.getRect(find.byKey(const ValueKey('puzzle-board')));
    expect(rect.width, greaterThan(200));
    expect(rect.height, greaterThan(200));
    final parents = <int, int>{0: -1}, queue = <int>[0];
    for (var i = 0; i < queue.length; i++) {
      final a = queue[i];
      for (final e in p.mazeEdges) {
        final x = e ~/ 100,
            y = e % 100,
            b = x == a
                ? y
                : y == a
                    ? x
                    : -1;
        if (b >= 0 && !parents.containsKey(b)) {
          parents[b] = a;
          queue.add(b);
        }
      }
    }
    final route = <int>[];
    for (var n = 24; n != 0; n = parents[n]!) {
      route.add(n);
    }
    for (final n in route.reversed) {
      await tester.tapAt(rect.topLeft +
          Offset(
              (n % 5 + .5) * rect.width / 5, (n ~/ 5 + .5) * rect.height / 5));
      await tester.pump();
      expect(p.mazeCell, n);
    }
    expect(p.solved, isTrue);
    expect(find.text('Open the skyway'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('color regions cycle and puzzle exit remains available',
      (tester) async {
    tester.view.physicalSize = const Size(740, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final p = GatewayPuzzle(4271, 2);
    await tester.pumpWidget(MaterialApp(home: PuzzleScreen(puzzle: p)));
    final rect = tester.getRect(find.byKey(const ValueKey('puzzle-board')));
    await tester.tapAt(rect.topLeft + Offset(rect.width / 6, rect.height / 6));
    await tester.pump();
    expect(p.colors[0], 0);
    expect(find.text('← Return to island'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
