import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/world_state.dart';

class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key, required this.puzzle});
  final GatewayPuzzle puzzle;
  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen>
    with WidgetsBindingObserver {
  Timer? timer;
  bool timed = false, active = true;
  int seconds = 90;
  GatewayPuzzle get p => widget.puzzle;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!timed || !active || p.solved || !mounted) return;
      setState(() {
        seconds--;
        if (seconds == 0) {
          p.mazeCell = 0;
          seconds = 90;
          timed = false;
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: const Color(0xff203c48),
      body: SafeArea(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
            width: 220,
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('← Return to island')),
                      Text(
                          [
                            'UNTIE THE ROPE',
                            'LOST-PATH MAZE',
                            'FOUR-COLOR MAP'
                          ][p.kind.index],
                          style: const TextStyle(
                              color: Color(0xffffdd94),
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(
                          switch (p.kind) {
                            PuzzleKind.rope =>
                              'Drag the six knots until no ropes cross. Keep knots apart.',
                            PuzzleKind.maze =>
                              'Tap a connected neighboring tile. Reach the gold exit at bottom right.',
                            PuzzleKind.coloring =>
                              'Tap each region to cycle four colors. Borders and marked diagonal links must use different colors.',
                          },
                          style: const TextStyle(
                              color: Colors.white, height: 1.5)),
                      if (p.kind == PuzzleKind.maze)
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                                timed
                                    ? '${seconds}s · optional timer'
                                    : 'Optional 90s timer',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12)),
                            value: timed,
                            onChanged: (v) => setState(() {
                                  timed = v;
                                  seconds = 90;
                                })),
                      const SizedBox(height: 12),
                      FilledButton(
                          onPressed: p.solved
                              ? () => Navigator.pop(context, true)
                              : null,
                          child: Text(
                              p.solved ? 'Open the skyway' : 'Solve to open')),
                    ])))),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: LayoutBuilder(
                    key: const ValueKey('puzzle-board'),
                    builder: (context, c) {
                      final size = Size(c.maxWidth, c.maxHeight);
                      return switch (p.kind) {
                        PuzzleKind.rope => Stack(children: [
                            Positioned.fill(
                                child: CustomPaint(painter: _PuzzlePainter(p))),
                            for (var i = 0; i < 6; i++)
                              Positioned(
                                  left: p.nodes[i].x * size.width - 18,
                                  top: p.nodes[i].y * size.height - 18,
                                  child: GestureDetector(
                                      onPanUpdate: (d) => setState(() {
                                            p.nodes[i] = Point2(
                                                (p.nodes[i].x +
                                                        d.delta.dx / size.width)
                                                    .clamp(.06, .94),
                                                (p.nodes[i].y +
                                                        d.delta.dy /
                                                            size.height)
                                                    .clamp(.06, .94));
                                          }),
                                      child: CircleAvatar(
                                          radius: 18,
                                          backgroundColor:
                                              const Color(0xffffd18a),
                                          child: Text('${i + 1}')))),
                          ]),
                        PuzzleKind.maze => CustomPaint(
                            painter: _PuzzlePainter(p),
                            child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (d) => setState(() {
                                      final x =
                                          (d.localPosition.dx / size.width * 5)
                                              .floor()
                                              .clamp(0, 4);
                                      final y =
                                          (d.localPosition.dy / size.height * 5)
                                              .floor()
                                              .clamp(0, 4);
                                      p.mazeMove(y * 5 + x);
                                    }))),
                        PuzzleKind.coloring => Stack(children: [
                            Positioned.fill(
                                child: GridView.count(
                                    crossAxisCount: 3,
                                    childAspectRatio: size.width / size.height,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    children: [
                                  for (var i = 0; i < 9; i++)
                                    GestureDetector(
                                        onTap: () => setState(() {
                                              p.colors[i] =
                                                  (p.colors[i] + 1) % 4;
                                            }),
                                        child: Container(
                                            margin: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                                color: p.colors[i] < 0
                                                    ? const Color(0xff607783)
                                                    : _colors[p.colors[i]],
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                            child: Center(
                                                child: Text('${i + 1}',
                                                    style: const TextStyle(
                                                        fontSize: 24))))),
                                ])),
                            Positioned.fill(
                                child: IgnorePointer(
                                    child: CustomPaint(
                                        painter: _PuzzlePainter(p)))),
                          ]),
                      };
                    }))),
      ])));
}

const _colors = [
  Color(0xffe59e84),
  Color(0xff78bfb4),
  Color(0xffd9bc71),
  Color(0xffa394d3)
];

class _PuzzlePainter extends CustomPainter {
  _PuzzlePainter(this.p);
  final GatewayPuzzle p;
  @override
  void paint(Canvas canvas, Size s) {
    final paint = Paint()
      ..color = const Color(0xffffdf9e)
      ..strokeWidth = 4;
    if (p.kind == PuzzleKind.rope) {
      for (var i = 0; i < 6; i++) {
        final a = p.nodes[i], b = p.nodes[(i + 1) % 6];
        canvas.drawLine(Offset(a.x * s.width, a.y * s.height),
            Offset(b.x * s.width, b.y * s.height), paint);
      }
    } else if (p.kind == PuzzleKind.maze) {
      final w = s.width / 5, h = s.height / 5;
      for (var i = 0; i < 25; i++) {
        final x = (i % 5) * w, y = (i ~/ 5) * h;
        paint.color = const Color(0xffa8c3c0);
        paint.strokeWidth = 3;
        if (i % 5 == 0) canvas.drawLine(Offset(x, y), Offset(x, y + h), paint);
        if (i < 5) canvas.drawLine(Offset(x, y), Offset(x + w, y), paint);
        if (i % 5 == 4 || !p.mazeEdges.contains(GatewayPuzzle.edge(i, i + 1))) {
          canvas.drawLine(Offset(x + w, y), Offset(x + w, y + h), paint);
        }
        if (i >= 20 || !p.mazeEdges.contains(GatewayPuzzle.edge(i, i + 5))) {
          canvas.drawLine(Offset(x, y + h), Offset(x + w, y + h), paint);
        }
        if (i == 24 || i == p.mazeCell) {
          paint.color = i == p.mazeCell
              ? const Color(0xff83ddd1)
              : const Color(0xffffd47e);
          canvas.drawCircle(
              Offset(x + w / 2, y + h / 2), w < h ? w * .25 : h * .25, paint);
        }
      }
    } else {
      for (final e in p.borders) {
        final a = e ~/ 100, b = e % 100;
        if (b - a != 4) continue;
        paint.color = const Color(0xff203c48);
        paint.strokeWidth = 7;
        final x =
            Offset((a % 3 + .75) * s.width / 3, (a ~/ 3 + .75) * s.height / 3);
        final y =
            Offset((b % 3 + .25) * s.width / 3, (b ~/ 3 + .25) * s.height / 3);
        canvas.drawLine(x, y, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PuzzlePainter oldDelegate) => true;
}
