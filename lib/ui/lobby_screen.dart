import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/save_repository.dart';
import '../domain/world_state.dart';
import 'game_screen.dart';

const _cream = Color(0xfffff3d5);
const _night = Color(0xff183e49);
const _gold = Color(0xffedc573);
const explorerNames = ['Rowan', 'Sky', 'Fern'];
const explorerColors = [
  Color(0xffdc9264),
  Color(0xff659dbb),
  Color(0xff8fa76a)
];

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key, required this.saves, required this.loaded});
  final SaveRepository saves;
  final LoadResult loaded;
  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  late final WorldState world = widget.loaded.state;
  late int selected = world.islandIndex;
  int tab = 0, page = 0;
  bool busy = false;
  String? error;

  Future<void> persist() async {
    try {
      await widget.saves.save(world);
      if (mounted) setState(() => error = null);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not save. Tap Retry before leaving.');
      }
    }
  }

  Future<void> launch() async {
    if (busy || selected > world.highestUnlocked) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.saves.save(world);
      if (selected != world.islandIndex) {
        final memory = await widget.saves.loadIsland(selected);
        world.travel(selected, memory);
        await widget.saves.save(world);
      }
      if (!mounted) return;
      await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) =>
            GameScreen(saves: widget.saves, loaded: LoadResult(world)),
      ));
      if (!mounted) return;
      setState(() {
        selected = world.islandIndex;
        busy = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Your trail could not be saved. Please retry.';
        });
      }
    }
  }

  Future<void> launchRun() async {
    if (busy || world.highestUnlocked < 3) return;
    setState(() => busy = true);
    try {
      world.profile.runsStarted++;
      await widget.saves.save(world);
      final expedition = WorldState(
          seed: (world.seed + world.profile.runsStarted * 7919) & 0x7fffffff,
          islandIndex: 3,
          highestUnlocked: 3,
          highestVisited: 3,
          character: world.character,
          sound: world.sound,
          calm: world.calm,
          guide: world.guide,
          profile: world.profile,
          run: TrailRun());
      if (!mounted) return;
      await Navigator.of(context).push<void>(MaterialPageRoute(
          builder: (_) =>
              GameScreen(saves: widget.saves, loaded: LoadResult(expedition))));
      await widget.saves.save(world);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not save the expedition. Please retry.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _night,
        body: DecoratedBox(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff183e49), Color(0xff376e72), Color(0xff639388)],
          )),
          child: SafeArea(
              child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.explore_rounded, color: _gold, size: 28),
                const SizedBox(width: 10),
                const Text('WONDERTAIL',
                    style: TextStyle(
                        color: _cream,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2)),
                const Spacer(),
                Text('✦ ${world.profile.coins}  ◈ ${world.profile.cores}',
                    style: const TextStyle(color: _cream, fontSize: 11)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                      child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: TextButton(
                      key: ValueKey('lobby-tab-$i'),
                      onPressed: busy
                          ? null
                          : () => setState(() {
                                tab = i;
                                if (i == 3) page = (selected ~/ 6) * 6;
                              }),
                      style: TextButton.styleFrom(
                        foregroundColor: tab == i ? _night : _cream,
                        backgroundColor:
                            tab == i ? _gold : const Color(0x22365052),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: Text(
                          ['Adventure', 'Explorers', 'Settings', 'Islands'][i],
                          style: const TextStyle(fontSize: 12)),
                    ),
                  )),
              ]),
              const SizedBox(height: 10),
              Expanded(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Expanded(
                        flex: 4,
                        child: Column(children: [
                          Expanded(
                              child: CustomPaint(
                                  painter: ExplorerPainter(world.character),
                                  child: const SizedBox.expand())),
                          Text(explorerNames[world.character],
                              style: const TextStyle(
                                  color: _cream,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800)),
                          const Text('YOUR EXPLORER',
                              style: TextStyle(
                                  color: _gold, fontSize: 9, letterSpacing: 2)),
                          const SizedBox(height: 8),
                          SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                key: const ValueKey('start-adventure'),
                                onPressed: busy ? null : launch,
                                style: FilledButton.styleFrom(
                                    backgroundColor: _gold,
                                    foregroundColor: _night),
                                icon: Icon(busy
                                    ? Icons.hourglass_top
                                    : Icons.play_arrow_rounded),
                                label: Text(busy
                                    ? 'Opening…'
                                    : 'Play island ${selected + 1}'),
                              )),
                        ])),
                    const SizedBox(width: 18),
                    Expanded(
                        flex: 6,
                        child: Container(
                          decoration: BoxDecoration(
                              color: const Color(0xf5fff3d5),
                              borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.all(15),
                          child: SingleChildScrollView(
                              key: ValueKey('lobby-content-$tab'),
                              child: switch (tab) {
                                1 => explorers(),
                                2 => settings(),
                                3 => islands(),
                                4 => workshop(),
                                5 => trailblazer(),
                                _ => adventure(),
                              }),
                        )),
                  ])),
              if (error != null)
                Row(children: [
                  Expanded(
                      child: Text(error!,
                          style: const TextStyle(color: _cream, fontSize: 11))),
                  TextButton(
                      onPressed: persist,
                      child:
                          const Text('Retry', style: TextStyle(color: _gold))),
                ]),
            ]),
          )),
        ),
      );

  Widget heading(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 20, color: _night, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 12, height: 1.4, color: Color(0xff597577))),
          const SizedBox(height: 12),
        ],
      );

  Widget adventure() {
    final map = IslandMap.generate(world.seed, selected);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      heading(
          map.name, 'Island ${selected + 1} · ${map.landform} · ${map.title}'),
      SizedBox(
          height: 120,
          width: double.infinity,
          child: CustomPaint(painter: IslandPreviewPainter(map))),
      const SizedBox(height: 8),
      const Text('A world worth wandering',
          style: TextStyle(color: _night, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      const Text(
          'Visit Scout Wren’s lodge. Explore a crystal chamber beneath the mountains. Restore an ancient sky archive.',
          style:
              TextStyle(fontSize: 12, height: 1.45, color: Color(0xff597577))),
      const SizedBox(height: 10),
      Text('Main adventure: ${map.title}',
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: _night)),
      const SizedBox(height: 8),
      Text('${map.condition} · ${map.conditionHint}',
          style: const TextStyle(fontSize: 12, color: _night)),
      const SizedBox(height: 12),
      FilledButton.icon(
          key: const ValueKey('open-workshop'),
          onPressed: busy ? null : () => setState(() => tab = 4),
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Loom & Workshop')),
      OutlinedButton.icon(
          key: const ValueKey('open-trailblazer'),
          onPressed: busy ? null : () => setState(() => tab = 5),
          icon: const Icon(Icons.route),
          label: const Text('Trailblazer Runs')),
      if (widget.loaded.notice != null)
        Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(widget.loaded.notice!,
                style:
                    const TextStyle(fontSize: 11, color: Color(0xff597577)))),
    ]);
  }

  Widget explorers() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        heading('Choose your explorer',
            'Rowan: balanced. Sky: taller, faster, higher jumps. Fern: broader, slower, stronger attacks. Switching keeps your progress.'),
        for (var i = 0; i < 3; i++)
          Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                key: ValueKey('choose-character-$i'),
                onTap: busy
                    ? null
                    : () {
                        setState(() => world.character = i);
                        persist();
                      },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: world.character == i
                          ? const Color(0xffe3d6aa)
                          : const Color(0xffefe7ce),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: world.character == i
                              ? const Color(0xff608b7c)
                              : Colors.transparent)),
                  child: Row(children: [
                    SizedBox(
                        width: 48,
                        height: 60,
                        child: CustomPaint(painter: ExplorerPainter(i))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(explorerNames[i],
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, color: _night)),
                          Text(
                              [
                                'The trail wanderer',
                                'The stargazer',
                                'The forest friend'
                              ][i],
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xff597577))),
                        ])),
                    if (world.character == i)
                      const Icon(Icons.check_circle, color: Color(0xff477d78)),
                  ]),
                ),
              )),
      ]);

  Widget workshop() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        heading('Loom & Workshop',
            '✦ ${world.profile.coins} Starlight · ◈ ${world.profile.cores} cores · ${world.profile.seeds} skyseeds\nUnlocks last across all islands on this device.'),
        const Text(
            'Every 12-coin collection earns one core. Restored archives widen coin pickup range (up to 52) and reveal caches.',
            style: TextStyle(fontSize: 11, color: _night)),
        for (final item in WorkshopItem.values)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, color: _night)),
                    Text(item.description,
                        style: const TextStyle(fontSize: 11, color: _night)),
                    TextButton(
                        key: ValueKey('workshop-${item.index}'),
                        onPressed: busy
                            ? null
                            : world.profile.owns(item)
                                ? () {
                                    setState(() => world.profile.equip(item));
                                    persist();
                                  }
                                : item == WorkshopItem.runnerCape ||
                                        world.profile.coins < item.coins ||
                                        world.profile.cores < item.cores
                                    ? null
                                    : () {
                                        setState(
                                            () => world.profile.purchase(item));
                                        persist();
                                      },
                        child: Text(world.profile.owns(item)
                            ? 'Equip / toggle'
                            : item == WorkshopItem.runnerCape
                                ? 'Finish Trailblazer to earn'
                                : 'Unlock · ${item.coins} Starlight + ${item.cores} cores')),
                  ])),
        TextButton(
            onPressed: () {
              setState(() {
                world.profile.cape = 0;
                world.profile.trail = false;
                world.profile.hat = false;
              });
              persist();
            },
            child: const Text('Unequip accessories')),
        const Divider(),
        const Text('COMPANION BONDS',
            style: TextStyle(color: _night, fontWeight: FontWeight.w800)),
        for (final creature in Adventure.values)
          Text(
              '${[
                'Pip',
                'Luma',
                'Moss'
              ][creature.index]} · Rank ${world.profile.rank(creature)}/3 · ${world.profile.bonds[creature.index]} kindness\n'
              '${[
                'Rain gifts bonus Starlight at rank 2.',
                'Rank 2 lights twilight mist and reveals caches.',
                'Rank 2 uncovers seed caches.'
              ][creature.index]}',
              style: const TextStyle(fontSize: 11, height: 1.5, color: _night)),
        const Text(
            'Earn kindness by restoring a main wonder and giving one skyseed favor per island. Rank 2 needs 2 kindness; rank 3 needs 4.',
            style: TextStyle(fontSize: 11, height: 1.5, color: _night)),
      ]);

  Widget trailblazer() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        heading('Trailblazer Runs',
            'Optional three-island expeditions. Your normal world stays safe.'),
        const Text(
            'Restore three wonders within 7 minutes of active play. Menus and background time pause the clock. Each attempt uses a new seed and island conditions.\n\nFirst victory earns the permanent Trailblazer Cape, 24 Starlight, and 2 cores. Later victories improve your best time; normal pickups are not banked during a run. Leaving or restarting ends an unfinished run.',
            style: TextStyle(fontSize: 12, height: 1.5, color: _night)),
        if (world.profile.bestRunMillis > 0)
          Text(
              'Best: ${(world.profile.bestRunMillis / 1000).toStringAsFixed(1)} seconds',
              style: const TextStyle(color: _night)),
        const SizedBox(height: 12),
        FilledButton(
            key: const ValueKey('start-trailblazer'),
            onPressed: busy || world.highestUnlocked < 3 ? null : launchRun,
            child: Text(world.highestUnlocked < 3
                ? 'Restore 3 islands to unlock'
                : 'Start 3-island run')),
      ]);

  Widget settings() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        heading('Make yourself at home',
            'Preferences save on this device. Android audio starts when you move.'),
        SwitchListTile(
            key: const ValueKey('music-setting'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Music & sounds', style: TextStyle(fontSize: 14)),
            value: world.sound,
            onChanged: (value) {
              setState(() => world.sound = value);
              persist();
            }),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Calm motion', style: TextStyle(fontSize: 14)),
            subtitle: const Text('Reduce particles, bobbing and camera easing',
                style: TextStyle(fontSize: 10)),
            value: world.calm,
            onChanged: (value) {
              setState(() => world.calm = value);
              persist();
            }),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Glowing objective marker',
                style: TextStyle(fontSize: 14)),
            value: world.guide,
            onChanged: (value) {
              setState(() => world.guide = value);
              persist();
            }),
        const Text(
            'Landscape play · offline saves · no ads\nWeb audio is not available in this build.',
            style:
                TextStyle(fontSize: 11, height: 1.5, color: Color(0xff597577))),
      ]);

  Widget islands() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        heading('Your island atlas',
            'Replay unlocked islands. Restore the main wonder to open the next island.'),
        for (var index = page;
            index < math.min(page + 6, world.highestUnlocked + 2);
            index++)
          Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: ListTile(
                key: ValueKey('select-island-$index'),
                dense: true,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                tileColor: selected == index
                    ? const Color(0xffdfd4af)
                    : const Color(0xffeee7d0),
                leading: Icon(
                    index > world.highestUnlocked
                        ? Icons.lock_outline
                        : Icons.landscape,
                    color: const Color(0xff477d78)),
                title: Text(
                    'Island ${index + 1} · ${IslandMap.generate(world.seed, index).name}',
                    style: const TextStyle(fontSize: 12)),
                subtitle: Text(
                    index > world.highestUnlocked
                        ? 'Restore island $index to unlock'
                        : IslandMap.generate(world.seed, index).landform,
                    style: const TextStyle(fontSize: 10)),
                trailing: selected == index
                    ? const Icon(Icons.check, size: 18)
                    : null,
                onTap: index > world.highestUnlocked || busy
                    ? null
                    : () => setState(() => selected = index),
              )),
        Row(children: [
          TextButton(
              onPressed: page == 0 ? null : () => setState(() => page -= 6),
              child: const Text('Previous')),
          const Spacer(),
          TextButton(
              onPressed: page + 6 > world.highestUnlocked + 1
                  ? null
                  : () => setState(() => page += 6),
              child: const Text('Next')),
        ]),
      ]);
}

class ExplorerPainter extends CustomPainter {
  ExplorerPainter(this.character);
  final int character;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 150, size.height / 160);
    canvas.save();
    canvas.translate(size.width / 2, size.height * 0.94);
    canvas.scale(scale);
    final paint = Paint();
    canvas.drawOval(const Rect.fromLTWH(-42, -9, 84, 16),
        paint..color = const Color(0x33506f68));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-23, -38, 19, 36), const Radius.circular(7)),
        paint..color = _night);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(5, -38, 19, 36), const Radius.circular(7)),
        paint..color = _night);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-31, -88, 62, 63), const Radius.circular(18)),
        paint..color = explorerColors[character]);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-45, -83, 19, 49), const Radius.circular(7)),
        paint..color = const Color(0xff9d7958));
    canvas.drawCircle(
        const Offset(0, -104), 26, paint..color = const Color(0xffedbd98));
    canvas.drawArc(const Rect.fromLTWH(-27, -135, 54, 50), math.pi, math.pi,
        true, paint..color = const Color(0xff5e4948));
    canvas.drawOval(const Rect.fromLTWH(-40, -134, 80, 18),
        paint..color = character == 0 ? _gold : explorerColors[character]);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-25, -154, 50, 29), const Radius.circular(12)),
        paint..color = character == 0 ? _cream : explorerColors[character]);
    for (final x in [-9.0, 9.0]) {
      canvas.drawCircle(Offset(x, -105), 2.8, paint..color = _night);
    }
    canvas.drawArc(
        const Rect.fromLTWH(-7, -102, 14, 10),
        0,
        math.pi,
        false,
        paint
          ..color = _night
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(21, -57), 12, paint..color = _gold);
    canvas.drawCircle(const Offset(21, -57), 7, paint..color = _cream);
    canvas.restore();
  }

  @override
  bool shouldRepaint(ExplorerPainter oldDelegate) =>
      oldDelegate.character != character;
}

class IslandPreviewPainter extends CustomPainter {
  IslandPreviewPainter(this.map);
  final IslandMap map;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(math.min(size.width / 1450, size.height / 1100));
    canvas.translate(-640, -480);
    final path = Path();
    for (var i = 0; i <= 80; i++) {
      final point = map.shorePoint(i * math.pi * 2 / 80);
      if (i == 0) {
        path.moveTo(point.x, point.y);
      } else {
        path.lineTo(point.x, point.y);
      }
    }
    final paint = Paint()..color = const Color(0xff719e85);
    canvas.drawPath(path..close(), paint);
    final cave = map.cave;
    canvas.drawPath(
        Path()
          ..moveTo(cave.x - 90, cave.y)
          ..lineTo(cave.x, cave.y - 180)
          ..lineTo(cave.x + 90, cave.y)
          ..close(),
        paint..color = const Color(0xff496575));
    canvas.drawCircle(
        Offset(map.arrival.x, map.arrival.y), 24, paint..color = _gold);
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(map.lodge.x, map.lodge.y), width: 60, height: 55),
        paint..color = const Color(0xffd6b07c));
    canvas.restore();
  }

  @override
  bool shouldRepaint(IslandPreviewPainter oldDelegate) =>
      oldDelegate.map.index != map.index || oldDelegate.map.name != map.name;
}
