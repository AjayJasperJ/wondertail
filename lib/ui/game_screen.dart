import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/save_repository.dart';
import '../domain/world_state.dart';
import '../game/wondertail_game.dart';

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
  final Set<LogicalKeyboardKey> _held = {};
  final Set<int> _touchHeld = {};
  Timer? _autosave;
  bool _dirty = false;
  bool _dialogOpen = false;
  String _saveLabel = 'Saved on this device';
  int _knownJournalLength = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _knownJournalLength = _world.journal.length;
    _game = WondertailGame(state: _world, onWorldChanged: _worldChanged);
    _autosave = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_dirty) unawaited(_save());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.loaded.notice != null) _notice(widget.loaded.notice!);
      unawaited(_save());
    });
  }

  void _worldChanged() {
    if (!mounted) return;
    _dirty = true;
    if (_world.journal.length != _knownJournalLength) {
      _knownJournalLength = _world.journal.length;
      unawaited(_save());
    }
    setState(() {});
  }

  Future<void> _save() async {
    _dirty = false;
    try {
      await widget.saves.save(_world);
      if (mounted && _saveLabel != 'Saved on this device') {
        setState(() => _saveLabel = 'Saved on this device');
      }
    } catch (_) {
      _dirty = true;
      if (mounted) setState(() => _saveLabel = 'Save failed · tap to retry');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _clearInput();
      _game.controlsEnabled = false;
      _game.pauseEngine();
      unawaited(_save());
    } else {
      _game.controlsEnabled = !_dialogOpen;
      _game.resumeEngine();
    }
  }

  void _clearInput() {
    _held.clear();
    _touchHeld.clear();
    _game.clearInput();
  }

  void _syncInput() {
    bool has(LogicalKeyboardKey a, LogicalKeyboardKey b) =>
        _held.contains(a) || _held.contains(b);
    _game.inputX =
        ((has(LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.keyD) ||
                    _touchHeld.contains(1))
                ? 1
                : 0) -
            ((has(LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.keyA) ||
                        _touchHeld.contains(3))
                    ? 1
                    : 0)
                .toDouble();
    _game.inputY =
        ((has(LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.keyS) ||
                    _touchHeld.contains(2))
                ? 1
                : 0) -
            ((has(LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.keyW) ||
                        _touchHeld.contains(0))
                    ? 1
                    : 0)
                .toDouble();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_dialogOpen) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final movement = {
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.keyW,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyS,
      LogicalKeyboardKey.keyD,
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
      unawaited(_interact());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyJ && event is KeyDownEvent) {
      unawaited(_showJournal());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<T?> _pauseFor<T>(Widget dialog) async {
    _dialogOpen = true;
    _clearInput();
    _game.controlsEnabled = false;
    final result = await showDialog<T>(
      context: context,
      builder: (_) => dialog,
    );
    if (mounted) {
      _dialogOpen = false;
      _game.controlsEnabled = true;
      _keyboard.requestFocus();
    }
    return result;
  }

  Future<void> _interact() async {
    if (_dialogOpen) return;
    final encounter = WorldRules.nearby(_world);
    if (encounter == null) return;
    String title;
    String body;
    String? action;
    switch (encounter) {
      case Encounter.cloud:
        title = _world.cloudRescued
            ? 'Pip, your cloud friend'
            : 'A cloud in a crystal';
        body = _world.cloudRescued
            ? '“Thank you for listening. Wherever you wander, I’ll come too!”'
            : _world.studiedCrystal
                ? 'The crystal is an old cloud shelter. Its door is stuck! A gentle push will let the little cloud out.'
                : 'A little cloud taps on the glass. “Hello? I can hear the trees dreaming of rain.”';
        action = _world.cloudRescued ? null : 'Open the crystal';
      case Encounter.grove:
        title = _world.groveGrown ? 'The grateful grove' : 'The sleepy grove';
        body = !_world.cloudRescued
            ? 'The tiny trees are thirsty. Your compass points toward someone who could help.'
            : !_world.groveGrown
                ? 'Pip is watering the roots. Give the little trees a moment to wake up.'
                : _world.seedCollected
                    ? 'Leaves rustle a happy hello. The grove remembers the rain you brought.'
                    : 'Because you freed Pip, rain reached the roots. The trees grew a bright seed just for you!';
        action = _world.groveGrown && !_world.seedCollected
            ? 'Take the bright seed'
            : null;
      case Encounter.bridge:
        title = 'A seed-sized hollow';
        body = _world.bridgeGrown
            ? 'Your seed became a living bridge. You can walk across it to the lantern!'
            : _world.seedCollected
                ? 'Your bright seed wiggles in your backpack. This sunny hollow looks like a good home.'
                : 'There is a tiny hollow in the soil. Maybe a seed from a happy grove could grow here.';
        action = _world.seedCollected && !_world.bridgeGrown
            ? 'Plant my seed'
            : null;
      case Encounter.lookout:
        title = _world.lookoutReached
            ? 'Little Drift remembers'
            : 'You made a new path!';
        body = _world.lookoutReached
            ? 'Pip, the grove, and your bridge are still here. Wander back any time. This is the end of the first little adventure.'
            : 'One small kindness became rain, a grove, a seed, and a bridge. Pip settles beside you. “Where shall we wander next?”';
        action = _world.lookoutReached ? null : 'Remember this adventure';
    }
    final choice = await _pauseFor<String>(
      AlertDialog(
        icon: Icon(
          encounter == Encounter.cloud
              ? Icons.cloud_outlined
              : Icons.spa_outlined,
          size: 35,
          color: const Color(0xff658b72),
        ),
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 370),
          child: Text(body, style: const TextStyle(fontSize: 17, height: 1.5)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep exploring'),
          ),
          if (encounter == Encounter.cloud &&
              !_world.cloudRescued &&
              !_world.studiedCrystal)
            TextButton(
              onPressed: () => Navigator.pop(context, 'study'),
              child: const Text('Listen first'),
            ),
          if (action != null)
            FilledButton(
              onPressed: () => Navigator.pop(context, 'act'),
              child: Text(action),
            ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'study') {
      WorldRules.study(_world);
      _worldChanged();
      _notice('You listen closely. The crystal has a small door!');
    } else if (choice == 'act' && WorldRules.act(_world, encounter)) {
      _worldChanged();
      _notice(switch (encounter) {
        Encounter.cloud => 'Pip is free! Follow the rain to the sleepy grove.',
        Encounter.grove => 'One bright seed, tucked safely in your backpack.',
        Encounter.bridge => 'Your kindness made a new path. Walk across!',
        Encounter.lookout =>
          'Adventure remembered. Thank you for playing Little Drift.',
      });
    }
  }

  void _notice(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showJournal() async {
    if (_dialogOpen) return;
    await _pauseFor<void>(
      AlertDialog(
        title: const Text('Your little book of wonders'),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LITTLE DRIFT  /  CHAPTER 01',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 2,
                    color: Color(0xff788b72),
                  ),
                ),
                const SizedBox(height: 20),
                for (final entry in _world.journal)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Text(
                      '✦  $entry',
                      style: const TextStyle(height: 1.5, fontSize: 16),
                    ),
                  ),
                const Divider(),
                const Text(
                  'Move: arrow keys, WASD, or hold the direction buttons.\nInteract: E, Space, or the action button.\nJournal: J. Progress saves on this device.',
                  style: TextStyle(height: 1.6, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to the island'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _autosave?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.saves.save(_world).catchError((Object _) {}));
    _keyboard.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = WorldRules.target(_world);
    final dx = target.x - _world.x;
    final dy = target.y - _world.y;
    final nearby = WorldRules.nearby(_world);
    final actionLabel = switch (nearby) {
      Encounter.cloud => _world.cloudRescued ? 'Talk to Pip' : 'Meet the cloud',
      Encounter.grove => _world.groveGrown && !_world.seedCollected
          ? 'Collect a seed'
          : 'Visit the grove',
      Encounter.bridge => _world.seedCollected && !_world.bridgeGrown
          ? 'Plant your seed'
          : 'Look closer',
      Encounter.lookout => 'Enjoy the view',
      null => 'Follow your compass',
    };
    return Scaffold(
      backgroundColor: const Color(0xfffffcf4),
      body: SafeArea(
        child: Focus(
          focusNode: _keyboard,
          autofocus: true,
          onKeyEvent: _onKey,
          onFocusChange: (focused) {
            if (!focused) _clearInput();
          },
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: Color(0xffa68c55),
                      size: 25,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WONDERTAIL',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.6,
                              color: Color(0xff517566),
                            ),
                          ),
                          Text(
                            'Little Drift',
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w600,
                              color: Color(0xff354f43),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Your journal (J)',
                      onPressed: _showJournal,
                      icon: const Icon(Icons.menu_book_outlined),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ClipRect(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: GameWidget(game: _game, autofocus: false),
                      ),
                      Positioned(
                        top: 14,
                        left: 14,
                        right: 14,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xeefffdf4),
                                borderRadius: BorderRadius.circular(19),
                                border: Border.all(
                                  color: const Color(0x77ffffff),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: const BoxDecoration(
                                      color: Color(0xffecedcf),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Transform.rotate(
                                      angle: math.atan2(dy, dx) + math.pi / 2,
                                      child: const Icon(
                                        Icons.navigation_rounded,
                                        color: Color(0xff758765),
                                        size: 25,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'YOUR WONDER COMPASS',
                                          style: TextStyle(
                                            fontSize: 9,
                                            letterSpacing: 1.7,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xff859079),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          WorldRules.objective(_world),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            height: 1.25,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xff415d4b),
                                          ),
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
                      Positioned(left: 14, bottom: 14, child: _directionPad()),
                      Positioned(
                        right: 14,
                        bottom: 21,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xddfffdf4),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_world.pocketSeeds} seed  ·  ${_world.kindnessCount} kindness${_world.kindnessCount == 1 ? '' : 'es'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xff657960),
                                ),
                              ),
                            ),
                            const SizedBox(height: 9),
                            SizedBox(
                              width: 170,
                              child: FilledButton.icon(
                                onPressed: nearby == null ? null : _interact,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 17,
                                  ),
                                  backgroundColor: const Color(0xff4f7967),
                                  disabledBackgroundColor: const Color(
                                    0xdde6ead8,
                                  ),
                                  disabledForegroundColor: const Color(
                                    0xff6c7c65,
                                  ),
                                ),
                                icon: Icon(
                                  nearby == null
                                      ? Icons.explore_outlined
                                      : Icons.auto_awesome,
                                  size: 18,
                                ),
                                label: Text(
                                  actionLabel,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _saveLabel.startsWith('Save failed')
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        size: 13,
                        color: const Color(0xff7c8d73),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _saveLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xff718369),
                          ),
                        ),
                      ),
                      const Text(
                        'Every kindness opens a path.',
                        style: TextStyle(
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          color: Color(0xff718369),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _directionPad() => SizedBox(
        width: 138,
        height: 138,
        child: Stack(
          children: [
            Positioned(
              left: 47,
              top: 47,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0x55fffdf4),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.circle, size: 9, color: Color(0xff809576)),
              ),
            ),
            _directionButton(0, 47, 0, Icons.keyboard_arrow_up, 'Move up'),
            _directionButton(
                1, 94, 47, Icons.keyboard_arrow_right, 'Move right'),
            _directionButton(2, 47, 94, Icons.keyboard_arrow_down, 'Move down'),
            _directionButton(3, 0, 47, Icons.keyboard_arrow_left, 'Move left'),
          ],
        ),
      );

  Widget _directionButton(
    int direction,
    double left,
    double top,
    IconData icon,
    String label,
  ) =>
      Positioned(
        left: left,
        top: top,
        child: Semantics(
          label: label,
          button: true,
          onTap: () {
            if (_dialogOpen) return;
            final dx = direction == 1
                ? 1.0
                : direction == 3
                    ? -1.0
                    : 0.0;
            final dy = direction == 2
                ? 1.0
                : direction == 0
                    ? -1.0
                    : 0.0;
            for (var i = 0; i < 5; i++) {
              WorldRules.move(_world, dx, dy, 0.05);
            }
            _worldChanged();
          },
          child: Listener(
            onPointerDown: (_) {
              if (!_dialogOpen) {
                _keyboard.requestFocus();
                _touchHeld.add(direction);
                _syncInput();
              }
            },
            onPointerUp: (_) {
              _touchHeld.remove(direction);
              _syncInput();
            },
            onPointerCancel: (_) {
              _touchHeld.remove(direction);
              _syncInput();
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xeefffdf4),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0x99ffffff)),
              ),
              child: Icon(icon, color: const Color(0xff577462), size: 29),
            ),
          ),
        ),
      );
}
