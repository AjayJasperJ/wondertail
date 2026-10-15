import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/save_repository.dart';
import '../domain/world_state.dart';
import '../game/wondertail_game.dart';

const _ink = Color(0xff344f55);
const _paper = Color(0xfffff7df);
const _teal = Color(0xff477d78);

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.saves, required this.loaded});
  final SaveRepository saves;
  final LoadResult loaded;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final WorldState _world = widget.loaded.state;
  late final WondertailGame _game;
  final FocusNode _keyboard = FocusNode();
  final _stickKey = GlobalKey<_AnalogStickState>();
  final Set<LogicalKeyboardKey> _held = {};
  final ValueNotifier<String> _saveStatus = ValueNotifier(
    'Saved on this device',
  );
  final ValueNotifier<String?> _ribbon = ValueNotifier(null);
  Timer? _autosave, _ribbonTimer;
  String? _panel;
  Encounter? _encounter;
  bool _travelling = false, _retrySave = false;
  int _atlasPage = 0;
  double _touchX = 0, _touchY = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = WondertailGame(state: _world, onWorldChanged: _changed);
    _autosave = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_game.movedSinceSave || _retrySave) unawaited(_save());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showRibbon(
        widget.loaded.notice ??
            'Drag the compass stick to roam. Follow the golden arrow.',
      );
      unawaited(_save());
    });
  }

  void _changed(String message) {
    _showRibbon(message);
    unawaited(_save());
  }

  Future<void> _save() async {
    _game.movedSinceSave = false;
    try {
      await widget.saves.save(_world);
      _retrySave = false;
      if (mounted) _saveStatus.value = 'Saved on this device';
    } catch (_) {
      _retrySave = true;
      if (mounted) _saveStatus.value = 'Save needs a retry · tap here';
    }
  }

  void _showRibbon(String message) {
    if (!mounted) return;
    _ribbonTimer?.cancel();
    _ribbon.value = message;
    _ribbonTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) _ribbon.value = null;
    });
  }

  void _clearInput() {
    _held.clear();
    _touchX = 0;
    _touchY = 0;
    _game.clearInput();
    _stickKey.currentState?._release();
  }

  void _syncInput() {
    bool has(LogicalKeyboardKey a, LogicalKeyboardKey b) =>
        _held.contains(a) || _held.contains(b);
    final dx = (has(LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.keyD)
            ? 1.0
            : 0.0) -
        (has(LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.keyA)
            ? 1.0
            : 0.0);
    final dy = (has(LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.keyS)
            ? 1.0
            : 0.0) -
        (has(LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.keyW) ? 1.0 : 0.0);
    _game.inputX = dx == 0 ? _touchX : dx;
    _game.inputY = dy == 0 ? _touchY : dy;
    _game.sprint = _held.contains(LogicalKeyboardKey.shiftLeft) ||
        _held.contains(LogicalKeyboardKey.shiftRight);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape &&
        event is KeyDownEvent &&
        _panel != null) {
      _closePanel();
      return KeyEventResult.handled;
    }
    if (_panel != null || _travelling) return KeyEventResult.ignored;
    final movement = {
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.keyW,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyS,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
    };
    if (movement.contains(key)) {
      if (event is KeyUpEvent) {
        _held.remove(key);
      } else {
        _held.add(key);
      }
      _syncInput();
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.keyE || key == LogicalKeyboardKey.space) &&
        event is KeyDownEvent) {
      _interact();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyJ && event is KeyDownEvent) {
      _openJournal();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _clearInput();
      _game.controlsEnabled = false;
      _game.pauseEngine();
      unawaited(_save());
    } else {
      _game.controlsEnabled = _panel == null && !_travelling;
      _game.resumeEngine();
    }
  }

  void _closePanel() {
    if (_travelling) return;
    setState(() {
      _panel = null;
      _encounter = null;
    });
    _game.controlsEnabled = true;
    _keyboard.requestFocus();
  }

  void _openJournal() {
    if (_travelling) return;
    _clearInput();
    _game.controlsEnabled = false;
    setState(() {
      _panel = 'journal';
      _atlasPage = (_world.islandIndex ~/ 8) * 8;
    });
  }

  void _interact() {
    if (_panel != null || _travelling) return;
    final encounter = WorldRules.nearby(_world);
    if (encounter == null) return;
    final bed = WorldRules.bedIndex(encounter);
    if (bed != null) {
      if (WorldRules.act(_world, encounter)) {
        _game.burst(_world.map.collectibles[bed], const Color(0xffffd99c));
        _game.refresh();
        _changed(
          _world.progress.complete
              ? 'Three little gardens! Moss grew a new skyway for you.'
              : 'A little garden takes root · ${_world.progress.count}/3',
        );
      }
      return;
    }
    _clearInput();
    _game.controlsEnabled = false;
    setState(() {
      _panel = 'encounter';
      _encounter = encounter;
    });
  }

  Future<void> _travel(int index) async {
    if (_travelling || index == _world.islandIndex) return;
    _clearInput();
    _game.controlsEnabled = false;
    setState(() => _travelling = true);
    try {
      // Complete the old island checkpoint before loading another island.
      await widget.saves.save(_world);
      final memory = await widget.saves.loadIsland(index);
      if (!mounted) return;
      if (_world.travel(index, memory)) {
        _game.refresh(arrival: true);
        await _save();
      }
      if (!mounted) return;
      setState(() {
        _panel = null;
        _encounter = null;
        _travelling = false;
      });
      _game.controlsEnabled = true;
      _keyboard.requestFocus();
      _showRibbon(
        'Island ${index + 1} · ${_world.map.name} · ${_world.map.title}',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _travelling = false);
      _showRibbon('Your trail could not be saved yet. Try the skyway again.');
    }
  }

  void _perform() {
    final encounter = _encounter;
    if (encounter == null) return;
    if (encounter == Encounter.gate && _world.progress.complete) {
      unawaited(_travel(_world.islandIndex + 1));
      return;
    }
    if (WorldRules.act(_world, encounter)) {
      _game.burst(
        encounter == Encounter.friend ? _world.map.friend : _world.map.wonder,
        const Color(0xffffe29a),
      );
      _game.refresh();
      _closePanel();
      _changed(
        _world.progress.complete
            ? _world.map.consequence
            : WorldRules.objective(_world),
      );
    } else {
      _closePanel();
    }
  }

  String _actionLabel(Encounter? encounter) {
    if (encounter == null) return 'Follow the compass';
    if (WorldRules.bedIndex(encounter) != null) return 'Plant a little garden';
    return switch (encounter) {
      Encounter.friend => 'Meet ${_world.map.friendName}',
      Encounter.wonder =>
        _world.map.adventure == Adventure.garden && _world.progress.stage == 1
            ? 'Fill your watering can'
            : 'Explore the wonder',
      Encounter.gate =>
        _world.progress.complete ? 'Next adventure' : 'Inspect the skyway',
      _ => 'Explore',
    };
  }

  @override
  void dispose() {
    _autosave?.cancel();
    _ribbonTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.saves.save(_world).catchError((Object _) {}));
    _keyboard.dispose();
    _saveStatus.dispose();
    _ribbon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xffb6dcd5),
        body: Focus(
          focusNode: _keyboard,
          autofocus: true,
          onKeyEvent: _onKey,
          onFocusChange: (focused) {
            if (!focused) _clearInput();
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: GameWidget(game: _game, autofocus: false),
                ),
              ),
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 190,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x88edf1da), Color(0x00edf1da)],
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: ValueListenableBuilder<int>(
                  valueListenable: _game.revision,
                  builder: (context, _, child) => Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 14, 0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              color: Color(0xffa07a40),
                              size: 24,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'WONDERTAIL',
                                    style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 2.8,
                                      fontWeight: FontWeight.w800,
                                      color: _ink,
                                    ),
                                  ),
                                  Text(
                                    _world.map.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 23,
                                      height: 1.15,
                                      fontWeight: FontWeight.w800,
                                      color: _ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _RoundButton(
                              label: 'Your trail and journal',
                              icon: Icons.menu_book_rounded,
                              onTap: _openJournal,
                            ),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.topLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(15, 16, 15, 0),
                            child: _Parchment(
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xffeee2b9),
                                    ),
                                    child: ValueListenableBuilder<double>(
                                      valueListenable: _game.compassAngle,
                                      builder: (_, angle, child) =>
                                          Transform.rotate(
                                        angle: angle,
                                        child: child,
                                      ),
                                      child: const Icon(
                                        Icons.navigation_rounded,
                                        size: 25,
                                        color: Color(0xff8c8450),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'ISLAND ${_world.islandIndex + 1}  /  ${_world.map.title.toUpperCase()}',
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xff8e8d71),
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          WorldRules.objective(_world),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            height: 1.25,
                                            color: _ink,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            for (var i = 0; i < 3; i++)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 4,
                                                ),
                                                child: Icon(
                                                  (_world.progress.collected &
                                                              (1 << i)) !=
                                                          0
                                                      ? Icons.auto_awesome
                                                      : Icons.circle_outlined,
                                                  size: 13,
                                                  color: (_world.progress
                                                                  .collected &
                                                              (1 << i)) !=
                                                          0
                                                      ? const Color(
                                                          0xffc3974b,
                                                        )
                                                      : const Color(
                                                          0xffbeb79d,
                                                        ),
                                                ),
                                              ),
                                            Expanded(
                                              child: Text(
                                                '${_world.kindnessCount} islands restored',
                                                textAlign: TextAlign.right,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Color(0xff7d8d7b),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 177,
                child: SafeArea(
                  top: false,
                  child: IgnorePointer(
                    child: ValueListenableBuilder<String?>(
                      valueListenable: _ribbon,
                      builder: (_, text, __) => AnimatedOpacity(
                        opacity: text == null || _panel != null ? 0 : 1,
                        duration: const Duration(milliseconds: 200),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 470),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xee365b5e),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0x66e9d598),
                                ),
                              ),
                              child: Text(
                                text ?? '',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xfffff0cb),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_panel == null && !_travelling) ...[
                Positioned(
                  left: 15,
                  bottom: 35,
                  child: SafeArea(
                    top: false,
                    child: _AnalogStick(
                      key: _stickKey,
                      onChanged: (dx, dy) {
                        _touchX = dx;
                        _touchY = dy;
                        _syncInput();
                      },
                      onStart: () => _keyboard.requestFocus(),
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 46,
                  child: SafeArea(
                    top: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ValueListenableBuilder<int>(
                          valueListenable: _game.revision,
                          builder: (_, __, ___) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xddfff4d5),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              _world.progress.complete
                                  ? 'A new path is waiting'
                                  : '${_world.progress.count}/3 ${_world.map.adventure == Adventure.garden ? 'gardens' : _world.map.collectibleName}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: _ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 9),
                        SizedBox(
                          width: math.min(
                            185,
                            MediaQuery.sizeOf(context).width - 174,
                          ),
                          child: ValueListenableBuilder<Encounter?>(
                            valueListenable: _game.interaction,
                            builder: (_, encounter, __) => _AdventureButton(
                              label: _actionLabel(encounter),
                              icon: encounter == null
                                  ? Icons.explore_rounded
                                  : Icons.auto_awesome,
                              onTap: encounter == null ? null : _interact,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              Positioned(
                left: 20,
                right: 20,
                bottom: 9,
                child: SafeArea(
                  top: false,
                  child: GestureDetector(
                    onTap: _save,
                    child: ValueListenableBuilder<String>(
                      valueListenable: _saveStatus,
                      builder: (_, label, __) => Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          color: _ink,
                          shadows: [
                            Shadow(color: Color(0xfffff5d5), blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_panel != null) ...[
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _closePanel,
                    child: Container(color: const Color(0x55415258)),
                  ),
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 25),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 510,
                          maxHeight: math.max(
                            150,
                            MediaQuery.sizeOf(context).height - 110,
                          ),
                        ),
                        child: _Parchment(
                          padding: const EdgeInsets.all(23),
                          child: SingleChildScrollView(
                            child: _panel == 'journal'
                                ? _journalCard()
                                : _encounterCard(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (_travelling)
                Positioned.fill(
                  child: Container(
                    color: const Color(0xeeedf0d8),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, color: _teal, size: 45),
                          SizedBox(height: 20),
                          Text(
                            'A new island is waking up…',
                            style: TextStyle(
                              fontSize: 21,
                              color: _ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

  Widget _encounterCard() {
    final encounter = _encounter!;
    final map = _world.map;
    final p = _world.progress;
    String title, body, button;
    var actionable = false;
    if (encounter == Encounter.friend) {
      title = '${map.friendName}, ${switch (map.adventure) {
        Adventure.rain => 'the lost cloud',
        Adventure.lantern => 'the lantern moth',
        Adventure.garden => 'the wandering turtle',
      }}';
      body = p.stage > 0
          ? '“You remembered me! This island will remember you, too.”\n\n${WorldRules.objective(_world)}'
          : map.story;
      if (map.adventure == Adventure.lantern && p.count < 3) {
        body +=
            '\n\nFollow the numbered lights: 1, then 2, then 3. The next light sparkles brighter.';
      }
      button = switch (map.adventure) {
        Adventure.rain => 'Open the crystal',
        Adventure.lantern => 'Return the starlight',
        Adventure.garden => 'Help Moss plant a home',
      };
      actionable =
          p.stage == 0 && (map.adventure != Adventure.lantern || p.count == 3);
    } else if (encounter == Encounter.wonder) {
      title = map.wonderName;
      body = p.complete ? map.consequence : WorldRules.objective(_world);
      if (map.adventure == Adventure.garden && p.stage == 1) {
        body =
            'A cool spring hides beneath these roots. Fill your little watering can, then plant a garden in each of the three glowing beds.';
        button = 'Fill the watering can';
        actionable = true;
      } else {
        button = map.adventure == Adventure.lantern
            ? 'Light the star lantern'
            : 'Plant a living skyway';
        actionable = !p.complete && p.count == 3 && p.stage > 0;
        if (actionable) {
          body =
              '${map.friendName} is beside you. One more kindness will change this whole island. Ready?';
        }
      }
    } else {
      title = p.complete ? 'Beyond the clouds' : 'A sleeping skyway';
      body = p.complete
          ? '${map.consequence}\n\nAnother island is waiting. Its paths, colors, and little mysteries will be different. You can return here from your trail book.'
          : 'This arch wakes when the island’s wonder comes alive.\n\n${WorldRules.objective(_world)}';
      button = 'Sail to island ${_world.islandIndex + 2}';
      actionable = p.complete;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: Color(0xffe9d9aa),
                shape: BoxShape.circle,
              ),
              child: Icon(
                encounter == Encounter.friend
                    ? Icons.favorite_rounded
                    : encounter == Encounter.gate
                        ? Icons.sailing_rounded
                        : Icons.spa_rounded,
                color: _teal,
                size: 25,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ),
            _RoundButton(
              label: 'Close encounter',
              icon: Icons.close_rounded,
              onTap: _closePanel,
              small: true,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          body,
          style: const TextStyle(
            fontSize: 16,
            height: 1.55,
            color: Color(0xff607276),
          ),
        ),
        const SizedBox(height: 24),
        if (actionable)
          _AdventureButton(
            label: button,
            icon: Icons.auto_awesome,
            onTap: _perform,
          ),
        if (encounter == Encounter.friend && !p.listened)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _AdventureButton(
              label: 'Remember their story',
              icon: Icons.menu_book_rounded,
              secondary: true,
              onTap: () {
                WorldRules.listen(_world);
                _game.refresh();
                _closePanel();
                _changed('A new memory tucked into your trail book.');
              },
            ),
          ),
        if (!actionable)
          _AdventureButton(
            label: 'Keep wandering',
            icon: Icons.explore_rounded,
            onTap: _closePanel,
          ),
      ],
    );
  }

  Widget _journalCard() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_stories_rounded, color: _teal, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Your endless trail',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ),
              _RoundButton(
                label: 'Close journal',
                icon: Icons.close_rounded,
                onTap: _closePanel,
                small: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (final entry in _world.journal)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                entry,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xff657675),
                ),
              ),
            ),
          const SizedBox(height: 10),
          const Text(
            'RETURN TO A MEMORY',
            style: TextStyle(
              letterSpacing: 1.7,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xff8f9276),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = _atlasPage;
                  index <= math.min(_world.highestVisited, _atlasPage + 7);
                  index++)
                Semantics(
                  key: ValueKey('visit-island-$index'),
                  container: true,
                  button: true,
                  label: 'Visit island ${index + 1}',
                  child: GestureDetector(
                    onTap: index == _world.islandIndex
                        ? null
                        : () => _travel(index),
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: index == _world.islandIndex
                            ? _teal
                            : const Color(0xffeee4c6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xffd9cdac)),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: index == _world.islandIndex ? _paper : _ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (_world.highestVisited >= 8)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  if (_atlasPage > 0)
                    _RoundButton(
                      label: 'Earlier islands',
                      icon: Icons.chevron_left,
                      onTap: () => setState(() => _atlasPage -= 8),
                    ),
                  const Spacer(),
                  if (_atlasPage + 8 <= _world.highestVisited)
                    _RoundButton(
                      label: 'Later islands',
                      icon: Icons.chevron_right,
                      onTap: () => setState(() => _atlasPage += 8),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 22),
          _AdventureButton(
            label: _game.calmMotion ? 'Calm motion is on' : 'Use calm motion',
            icon: Icons.air_rounded,
            secondary: true,
            onTap: () => setState(() => _game.calmMotion = !_game.calmMotion),
          ),
          const SizedBox(height: 13),
          const Text(
            'Drag the stick to move. Keyboard: WASD / arrows, Shift to run, E to interact, J for your trail.\n\nThe sky has no final island. Adventures remix a growing set of authored wonders.',
            style:
                TextStyle(fontSize: 12, height: 1.5, color: Color(0xff7f887a)),
          ),
        ],
      );
}

class _Parchment extends StatelessWidget {
  const _Parchment({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xfff4e6b9), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1a31464e),
              blurRadius: 18,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: child,
      );
}

class _AdventureButton extends StatelessWidget {
  const _AdventureButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.secondary = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool secondary;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: onTap != null,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(17),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: onTap == null || secondary
                      ? const [Color(0xffeae5ca), Color(0xffe6ddba)]
                      : const [Color(0xff5a9384), Color(0xff3d726f)],
                ),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: onTap == null || secondary
                      ? const Color(0xffc9c7aa)
                      : const Color(0xffa0c2a3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x22365052),
                    offset: const Offset(0, 4),
                    blurRadius: secondary ? 0 : 7,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 19,
                    color: secondary || onTap == null
                        ? const Color(0xff7f8c75)
                        : _paper,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: secondary || onTap == null
                            ? const Color(0xff7f8c75)
                            : _paper,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.small = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool small;
  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        button: true,
        child: Tooltip(
          message: label,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: small ? 38 : 44,
              height: small ? 38 : 44,
              decoration: BoxDecoration(
                color: const Color(0xeefff3d0),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xffe2d3ac)),
              ),
              child: Icon(icon, color: _ink, size: small ? 18 : 22),
            ),
          ),
        ),
      );
}

/// Raw pointer tracking avoids gesture-slop delay, supports analog speed, and
/// releases immediately on pointer-up/cancel. Only this knob rebuilds on drag.
class _AnalogStick extends StatefulWidget {
  const _AnalogStick({
    super.key,
    required this.onChanged,
    required this.onStart,
  });
  final void Function(double x, double y) onChanged;
  final VoidCallback onStart;
  @override
  State<_AnalogStick> createState() => _AnalogStickState();
}

class _AnalogStickState extends State<_AnalogStick> {
  int? _pointer;
  Offset _offset = Offset.zero;
  void _update(Offset position) {
    var delta = position - const Offset(62, 62);
    if (delta.distance > 43) delta = delta / delta.distance * 43;
    if (delta.distance < 4) delta = Offset.zero;
    setState(() => _offset = delta);
    widget.onChanged(delta.dx / 43, delta.dy / 43);
  }

  void _release() {
    _pointer = null;
    if (mounted) setState(() => _offset = Offset.zero);
    widget.onChanged(0, 0);
  }

  @override
  Widget build(BuildContext context) => Semantics(
        key: const ValueKey('movement-joystick'),
        container: true,
        label: 'Movement joystick. Drag to walk.',
        child: Listener(
          onPointerDown: (event) {
            if (_pointer != null) return;
            _pointer = event.pointer;
            widget.onStart();
            _update(event.localPosition);
          },
          onPointerMove: (event) {
            if (_pointer == event.pointer) _update(event.localPosition);
          },
          onPointerUp: (event) {
            if (_pointer == event.pointer) _release();
          },
          onPointerCancel: (event) {
            if (_pointer == event.pointer) _release();
          },
          child: Container(
            width: 124,
            height: 124,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x88fff6d9),
              border: Border.all(color: const Color(0xbbfff8df), width: 2),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 94,
                  height: 94,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0x55a0ae8e)),
                  ),
                ),
                for (final (alignment, icon) in [
                  (Alignment.topCenter, Icons.keyboard_arrow_up),
                  (Alignment.bottomCenter, Icons.keyboard_arrow_down),
                  (Alignment.centerLeft, Icons.keyboard_arrow_left),
                  (Alignment.centerRight, Icons.keyboard_arrow_right),
                ])
                  Align(
                    alignment: alignment,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child:
                          Icon(icon, size: 18, color: const Color(0x777d9077)),
                    ),
                  ),
                Transform.translate(
                  offset: _offset,
                  child: Container(
                    width: 49,
                    height: 49,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xfffff7df), Color(0xffe4d8ac)],
                      ),
                      border:
                          Border.all(color: const Color(0xfffff7dd), width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22616c56),
                          offset: Offset(0, 4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 20,
                      color: Color(0xff9b925f),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
