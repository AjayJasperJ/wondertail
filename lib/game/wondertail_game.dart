import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../domain/world_state.dart';

/// A deliberately small canvas renderer on Flame's lifecycle/game loop.
/// The authored map and its collision rules live in the pure Dart domain layer.
class WondertailGame extends FlameGame {
  WondertailGame({required this.state, required this.onWorldChanged});
  final WorldState state;
  final VoidCallback onWorldChanged;
  double inputX = 0;
  double inputY = 0;
  bool controlsEnabled = true;
  double _time = 0;
  double _notifyTime = 0;
  late final List<(double, double)> _flowers = IslandMap.flowers(state.seed);

  void clearInput() {
    inputX = 0;
    inputY = 0;
  }

  @override
  Color backgroundColor() => const Color(0xffd8eae2);

  @override
  void update(double dt) {
    super.update(dt);
    final step = dt.clamp(0.0, 0.05);
    _time += step;
    if (!controlsEnabled) return;
    final moved = WorldRules.move(state, inputX, inputY, step);
    final changed = WorldRules.advanceRain(state, step);
    _notifyTime += step;
    if (changed || (moved && _notifyTime >= 0.1)) {
      _notifyTime = 0;
      onWorldChanged();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (size.x <= 0 || size.y <= 0) return;
    final screen = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(
      screen,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xffd2e7e1), Color(0xfff4eed6)],
        ).createShader(screen),
    );
    for (var i = 0; i < 7; i++) {
      final x = (i * 233.0 + _time * 5) % (size.x + 180) - 90;
      final y = 55.0 + (i * 113) % math.max(120, size.y.toInt());
      _cloud(
        canvas,
        Offset(x, y),
        0.7 + (i % 3) * 0.2,
        const Color(0x66ffffff),
        face: false,
      );
    }
    final zoom = size.x < 600 ? 0.90 : 1.12;
    canvas.save();
    canvas.translate(size.x / 2, size.y * 0.50);
    canvas.scale(zoom);
    canvas.translate(-state.x, -state.y);
    _island(canvas, const Rect.fromLTWH(100, 195, 750, 570), false);
    _island(canvas, const Rect.fromLTWH(925, 120, 310, 260), true);
    if (state.bridgeGrown) _bridge(canvas);
    _path(canvas);
    for (var i = 0; i < _flowers.length; i++) {
      final (x, y) = _flowers[i];
      canvas.drawLine(
        Offset(x, y),
        Offset(x + 1, y - 6),
        _paint(const Color(0xff7b9d66))..strokeWidth = 2,
      );
      canvas.drawCircle(
        Offset(x + 1, y - 7),
        2.6,
        _paint(i % 3 == 0 ? const Color(0xffffe8a5) : const Color(0xfff5fcdf)),
      );
    }
    _pond(canvas);
    for (final (x, y, radius) in IslandMap.rocks) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y + 5),
          width: radius * 2.3,
          height: radius * 1.7,
        ),
        _paint(const Color(0x2271835e)),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y - 4),
          width: radius * 2,
          height: radius * 1.6,
        ),
        _paint(const Color(0xff9da994)),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x - 7, y - 12),
          width: radius,
          height: radius * 0.5,
        ),
        _paint(const Color(0xffc0cab1)),
      );
    }
    _tree(canvas, 225, 455, const Color(0xff79996b), 1.0);
    _tree(canvas, 440, 255, const Color(0xff91aa72), 0.8);
    _tree(canvas, 590, 710, const Color(0xff87a06b), 0.9);
    _grove(canvas);
    _crystal(canvas);
    _seedHollow(canvas);
    _lookout(canvas);
    final nearby = WorldRules.nearby(state);
    if (nearby != null) {
      final mark = switch (nearby) {
        Encounter.cloud => IslandMap.cloud,
        Encounter.grove => IslandMap.grove,
        Encounter.bridge => IslandMap.bridge,
        Encounter.lookout => IslandMap.lookout,
      };
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(mark.x, mark.y + 12),
          width: 95,
          height: 42,
        ),
        _paint(const Color(0xbbfff7bf))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    _player(canvas);
    if (state.cloudRescued) {
      final rain = !state.groveGrown;
      final x = rain ? IslandMap.grove.x : state.x + 43;
      final y = rain ? IslandMap.grove.y - 110 : state.y - 56;
      _cloud(
        canvas,
        Offset(x, y + math.sin(_time * 2) * 4),
        0.72,
        const Color(0xfffbfff5),
      );
      if (rain) {
        for (var i = 0; i < 24; i++) {
          final rx = x - 55 + (i * 29 % 110);
          final ry = y + 20 + (i * 31 + _time * 170) % 100;
          canvas.drawLine(
            Offset(rx, ry),
            Offset(rx - 3, ry + 10),
            _paint(const Color(0xaa70ada9))..strokeWidth = 2,
          );
        }
      }
    }
    canvas.restore();
  }

  Paint _paint(Color color) => Paint()..color = color;

  void _island(Canvas canvas, Rect oval, bool small) {
    canvas.drawOval(
      oval.shift(const Offset(10, 55)),
      _paint(const Color(0x14708881)),
    );
    canvas.drawOval(
      oval.shift(const Offset(0, 25)),
      _paint(const Color(0xff958d72)),
    );
    canvas.drawOval(
      oval.shift(const Offset(0, 13)),
      _paint(const Color(0xffbaa77c)),
    );
    canvas.drawOval(
      oval,
      _paint(small ? const Color(0xffbdd0a0) : const Color(0xffbfd29c)),
    );
    canvas.drawOval(
      oval.deflate(13),
      _paint(small ? const Color(0xffcedbb0) : const Color(0xffcfdbac)),
    );
  }

  void _path(Canvas canvas) {
    final trail = Path()
      ..moveTo(370, 485)
      ..quadraticBezierTo(510, 510, 540, 340);
    final toGrove = Path()
      ..moveTo(480, 465)
      ..quadraticBezierTo(580, 490, 640, 590);
    final toBridge = Path()
      ..moveTo(555, 420)
      ..quadraticBezierTo(675, 410, 795, 350);
    for (final path in [trail, toGrove, toBridge]) {
      canvas.drawPath(
        path,
        _paint(const Color(0xffe2d9af))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 28
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _pond(Canvas canvas) {
    canvas.drawOval(
      const Rect.fromLTWH(245, 566, 130, 88),
      _paint(const Color(0xffa8b78a)),
    );
    canvas.drawOval(
      const Rect.fromLTWH(256, 575, 108, 68),
      _paint(const Color(0xff8abdb8)),
    );
    canvas.drawArc(
      const Rect.fromLTWH(274, 590, 65, 29),
      0,
      math.pi,
      false,
      _paint(const Color(0xffc4e0cb))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawOval(
      const Rect.fromLTWH(265, 605, 22, 12),
      _paint(const Color(0xff759e6f)),
    );
  }

  void _tree(Canvas canvas, double x, double y, Color color, double scale) {
    canvas.save();
    canvas.translate(x, y);
    canvas.scale(scale);
    canvas.drawOval(
      const Rect.fromLTWH(-32, -4, 64, 20),
      _paint(const Color(0x22728e60)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-5, -48, 10, 55),
        const Radius.circular(4),
      ),
      _paint(const Color(0xffa58c69)),
    );
    canvas.drawCircle(const Offset(-15, -47), 27, _paint(color));
    canvas.drawCircle(const Offset(15, -48), 30, _paint(color));
    canvas.drawCircle(const Offset(0, -69), 31, _paint(color));
    canvas.drawCircle(
      const Offset(-8, -76),
      18,
      _paint(const Color(0x229bce8a)),
    );
    canvas.restore();
  }

  void _grove(Canvas canvas) {
    final grown = state.groveGrown;
    for (final (x, y) in [(605.0, 605.0), (686.0, 591.0), (655.0, 641.0)]) {
      if (grown) {
        _tree(canvas, x, y, const Color(0xff77a876), 0.65);
      } else {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, y - 34),
          _paint(const Color(0xffa89777))
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(
          Offset(x, y - 16),
          Offset(x - 12, y - 28),
          _paint(const Color(0xffa89777))
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    if (grown && !state.seedCollected) _seed(canvas, const Offset(640, 563), 1);
    _label(
      canvas,
      Offset(640, 667),
      grown ? 'THE GRATEFUL GROVE' : 'THE SLEEPY GROVE',
    );
  }

  void _crystal(Canvas canvas) {
    canvas.save();
    canvas.translate(540, 340);
    canvas.drawOval(
      const Rect.fromLTWH(-39, -4, 78, 28),
      _paint(const Color(0xffb0be95)),
    );
    if (!state.cloudRescued) {
      final crystal = Path()
        ..moveTo(0, -73)
        ..lineTo(32, -42)
        ..lineTo(28, 2)
        ..lineTo(0, 15)
        ..lineTo(-30, -2)
        ..lineTo(-29, -45)
        ..close();
      canvas.drawPath(crystal, _paint(const Color(0xffa9d7ce)));
      _cloud(canvas, const Offset(0, -27), 0.48, const Color(0xfff7fff6));
      canvas.drawPath(
        crystal,
        _paint(const Color(0xfff3fff0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      canvas.drawLine(
        const Offset(0, -73),
        const Offset(-4, -6),
        _paint(const Color(0x88ffffff))..strokeWidth = 2,
      );
      _sparkle(canvas, Offset(43, -55 + math.sin(_time * 2) * 4), 6);
    } else {
      for (var i = 0; i < 5; i++) {
        canvas.drawCircle(
          Offset(-25.0 + i * 12, (i % 2) * 7.0),
          5,
          _paint(const Color(0xffb0ded0)),
        );
      }
    }
    _label(
      canvas,
      const Offset(0, 38),
      state.cloudRescued ? 'A NEW FRIEND' : 'A LITTLE MYSTERY',
    );
    canvas.restore();
  }

  void _seed(Canvas canvas, Offset point, double scale) {
    canvas.drawCircle(point, 18 * scale, _paint(const Color(0x55fff5b4)));
    canvas.drawOval(
      Rect.fromCenter(center: point, width: 12 * scale, height: 19 * scale),
      _paint(const Color(0xffe7b957)),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: point + Offset(7 * scale, -10 * scale),
        width: 13 * scale,
        height: 7 * scale,
      ),
      _paint(const Color(0xff65965c)),
    );
  }

  void _seedHollow(Canvas canvas) {
    canvas.drawOval(
      const Rect.fromLTWH(774, 339, 42, 25),
      _paint(const Color(0xffa88d63)),
    );
    canvas.drawOval(
      const Rect.fromLTWH(783, 345, 24, 12),
      _paint(const Color(0xff807d53)),
    );
    if (state.seedCollected && !state.bridgeGrown) {
      _sparkle(canvas, Offset(795, 324 + math.sin(_time * 3) * 3), 9);
    }
    _label(canvas, const Offset(789, 392), 'THE SEED HOLLOW');
  }

  void _bridge(Canvas canvas) {
    final path = Path()
      ..moveTo(795, 350)
      ..lineTo(975, 280);
    canvas.drawPath(
      path,
      _paint(const Color(0xff879c66))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 69
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      _paint(const Color(0xffb0c989))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 54
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < 12; i++) {
      final x = 800.0 + i * 15;
      final y = 348.0 - i * 5.85;
      canvas.drawLine(
        Offset(x - 6, y - 18),
        Offset(x + 8, y + 18),
        _paint(const Color(0xffd5dfa6))
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y - 29), width: 20, height: 11),
        _paint(const Color(0xff76a273)),
      );
    }
  }

  void _lookout(Canvas canvas) {
    _tree(canvas, 1170, 265, const Color(0xff8fac77), 0.8);
    canvas.drawOval(
      const Rect.fromLTWH(1035, 222, 70, 31),
      _paint(const Color(0xffadb58b)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(1066, 176, 8, 63),
        const Radius.circular(3),
      ),
      _paint(const Color(0xffa58b64)),
    );
    canvas.drawCircle(
      const Offset(1070, 172),
      24,
      _paint(const Color(0x55fff3aa)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(1057, 153, 26, 33),
        const Radius.circular(8),
      ),
      _paint(const Color(0xffffe9a0)),
    );
    canvas.drawLine(
      const Offset(1057, 156),
      const Offset(1083, 156),
      _paint(const Color(0xffb18b59))..strokeWidth = 3,
    );
    _label(canvas, const Offset(1070, 277), 'LANTERN LOOKOUT');
    if (state.lookoutReached) {
      for (var i = 0; i < 8; i++) {
        _sparkle(
          canvas,
          Offset(
            1070 + math.cos(i * 0.8 + _time * 0.3) * 62,
            195 + math.sin(i * 0.8 + _time * 0.3) * 55,
          ),
          3,
        );
      }
    }
  }

  void _player(Canvas canvas) {
    final moving = inputX != 0 || inputY != 0;
    final bounce =
        moving ? math.sin(_time * 14) * 1.7 : math.sin(_time * 2) * 0.6;
    canvas.save();
    canvas.translate(state.x, state.y);
    canvas.drawOval(
      const Rect.fromLTWH(-14, -4, 28, 11),
      _paint(const Color(0x33728965)),
    );
    canvas.translate(0, bounce);
    final step = moving ? math.sin(_time * 14) * 2.5 : 0.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-9, -7 + step, 7, 12),
        const Radius.circular(3),
      ),
      _paint(const Color(0xff655b4d)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2, -7 - step, 7, 12),
        const Radius.circular(3),
      ),
      _paint(const Color(0xff655b4d)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-15, -32, 30, 28),
        const Radius.circular(10),
      ),
      _paint(const Color(0xffca805d)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-19, -29, 10, 20),
        const Radius.circular(4),
      ),
      _paint(const Color(0xffae925b)),
    );
    canvas.drawCircle(
      const Offset(0, -39),
      13,
      _paint(const Color(0xffe8ba90)),
    );
    canvas.drawArc(
      const Rect.fromLTWH(-14, -54, 28, 28),
      math.pi,
      math.pi,
      true,
      _paint(const Color(0xff725a43)),
    );
    canvas.drawOval(
      const Rect.fromLTWH(-20, -53, 40, 12),
      _paint(const Color(0xffe4c579)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-13, -67, 26, 20),
        const Radius.circular(9),
      ),
      _paint(const Color(0xffecd495)),
    );
    canvas.drawCircle(
      Offset(inputX < 0 ? -6 : 5, -38),
      1.6,
      _paint(const Color(0xff514d41)),
    );
    canvas.drawCircle(const Offset(9, -18), 4, _paint(const Color(0xfff8dfa0)));
    canvas.restore();
  }

  void _cloud(
    Canvas canvas,
    Offset point,
    double scale,
    Color color, {
    bool face = true,
  }) {
    canvas.save();
    canvas.translate(point.dx, point.dy);
    canvas.scale(scale);
    final paint = _paint(color);
    canvas.drawOval(const Rect.fromLTWH(-42, -7, 84, 34), paint);
    canvas.drawCircle(const Offset(-22, -5), 22, paint);
    canvas.drawCircle(const Offset(2, -17), 28, paint);
    canvas.drawCircle(const Offset(25, -2), 20, paint);
    if (face) {
      canvas.drawCircle(
        const Offset(-9, 3),
        2.4,
        _paint(const Color(0xff58746b)),
      );
      canvas.drawCircle(
        const Offset(9, 3),
        2.4,
        _paint(const Color(0xff58746b)),
      );
      canvas.drawArc(
        const Rect.fromLTWH(-5, 5, 10, 8),
        0,
        math.pi,
        false,
        _paint(const Color(0xff58746b))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.7,
      );
      canvas.drawCircle(
        const Offset(-17, 10),
        4,
        _paint(const Color(0xffefd0b7)),
      );
      canvas.drawCircle(
        const Offset(17, 10),
        4,
        _paint(const Color(0xffefd0b7)),
      );
    }
    canvas.restore();
  }

  void _sparkle(Canvas canvas, Offset point, double radius) {
    canvas.drawLine(
      point - Offset(radius, 0),
      point + Offset(radius, 0),
      _paint(const Color(0xfffff6bd))
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      point - Offset(0, radius),
      point + Offset(0, radius),
      _paint(const Color(0xfffff6bd))
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _label(Canvas canvas, Offset point, String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xff64785c),
          fontFamily: 'sans-serif',
          fontSize: 10,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, point - Offset(painter.width / 2, 0));
  }
}
