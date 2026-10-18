import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../domain/world_state.dart';

class IslandPalette {
  const IslandPalette(
    this.sky,
    this.horizon,
    this.grass,
    this.light,
    this.leaf,
    this.accent,
    this.ink,
  );
  final Color sky, horizon, grass, light, leaf, accent, ink;
  static IslandPalette forBiome(Biome biome) => switch (biome) {
        Biome.meadow => const IslandPalette(
            Color(0xffb6dcd5),
            Color(0xffedf0d3),
            Color(0xff94bd85),
            Color(0xffb2d49b),
            Color(0xff468d70),
            Color(0xffffdc86),
            Color(0xff466850),
          ),
        Biome.twilight => const IslandPalette(
            Color(0xff414b78),
            Color(0xffb6adc3),
            Color(0xff969db8),
            Color(0xffb9bad0),
            Color(0xff77749e),
            Color(0xffffdba7),
            Color(0xff505574),
          ),
        Biome.coral => const IslandPalette(
            Color(0xffa2cfda),
            Color(0xfff4debd),
            Color(0xffdcb88d),
            Color(0xffefd0a6),
            Color(0xffc98382),
            Color(0xffb5eee0),
            Color(0xff8c625d),
          ),
      };
}

class _Spark {
  _Spark(this.x, this.y, this.vx, this.vy, this.life, this.color);
  double x, y, vx, vy, life;
  final Color color;
}

/// One cached static scene; only character, companion, pickups and small effects
/// animate. Flutter HUD notifiers change on events/contact, never per frame.
class WondertailGame extends FlameGame {
  WondertailGame(
      {required this.state, required this.onWorldChanged, this.onSound});
  final void Function(String cue)? onSound;
  double _soundCooldown = 0;
  bool _nearPickup = false;
  final WorldState state;
  final void Function(String message) onWorldChanged;
  final ValueNotifier<int> revision = ValueNotifier(0);
  final ValueNotifier<Encounter?> interaction = ValueNotifier(null);
  final ValueNotifier<double> compassAngle = ValueNotifier(0);
  double inputX = 0, inputY = 0;
  bool sprint = false;
  bool controlsEnabled = true;
  bool movedSinceSave = false;
  bool calmMotion = false;
  int terrainBuildCount = 0;
  int hudUpdateCount = 0;
  ui.Picture? _terrain;
  int _terrainKey = -1;
  double _time = 0, _compassTime = 0, _arrivalFlash = 1;
  late double _cameraX = state.x;
  late double _cameraY = state.y;
  final List<_Spark> _sparks = [];
  Paint? _skyPaint;
  double _skyWidth = 0, _skyHeight = 0;

  void clearInput() {
    inputX = 0;
    inputY = 0;
    sprint = false;
  }

  void refresh({bool arrival = false}) {
    revision.value++;
    interaction.value = WorldRules.nearby(state);
    if (arrival) {
      _cameraX = state.x;
      _cameraY = state.y;
      _arrivalFlash = 1;
      _skyPaint = null;
      _sparks.clear();
    }
  }

  void burst(Point2 point, Color color) {
    if (calmMotion) return;
    for (var i = 0; i < 14 && _sparks.length < 42; i++) {
      final angle = i * math.pi * 2 / 14;
      _sparks.add(
        _Spark(
          point.x,
          point.y - 15,
          math.cos(angle) * 60,
          math.sin(angle) * 60 - 30,
          0.8,
          color,
        ),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final step = dt.clamp(0.0, 0.15);
    _time += step;
    _soundCooldown = math.max(0, _soundCooldown - step);
    _arrivalFlash = math.max(0, _arrivalFlash - step * 1.4);
    for (var i = _sparks.length - 1; i >= 0; i--) {
      final p = _sparks[i];
      p.life -= step;
      if (p.life <= 0) {
        _sparks.removeAt(i);
        continue;
      }
      p.x += p.vx * step;
      p.y += p.vy * step;
      p.vy += step * 45;
    }
    if (!controlsEnabled) return;
    if (WorldRules.move(state, inputX, inputY, step, sprint: sprint)) {
      movedSinceSave = true;
    }
    final smoothing = calmMotion ? 1.0 : 1 - math.exp(-12 * step);
    _cameraX += (state.x - _cameraX) * smoothing;
    _cameraY += (state.y - _cameraY) * smoothing;
    if (WorldRules.advance(state, step)) {
      refresh();
      burst(state.map.wonder, const Color(0xffffe59c));
      onWorldChanged('Pip’s rain woke the trees. Find three glowing sunseeds!');
    }
    final nearPickup = [
      for (var i = 0; i < state.map.coins.length; i++)
        if ((state.progress.coins & (1 << i)) == 0) state.map.coins[i],
      if (WorldRules.itemsActive(state))
        for (var i = 0; i < 3; i++)
          if ((state.progress.collected & (1 << i)) == 0)
            state.map.collectibles[i],
    ].any((point) => point.distanceTo(state.position) < 80);
    if (nearPickup && !_nearPickup && _soundCooldown <= 0) {
      onSound?.call('near');
      _soundCooldown = 3;
    }
    _nearPickup = nearPickup;
    final coins = WorldRules.collectCoins(state);
    if (coins > 0) {
      onSound?.call('coin');
      burst(state.position, const Color(0xffffce5c));
      refresh();
      onWorldChanged(state.progress.coinCount == 12
          ? '12 coins! Your explorer scarf now shines on this island.'
          : '+$coins sky coin · ${state.progress.coinCount}/12');
    }
    final collected = WorldRules.collect(state);
    if (collected.isNotEmpty) {
      for (final index in collected) {
        burst(state.map.collectibles[index], const Color(0xffffeaa2));
      }
      refresh();
      onWorldChanged(
        state.progress.count == 3
            ? 'All three found! Your compass knows where to go.'
            : '+1 ${state.map.collectibleName} · ${state.progress.count}/3',
      );
    }
    final nearby = WorldRules.nearby(state);
    if (interaction.value != nearby) {
      interaction.value = nearby;
      if (nearby != null && _soundCooldown <= 0) {
        onSound?.call('near');
        _soundCooldown = 3;
      }
      hudUpdateCount++;
    }
    _compassTime += step;
    if (_compassTime >= 0.12) {
      _compassTime = 0;
      final target = WorldRules.target(state);
      final angle =
          math.atan2(target.y - state.y, target.x - state.x) + math.pi / 2;
      if ((angle - compassAngle.value).abs() > 0.04) {
        compassAngle.value = angle;
        hudUpdateCount++;
      }
    }
  }

  @override
  Color backgroundColor() => const Color(0xffb6dcd5);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (size.x <= 0 || size.y <= 0) return;
    final palette = IslandPalette.forBiome(state.map.biome);
    if (_skyPaint == null || _skyWidth != size.x || _skyHeight != size.y) {
      _skyWidth = size.x;
      _skyHeight = size.y;
      _skyPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.sky, palette.horizon],
        ).createShader(Rect.fromLTWH(0, 0, size.x, size.y));
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), _skyPaint!);
    for (var i = 0; i < 5; i++) {
      final x =
          (i * 271.0 + (calmMotion ? 0 : _time * 4)) % (size.x + 220) - 110;
      _cloud(
        canvas,
        Offset(x, 65.0 + (i * 131) % math.max(100, size.y.toInt())),
        1.4,
        const Color(0x22ffffff),
        face: false,
      );
    }
    for (var i = 0; i < 3; i++) {
      final x = size.x * (0.15 + i * 0.36);
      final y = size.y * (0.33 + (i % 2) * 0.15);
      canvas.drawPath(
          Path()
            ..moveTo(x - 44, y)
            ..lineTo(x + 48, y)
            ..lineTo(x + 10, y + 53)
            ..close(),
          _paint(const Color(0x44758c91)));
      canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 97, height: 28),
          _paint(const Color(0x6692b6a3)));
    }
    final zoom = size.x > size.y ? (size.y / 530).clamp(0.58, 0.9) : 0.72;
    canvas.save();
    canvas.translate(size.x / 2, size.y * 0.52);
    canvas.scale(zoom);
    canvas.translate(-_cameraX, -_cameraY);
    final key = state.islandIndex * 32 +
        state.progress.stage * 8 +
        (state.map.adventure == Adventure.garden
            ? state.progress.collected
            : 0);
    if (_terrainKey != key || _terrain == null) {
      _terrain?.dispose();
      final recorder = ui.PictureRecorder();
      _drawTerrain(Canvas(recorder), palette);
      _terrain = recorder.endRecording();
      _terrainKey = key;
      terrainBuildCount++;
    }
    canvas.drawPicture(_terrain!);
    _drawCoins(canvas);
    final target = WorldRules.target(state);
    final pulse = calmMotion ? 0.0 : math.sin(_time * 3) * 5;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(target.x, target.y),
            width: 70 + pulse,
            height: 34 + pulse),
        _paint(const Color(0xffffd16b))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    _star(canvas, Offset(target.x, target.y - 100 - pulse), 11,
        const Color(0xffffdf83));
    _drawPickups(canvas, palette);
    _drawFriend(canvas, palette);
    if (state.progress.complete) _gateGlow(canvas, palette);
    final nearby = interaction.value;
    if (nearby != null) {
      final point = switch (nearby) {
        Encounter.friend => state.map.friend,
        Encounter.wonder => state.map.wonder,
        Encounter.gate => state.map.gate,
        _ => state.map.collectibles[WorldRules.bedIndex(nearby)!],
      };
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(point.x, point.y + 5),
          width: 93,
          height: 39,
        ),
        _paint(const Color(0xbbfff3b8))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }
    _player(canvas);
    for (final p in _sparks) {
      canvas.drawCircle(Offset(p.x, p.y), 3 * (p.life / 0.8), _paint(p.color));
    }
    canvas.restore();
    if (_arrivalFlash > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        _paint(Color.fromRGBO(245, 241, 219, _arrivalFlash * 0.45)),
      );
    }
  }

  Paint _paint(Color color) => Paint()..color = color;
  Path _islandPath(double rx, double ry, double drop) {
    final path = Path();
    for (var i = 0; i <= 80; i++) {
      final angle = i * math.pi * 2 / 80;
      final wobble = math.sin(angle * 7) * 4 + math.cos(angle * 5) * 3;
      final x = 640 + math.cos(angle) * (rx + wobble);
      final y = 480 + drop + math.sin(angle) * (ry + wobble);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }

  void _drawTerrain(Canvas canvas, IslandPalette p) {
    canvas.drawOval(
      const Rect.fromLTWH(219, 252, 870, 680),
      _paint(const Color(0x14708881)),
    );
    canvas.drawPath(_islandPath(444, 330, 49), _paint(const Color(0xff8c8b86)));
    canvas.drawPath(_islandPath(444, 330, 32), _paint(const Color(0xffc2ad90)));
    canvas.drawPath(_islandPath(444, 330, 14), _paint(const Color(0xffe0cba3)));
    canvas.drawPath(_islandPath(440, 330, 0), _paint(p.grass));
    canvas.drawPath(_islandPath(426, 316, -3), _paint(p.light));
    for (final route in state.map.trails) {
      final trail = Path()..moveTo(route.first.x, route.first.y);
      for (final point in route.skip(1)) {
        trail.lineTo(point.x, point.y);
      }
      canvas.drawPath(
          trail,
          _paint(const Color(0xff9b9b68))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 42
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round);
      canvas.drawPath(
          trail,
          _paint(const Color(0xffead6a4))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 33
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round);
      for (var i = 2; i < route.length; i += 4) {
        final point = route[i];
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(point.x, point.y), width: 12, height: 7),
            _paint(const Color(0xffd0bc8c)));
      }
    }
    // Waterfall and layered cliff strata give the island a visible silhouette.
    canvas.drawPath(
        Path()
          ..moveTo(680, 785)
          ..lineTo(724, 782)
          ..lineTo(718, 902)
          ..quadraticBezierTo(697, 924, 683, 901)
          ..close(),
        _paint(const Color(0xff78cbd1)));
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(Offset(688 + i * 8.0, 795), Offset(688 + i * 8.0, 890),
          _paint(const Color(0x99e5ffff))..strokeWidth = 2);
    }
    for (var i = 0; i < state.map.flowers.length; i++) {
      final point = state.map.flowers[i];
      final color = i % 4 == 0 ? p.accent : const Color(0xffeff5d3);
      canvas.drawLine(
        Offset(point.x, point.y),
        Offset(point.x + 1, point.y - 6),
        _paint(p.leaf)..strokeWidth = 1.4,
      );
      canvas.drawCircle(
        Offset(point.x + 1, point.y - 8),
        i % 4 == 0 ? 3 : 2,
        _paint(color),
      );
      if (i % 9 == 0) {
        canvas.drawCircle(
          Offset(point.x + 5, point.y - 5),
          2,
          _paint(p.accent),
        );
      }
    }
    for (final obstacle in state.map.obstacles) {
      final point = obstacle.center;
      final radius = obstacle.radius;
      if (obstacle.pond) {
        canvas.drawCircle(
          Offset(point.x, point.y),
          radius + 6,
          _paint(const Color(0xff86a990)),
        );
        canvas.drawCircle(
          Offset(point.x, point.y),
          radius,
          _paint(const Color(0xff69adb5)),
        );
        canvas.drawArc(
          Rect.fromCircle(
            center: Offset(point.x - 4, point.y - 5),
            radius: radius * 0.65,
          ),
          0.2,
          2.2,
          false,
          _paint(const Color(0xffb0ded6))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(point.x - 14, point.y + 10),
            width: 21,
            height: 12,
          ),
          _paint(const Color(0xff7baf72)),
        );
      } else {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(point.x + 3, point.y + 8),
            width: radius * 2.3,
            height: radius * 1.7,
          ),
          _paint(const Color(0x22716e68)),
        );
        canvas.drawCircle(
          Offset(point.x, point.y - 5),
          radius,
          _paint(const Color(0xff99a5a2)),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(point.x - 4, point.y - radius * 0.55),
            width: radius * 1.4,
            height: radius * 0.7,
          ),
          _paint(const Color(0xffc0cbc2)),
        );
        canvas.drawCircle(
          Offset(point.x + radius * 0.45, point.y - 3),
          radius * 0.38,
          _paint(p.leaf),
        );
      }
    }
    for (var i = 0; i < state.map.trees.length; i++) {
      final tree = state.map.trees[i];
      _tree(
        canvas,
        tree.x,
        tree.y,
        p.leaf,
        0.65 + (i % 4) * 0.1,
        p.accent,
        blossom: state.progress.complete,
      );
    }
    _wonder(canvas, p);
    _gate(canvas, p);
    for (var i = 0; i < 3; i++) {
      final point = state.map.collectibles[i];
      if (state.map.adventure == Adventure.garden) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(point.x, point.y),
            width: 59,
            height: 38,
          ),
          _paint(const Color(0xffb19170)),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(point.x, point.y - 2),
            width: 47,
            height: 29,
          ),
          _paint(const Color(0xff907b61)),
        );
        if ((state.progress.collected & (1 << i)) != 0) {
          _tree(
            canvas,
            point.x,
            point.y,
            p.leaf,
            0.68,
            p.accent,
            blossom: true,
          );
        }
      } else if (state.map.adventure == Adventure.lantern) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(point.x, point.y + 3),
            width: 46,
            height: 30,
          ),
          _paint(const Color(0xffb3adbf)),
        );
        _label(canvas, Offset(point.x, point.y + 24), '${i + 1}', p.ink);
      }
    }
    _label(
      canvas,
      Offset(state.map.friend.x, state.map.friend.y + 36),
      state.map.friendName.toUpperCase(),
      p.ink,
    );
    _label(
      canvas,
      Offset(state.map.wonder.x, state.map.wonder.y + 60),
      state.map.wonderName.toUpperCase(),
      p.ink,
    );
    _label(
      canvas,
      Offset(state.map.gate.x, state.map.gate.y + 45),
      state.progress.complete ? 'THE NEXT ADVENTURE' : 'A SLEEPING SKYWAY',
      p.ink,
    );
    // The arrival campsite remains a visual anchor when revisiting.
    final tent = Path()
      ..moveTo(325, 566)
      ..lineTo(351, 518)
      ..lineTo(379, 566)
      ..close();
    canvas.drawPath(tent, _paint(const Color(0xffedbc76)));
    canvas.drawPath(
      Path()
        ..moveTo(339, 566)
        ..lineTo(351, 537)
        ..lineTo(364, 566)
        ..close(),
      _paint(const Color(0xff967658)),
    );
    canvas.drawLine(
      const Offset(325, 566),
      const Offset(379, 566),
      _paint(const Color(0xff9c795c))..strokeWidth = 3,
    );
  }

  void _tree(
    Canvas canvas,
    double x,
    double y,
    Color color,
    double scale,
    Color blossomColor, {
    bool blossom = false,
  }) {
    canvas.save();
    canvas.translate(x, y);
    canvas.scale(scale);
    canvas.drawOval(
      const Rect.fromLTWH(-33, -4, 66, 20),
      _paint(const Color(0x22728e60)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-5, -49, 10, 55),
        const Radius.circular(4),
      ),
      _paint(const Color(0xff937858)),
    );
    if (state.map.biome == Biome.twilight) {
      for (var tier = 0; tier < 3; tier++) {
        final y = -24.0 - tier * 22;
        final width = 39.0 - tier * 7;
        canvas.drawPath(
            Path()
              ..moveTo(-width, y)
              ..lineTo(0, y - 46)
              ..lineTo(width, y)
              ..quadraticBezierTo(0, y + 11, -width, y)
              ..close(),
            _paint(tier.isEven ? color : const Color(0xff9292b8)));
      }
    } else if (state.map.biome == Biome.coral) {
      for (final side in [-1.0, 1.0]) {
        canvas.drawPath(
            Path()
              ..moveTo(0, -22)
              ..quadraticBezierTo(side * 37, -25, side * 32, -66),
            _paint(color)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 13
              ..strokeCap = StrokeCap.round);
        canvas.drawCircle(
            Offset(side * 32, -67), 16, _paint(const Color(0xffe6a3a0)));
      }
      canvas.drawOval(const Rect.fromLTWH(-22, -101, 44, 55), _paint(color));
      canvas.drawOval(const Rect.fromLTWH(-18, -96, 25, 30),
          _paint(const Color(0xfff2b9a4)));
    } else {
      canvas.drawCircle(const Offset(-15, -49), 27, _paint(color));
      canvas.drawCircle(const Offset(16, -49), 30, _paint(color));
      canvas.drawCircle(const Offset(0, -72), 32, _paint(color));
      canvas.drawCircle(
          const Offset(-10, -82), 18, _paint(const Color(0x337effab)));
    }
    for (var i = 0; i < 9; i++) {
      final angle = i * 2.4;
      final leaf = Offset(math.cos(angle) * 27, -62 + math.sin(angle) * 27);
      canvas.drawOval(Rect.fromCenter(center: leaf, width: 16, height: 9),
          _paint(i.isEven ? const Color(0x337fffad) : const Color(0x22405050)));
    }
    canvas.drawLine(const Offset(-2, -5), const Offset(-2, -42),
        _paint(const Color(0xffc4a16c))..strokeWidth = 2);
    for (final x in [-19.0, 22.0]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, -3, 3, 10), const Radius.circular(2)),
          _paint(const Color(0xfff0d6a0)));
      canvas.drawOval(
          Rect.fromCenter(center: Offset(x + 1, -3), width: 13, height: 8),
          _paint(blossomColor));
    }
    if (blossom) {
      for (final point in [
        const Offset(-20, -57),
        const Offset(13, -74),
        const Offset(28, -43),
        const Offset(-6, -91),
      ]) {
        canvas.drawCircle(point, 5, _paint(blossomColor));
        canvas.drawCircle(point, 2, _paint(const Color(0xfffff2d4)));
      }
    }
    canvas.restore();
  }

  void _wonder(Canvas canvas, IslandPalette p) {
    final point = state.map.wonder;
    final awake = state.progress.stage >= 2 || state.progress.complete;
    canvas.save();
    canvas.translate(point.x, point.y);
    canvas.drawOval(
      const Rect.fromLTWH(-50, -9, 100, 41),
      _paint(const Color(0xffa49e7e)),
    );
    canvas.drawOval(
      const Rect.fromLTWH(-43, -13, 86, 34),
      _paint(const Color(0xffc6c09c)),
    );
    if (state.map.adventure == Adventure.lantern) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-7, -89, 14, 92),
          const Radius.circular(4),
        ),
        _paint(const Color(0xff847b91)),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-28, -117, 56, 51),
          const Radius.circular(15),
        ),
        _paint(
          state.progress.complete
              ? const Color(0xffffe799)
              : const Color(0xffbbb4c4),
        ),
      );
      canvas.drawLine(
        const Offset(-32, -115),
        const Offset(32, -115),
        _paint(const Color(0xff806c87))..strokeWidth = 6,
      );
      canvas.drawLine(
        const Offset(-32, -68),
        const Offset(32, -68),
        _paint(const Color(0xff806c87))..strokeWidth = 6,
      );
      if (state.progress.complete) {
        for (var i = 0; i < 6; i++) {
          _star(
            canvas,
            Offset(math.cos(i * 1.05) * 55, -90 + math.sin(i * 1.05) * 42),
            4,
            p.accent,
          );
        }
      }
    } else if (awake) {
      _tree(canvas, -23, 5, p.leaf, 0.86, p.accent, blossom: true);
      _tree(canvas, 30, 10, p.leaf, 0.64, p.accent, blossom: true);
      canvas.drawOval(
        const Rect.fromLTWH(-12, 12, 24, 16),
        _paint(const Color(0xffd59b62)),
      );
    } else {
      for (final x in [-22.0, 19.0]) {
        canvas.drawLine(
          Offset(x, 4),
          Offset(x, -48),
          _paint(const Color(0xffab8e77))
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(
          Offset(x, -22),
          Offset(x - 16, -36),
          _paint(const Color(0xffab8e77))
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    canvas.restore();
  }

  void _gate(Canvas canvas, IslandPalette p) {
    final point = state.map.gate;
    canvas.save();
    canvas.translate(point.x, point.y);
    canvas.drawOval(
      const Rect.fromLTWH(-56, -4, 112, 33),
      _paint(const Color(0xff9da890)),
    );
    canvas.drawOval(
      const Rect.fromLTWH(-47, -9, 94, 27),
      _paint(const Color(0xffe6d4ad)),
    );
    final arch = Path()
      ..moveTo(-35, 1)
      ..lineTo(-35, -57)
      ..cubicTo(-35, -112, 35, -112, 35, -57)
      ..lineTo(35, 1);
    canvas.drawPath(
      arch,
      _paint(state.progress.complete ? p.leaf : const Color(0xffa1a394))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < 5; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(i.isEven ? -36 : 36, -i * 16.0),
          width: 22,
          height: 12,
        ),
        _paint(p.leaf),
      );
    }
    _star(
      canvas,
      const Offset(0, -101),
      9,
      state.progress.complete ? p.accent : const Color(0xffcfceae),
    );
    canvas.restore();
  }

  void _gateGlow(Canvas canvas, IslandPalette p) {
    final point = state.map.gate;
    final rect = Rect.fromCenter(
      center: Offset(point.x, point.y - 42),
      width: 57,
      height: 88,
    );
    canvas.drawOval(rect, _paint(const Color(0x7783e7dc)));
    for (var i = 0; i < 7; i++) {
      final t = calmMotion ? i / 7 : (i / 7 + _time * 0.17) % 1;
      _star(
        canvas,
        Offset(point.x + math.sin(i * 5 + t * 4) * 18, point.y - t * 80),
        3,
        const Color(0xfffff3bc),
      );
    }
  }

  void _drawPickups(Canvas canvas, IslandPalette p) {
    if (!WorldRules.itemsActive(state)) return;
    for (var i = 0; i < 3; i++) {
      if ((state.progress.collected & (1 << i)) != 0) continue;
      final point = state.map.collectibles[i];
      final bob = calmMotion ? 0.0 : math.sin(_time * 2.8 + i) * 4;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(point.x, point.y + 3),
          width: 24,
          height: 10,
        ),
        _paint(const Color(0x33837661)),
      );
      final active =
          state.map.adventure != Adventure.lantern || i == state.progress.count;
      canvas.drawCircle(
        Offset(point.x, point.y - 15 + bob),
        active ? 23 : 15,
        _paint(active ? const Color(0x88fff3b4) : const Color(0x228a99b6)),
      );
      if (state.map.adventure == Adventure.garden) {
        _star(
          canvas,
          Offset(point.x, point.y - 22 + bob),
          9,
          const Color(0xffffe9ad),
        );
      } else {
        _star(
          canvas,
          Offset(point.x, point.y - 17 + bob),
          12,
          const Color(0xffffe68b),
        );
        canvas.drawCircle(
          Offset(point.x, point.y - 17 + bob),
          4,
          _paint(const Color(0xfffffff0)),
        );
      }
    }
  }

  void _drawFriend(Canvas canvas, IslandPalette p) {
    final map = state.map;
    if (map.adventure == Adventure.rain) {
      if (state.progress.stage == 0) {
        final point = map.friend;
        final crystal = Path()
          ..moveTo(point.x, point.y - 85)
          ..lineTo(point.x + 36, point.y - 51)
          ..lineTo(point.x + 29, point.y + 5)
          ..lineTo(point.x, point.y + 16)
          ..lineTo(point.x - 30, point.y + 1)
          ..lineTo(point.x - 35, point.y - 51)
          ..close();
        canvas.drawPath(crystal, _paint(const Color(0xaa9bdcd1)));
        _cloud(
          canvas,
          Offset(point.x, point.y - 31),
          0.5,
          const Color(0xfff8fff2),
        );
        canvas.drawPath(
          crystal,
          _paint(const Color(0xfff6fff1))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        _star(canvas, Offset(point.x + 44, point.y - 56), 6, p.accent);
      } else {
        final rain = state.progress.stage == 1;
        final x = rain ? map.wonder.x : state.x + 45;
        final y = rain ? map.wonder.y - 104 : state.y - 57;
        _cloud(
          canvas,
          Offset(x, y + (calmMotion ? 0 : math.sin(_time * 2) * 3)),
          0.7,
          const Color(0xfffcfff4),
        );
        if (rain) {
          for (var i = 0; i < 15; i++) {
            final rx = x - 45 + i * 29 % 90;
            final ry = y + 18 + (i * 17 + _time * 150) % 100;
            canvas.drawLine(
              Offset(rx, ry),
              Offset(rx - 3, ry + 10),
              _paint(const Color(0xaa529fbd))..strokeWidth = 2,
            );
          }
        }
      }
    } else {
      final point = state.progress.stage > 0
          ? Point2(state.x + 40, state.y - 18)
          : map.friend;
      canvas.save();
      canvas.translate(point.x, point.y);
      if (map.adventure == Adventure.lantern) {
        final wing = calmMotion ? 1.0 : 0.8 + math.sin(_time * 8).abs() * 0.2;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(-15 * wing, -25),
            width: 35 * wing,
            height: 36,
          ),
          _paint(const Color(0xfff5dcae)),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(15 * wing, -25),
            width: 35 * wing,
            height: 36,
          ),
          _paint(const Color(0xffe9bfd6)),
        );
        canvas.drawOval(
          const Rect.fromLTWH(-8, -42, 16, 39),
          _paint(const Color(0xff8f788e)),
        );
        canvas.drawCircle(
          const Offset(0, -29),
          10,
          _paint(const Color(0xfffcdfad)),
        );
        _face(canvas, const Offset(0, -30), 0.65);
      } else {
        canvas.drawOval(
          const Rect.fromLTWH(-25, -2, 50, 16),
          _paint(const Color(0x33738c63)),
        );
        for (final x in [-16.0, 15.0]) {
          canvas.drawOval(
            Rect.fromCenter(center: Offset(x, -3), width: 14, height: 15),
            _paint(const Color(0xff7fac88)),
          );
        }
        canvas.drawOval(
          const Rect.fromLTWH(-25, -35, 48, 36),
          _paint(const Color(0xff91aa70)),
        );
        canvas.drawOval(
          const Rect.fromLTWH(-18, -34, 32, 26),
          _paint(const Color(0xffc0ce81)),
        );
        canvas.drawCircle(
          const Offset(23, -18),
          13,
          _paint(const Color(0xffa4c894)),
        );
        _face(canvas, const Offset(25, -20), 0.55);
        if (state.progress.complete) {
          _star(canvas, const Offset(-3, -43), 9, const Color(0xffffd58f));
        }
      }
      canvas.restore();
    }
  }

  void _drawCoins(Canvas canvas) {
    for (var i = 0; i < state.map.coins.length; i++) {
      if ((state.progress.coins & (1 << i)) != 0) continue;
      final point = state.map.coins[i];
      final bob = calmMotion ? 0.0 : math.sin(_time * 3 + i) * 3;
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(point.x, point.y + 4), width: 21, height: 8),
          _paint(const Color(0x33745c28)));
      canvas.drawCircle(Offset(point.x, point.y - 12 + bob), 10,
          _paint(const Color(0xffae6e2a)));
      canvas.drawCircle(Offset(point.x - 1, point.y - 14 + bob), 9,
          _paint(const Color(0xffffd568)));
      _star(canvas, Offset(point.x - 1, point.y - 14 + bob), 5,
          const Color(0xfffff4ba));
    }
  }

  void _player(Canvas canvas) {
    final moving = (inputX != 0 || inputY != 0) && controlsEnabled;
    final bounce = moving && !calmMotion ? math.sin(_time * 15) * 2 : 0.0;
    canvas.save();
    canvas.translate(state.x, state.y);
    canvas.drawOval(
      const Rect.fromLTWH(-16, -3, 32, 12),
      _paint(const Color(0x33718965)),
    );
    canvas.translate(0, bounce);
    if (state.progress.coinCount == 12) {
      canvas.drawPath(
          Path()
            ..moveTo(-10, -30)
            ..quadraticBezierTo(-27, -40, -35, -24)
            ..lineTo(-23, -20)
            ..lineTo(-7, -25)
            ..close(),
          _paint(const Color(0xffffd15b)));
    }
    final step = moving && !calmMotion ? math.sin(_time * 15) * 3 : 0.0;
    for (final (x, y) in [(-10.0, step), (3.0, -step)]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, -9 + y, 8, 13),
          const Radius.circular(3),
        ),
        _paint(const Color(0xff59616a)),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-16, -35, 32, 30),
        const Radius.circular(11),
      ),
      _paint(const Color(0xffdc9264)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-20, -31, 12, 24),
        const Radius.circular(5),
      ),
      _paint(const Color(0xffa57b55)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-19, -31, 10, 7),
        const Radius.circular(3),
      ),
      _paint(const Color(0xffddb57a)),
    );
    canvas.drawCircle(
      const Offset(0, -42),
      14,
      _paint(const Color(0xffedc29e)),
    );
    canvas.drawArc(
      const Rect.fromLTWH(-14, -59, 28, 28),
      math.pi,
      math.pi,
      true,
      _paint(const Color(0xff685451)),
    );
    canvas.drawOval(
      const Rect.fromLTWH(-24, -59, 48, 14),
      _paint(const Color(0xffeed390)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-15, -74, 30, 22),
        const Radius.circular(10),
      ),
      _paint(const Color(0xfff4dd9d)),
    );
    canvas.drawLine(
      const Offset(-14, -55),
      const Offset(14, -55),
      _paint(const Color(0xffb98c61))..strokeWidth = 4,
    );
    canvas.drawCircle(
      Offset(inputX < 0 ? -6 : 6, -42),
      1.8,
      _paint(const Color(0xff4c5357)),
    );
    canvas.drawCircle(
      const Offset(10, -22),
      4,
      _paint(const Color(0xffffed9d)),
    );
    canvas.drawLine(
      const Offset(9, -8),
      const Offset(18, -7),
      _paint(const Color(0xfff4d793))..strokeWidth = 4,
    );
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
    canvas.drawOval(const Rect.fromLTWH(-42, -7, 84, 34), _paint(color));
    canvas.drawCircle(const Offset(-22, -5), 22, _paint(color));
    canvas.drawCircle(const Offset(2, -17), 28, _paint(color));
    canvas.drawCircle(const Offset(25, -2), 20, _paint(color));
    if (face) _face(canvas, const Offset(0, 3), 1);
    canvas.restore();
  }

  void _face(Canvas canvas, Offset point, double scale) {
    for (final dx in [-9.0, 9.0]) {
      canvas.drawCircle(
        point + Offset(dx * scale, 0),
        2.2 * scale,
        _paint(const Color(0xff526c6d)),
      );
    }
    canvas.drawArc(
      Rect.fromCenter(
        center: point + Offset(0, 5 * scale),
        width: 10 * scale,
        height: 8 * scale,
      ),
      0,
      math.pi,
      false,
      _paint(const Color(0xff526c6d))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    for (final dx in [-16.0, 16.0]) {
      canvas.drawCircle(
        point + Offset(dx * scale, 7 * scale),
        3.4 * scale,
        _paint(const Color(0xffedc4bb)),
      );
    }
  }

  void _star(Canvas canvas, Offset point, double radius, Color color) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 - math.pi / 2;
      final r = i.isEven ? radius : radius * 0.38;
      final x = point.dx + math.cos(angle) * r,
          y = point.dy + math.sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path..close(), _paint(color));
  }

  void _label(Canvas canvas, Offset point, String text, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontFamily: 'sans-serif',
          fontSize: 10,
          letterSpacing: 1.3,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, point - Offset(painter.width / 2, 0));
  }

  @override
  void onRemove() {
    _terrain?.dispose();
    _terrain = null;
    super.onRemove();
  }
}
