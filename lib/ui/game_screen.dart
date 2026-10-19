import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/save_repository.dart';
import '../domain/world_state.dart';
import '../game/wondertail_game.dart';
import '../game/game_audio.dart';

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
  final _audio = GameAudio();
  bool _muted = false;
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
    _game = WondertailGame(
        state: _world, onWorldChanged: _changed, onSound: _audio.cue);
    _world.profile.reconcile(_world);
    _game.calmMotion = _world.calm;
    _muted = !_world.sound;
    if (_muted) _audio.setMuted(true, _world.map.adventure.index);
    _autosave = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_game.movedSinceSave || _retrySave) unawaited(_save());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showRibbon(
        widget.loaded.notice ??
            '${_world.map.condition} · ${_world.map.conditionHint}',
      );
      unawaited(_save());
    });
  }

  void _changed(String message) {
    _world.profile.reconcile(_world);
    if (_world.run != null &&
        _world.progress.complete &&
        _world.islandIndex == 5) {
      _world.run!.finish(_world.profile);
      unawaited(
          widget.saves.saveRunReward(_world.profile).catchError((Object _) {
        if (mounted)
          _saveStatus.value = 'Return to lobby to retry saving the run reward';
      }));
    }
    if (_world.run?.finished ?? false) {
      _game.controlsEnabled = false;
      setState(() => _panel = 'runresult');
    }
    if (!message.contains('coin') && !message.contains('scarf')) {
      _audio.cue(_world.progress.complete ? 'complete' : 'task');
    }
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
    if (dx != 0 || dy != 0 || _touchX != 0 || _touchY != 0) {
      _audio.start(_world.map.adventure.index);
    }
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
      _audio.pause();
      _game.pauseEngine();
      unawaited(_save());
    } else {
      _game.controlsEnabled = _panel == null && !_travelling;
      _game.resumeEngine();
      _audio.start(_world.map.adventure.index);
    }
  }

  Future<void> _returnToLobby() async {
    _clearInput();
    _game.controlsEnabled = false;
    try {
      await widget.saves.save(_world);
      if (mounted && Navigator.of(context).canPop()) {
        _audio.pause();
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) _showRibbon('Could not save your trail. Please try again.');
    } finally {
      if (mounted) _game.controlsEnabled = _panel == null && !_travelling;
    }
  }

  void _closePanel() {
    if (_world.run?.finished ?? false) return;
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
    if (encounter == Encounter.mirror) {
      WorldRules.act(_world, encounter);
      _game.refresh();
      _changed('Mirror points ${[
        'north',
        'east',
        'south',
        'west'
      ][_world.progress.mirror]}. Match a gate’s rune.');
      return;
    }
    final bed = WorldRules.bedIndex(encounter);
    if (bed != null) {
      if (WorldRules.act(_world, encounter)) {
        _game.burst(_world.map.collectibles[bed], const Color(0xffffd99c));
        _game.refresh();
        _changed(
          _world.map.adventure == Adventure.rain
              ? 'Sunseed gathered · ${_world.progress.count}/3'
              : _world.progress.complete
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
      final memory = _world.run == null
          ? await widget.saves.loadIsland(index)
          : IslandProgress();
      if (!mounted) return;
      if (_world.travel(index, memory)) {
        _game.refresh(arrival: true);
        _audio.start(_world.map.adventure.index);
        _audio.cue('complete');
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
    final beforeRoom = _world.room, beforeChamber = _world.chamber;
    if (WorldRules.act(_world, encounter)) {
      _game.burst(
        encounter == Encounter.friend ? _world.map.friend : _world.map.wonder,
        const Color(0xffffe29a),
      );
      _game.refresh(
          arrival:
              beforeRoom != _world.room || beforeChamber != _world.chamber);
      _closePanel();
      _changed(
        encounter == Encounter.ruins
            ? 'Archive restored! Coin range ${_world.profile.coinRadius.round()} · hidden caches revealed.'
            : _world.progress.complete
                ? _world.map.consequence
                : WorldRules.objective(_world),
      );
    } else {
      _closePanel();
    }
  }

  String _actionLabel(Encounter? encounter) {
    if (encounter == null) return 'Follow the compass';
    if (WorldRules.bedIndex(encounter) != null)
      return _world.map.adventure == Adventure.rain
          ? 'Gather sunseed'
          : 'Plant a little garden';
    return switch (encounter) {
      Encounter.friend => 'Meet ${_world.map.friendName}',
      Encounter.wonder =>
        _world.map.adventure == Adventure.garden && _world.progress.stage == 1
            ? 'Fill your watering can'
            : 'Explore the wonder',
      Encounter.gate =>
        _world.progress.complete ? 'Next adventure' : 'Inspect the skyway',
      Encounter.cave => 'Enter crystal cave',
      Encounter.lodge => 'Enter scout lodge',
      Encounter.ruins => 'Explore ancient ruins',
      Encounter.exitRoom => 'Return outside',
      Encounter.scout => 'Talk to Scout Wren',
      Encounter.tool => 'Pick up shears',
      Encounter.vines => 'Clear vine gate',
      Encounter.cache => 'Open seed cache',
      Encounter.mirror => 'Rotate light mirror',
      Encounter.passageLeft => 'Explore left chamber',
      Encounter.passageRight => 'Explore right chamber',
      Encounter.glide => 'Glide across pond',
      _ => 'Explore',
    };
  }

  @override
  void dispose() {
    _autosave?.cancel();
    _ribbonTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.saves.save(_world).catchError((Object _) {}));
    _audio.pause();
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
              Positioned(
                top: 10,
                left: 14,
                right: 14,
                child: SafeArea(
                  bottom: false,
                  child: ValueListenableBuilder<int>(
                    valueListenable: _game.revision,
                    builder: (context, _, child) => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: Align(
                          alignment: Alignment.topLeft,
                          child: SizedBox(
                              width: 320,
                              child: _Parchment(
                                padding: const EdgeInsets.all(11),
                                child: Row(children: [
                                  ValueListenableBuilder<double>(
                                    valueListenable: _game.compassAngle,
                                    builder: (_, angle, child) =>
                                        Transform.rotate(
                                            angle: angle, child: child),
                                    child: const Icon(Icons.navigation_rounded,
                                        color: _teal, size: 26),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          _world.run == null
                                              ? 'ISLAND ${_world.islandIndex + 1} · ${_world.map.condition}'
                                              : 'RUN ${_world.islandIndex - 2}/3 · ${_world.run!.remaining.floor()}s left',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: _teal,
                                              fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 4),
                                      Text(WorldRules.objective(_world),
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: _ink,
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 3),
                                      Text(
                                          _world.run == null
                                              ? 'Bank coins • ${_world.map.friendName} bond ${_world.profile.rank(_world.map.adventure)}/3'
                                              : 'Active-play timer • menus pause the run',
                                          style: const TextStyle(
                                              fontSize: 9, color: _teal)),
                                    ],
                                  )),
                                ]),
                              )),
                        )),
                        const SizedBox(width: 8),
                        _Parchment(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Text('✦ ${_world.progress.coinCount}/12',
                                style: const TextStyle(
                                    color: _ink, fontWeight: FontWeight.w800))),
                        const SizedBox(width: 6),
                        _RoundButton(
                            label: _muted ? 'Enable sound' : 'Mute sound',
                            icon: _muted
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            onTap: () {
                              setState(() {
                                _muted = !_muted;
                                _world.sound = !_muted;
                              });
                              unawaited(_save());
                              _audio.setMuted(
                                  _muted, _world.map.adventure.index);
                            }),
                        const SizedBox(width: 6),
                        _RoundButton(
                            label: 'Return to lobby',
                            icon: Icons.home_rounded,
                            onTap: _returnToLobby),
                        const SizedBox(width: 6),
                        _RoundButton(
                            label: 'Your trail and journal',
                            icon: Icons.menu_book_rounded,
                            onTap: _openJournal),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 145,
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
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: math.min(
                              380, MediaQuery.sizeOf(context).width * 0.48),
                          maxHeight: math.max(
                            150,
                            MediaQuery.sizeOf(context).height * 0.76,
                          ),
                        ),
                        child: SizedBox(
                            key: const ValueKey('adventure-panel'),
                            child: _Parchment(
                              padding: const EdgeInsets.all(14),
                              child: SingleChildScrollView(
                                child: _panel == 'runresult'
                                    ? _runResult()
                                    : _panel == 'journal'
                                        ? _journalCard()
                                        : _encounterCard(),
                              ),
                            )),
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
    if (encounter == Encounter.tool) {
      title = 'Trail shears';
      body =
          'A clearing tool for this island. Use it beside the overgrown vine gate, or explore another route.';
      button = 'Take the shears';
      actionable = true;
    } else if (encounter == Encounter.vines) {
      title = 'An overgrown path';
      body = p.toolFound
          ? 'Your shears can clear these vines. The opening stays clear on return visits.'
          : 'Find the shears near camp, or walk around the tangled gate.';
      button = 'Clear the vines';
      actionable = p.toolFound;
    } else if (encounter == Encounter.cache) {
      title = 'A hidden seed cache';
      body =
          'Your scanner or companion found a cache: 3 Starlight and skyseeds for a creature favor. One cache per island.';
      button = 'Open the cache';
      actionable = !p.cacheOpened;
    } else if (encounter == Encounter.glide) {
      title = 'A short water crossing';
      body =
          'Your equipped Glider Cape carries you across this pond to the opposite safe bank. Land stays within the island.';
      button = 'Glide to the far bank';
      actionable = true;
    } else if (encounter == Encounter.passageLeft ||
        encounter == Encounter.passageRight) {
      final branch = encounter == Encounter.passageLeft ? 1 : 2;
      title = 'Light-locked chamber';
      body = 'This gate’s rune points ${[
        'north',
        'east',
        'south',
        'west'
      ][map.solution(branch)]}. Rotate the hub mirror to the same direction. Each branch holds cave crystals.';
      button = 'Enter chamber ${branch + 1}';
      actionable = p.mirror == map.solution(branch);
    } else if (encounter == Encounter.cave) {
      title = 'Beneath the mountain';
      body =
          'Explore ${map.chambers} connected chambers. Align the hub’s light mirror with each gate rune to reach three crystals, then power the archive.';
      button = 'Explore the cave';
      actionable = true;
    } else if (encounter == Encounter.lodge) {
      title = 'Wren’s scout lodge';
      body =
          'A warm map room hides inside. Scout Wren knows why these mountains glow at night.';
      button = 'Enter the lodge';
      actionable = true;
    } else if (encounter == Encounter.exitRoom) {
      title = _world.room == 1 && _world.chamber != 0
          ? 'Back to the hub'
          : 'Back to the open sky';
      body =
          'Your discoveries stay with this island. You can return whenever you like.';
      button = _world.room == 1 && _world.chamber != 0
          ? 'Return to cave hub'
          : 'Return outside';
      actionable = true;
    } else if (encounter == Encounter.scout) {
      title = 'Wren, the island scout';
      body = p.scoutMet
          ? (p.ruinsRestored
              ? '“You brought the Sky Archive back to life! Every explorer who comes here will see your work.”'
              : '“Find three crystals in the mountain cave. The empty pedestal at the ruins needs their light.”')
          : '“Welcome, explorer! The old Sky Archive has gone dark. Three cave crystals can wake it. Would you explore the mountain for me?”';
      button = 'Mark the discovery in my journal';
      actionable = !p.scoutMet;
    } else if (encounter == Encounter.ruins) {
      title = p.ruinsRestored
          ? 'The restored Sky Archive'
          : 'An ancient sky archive';
      body = p.ruinsRestored
          ? 'Your crystals hold a warm light above the old columns. Wren’s lost archive shines again.'
          : p.shards == 7
              ? 'Three crystals fit the empty pedestal. Place them to rebuild the arch and light the archive.'
              : 'The broken pedestal needs three cave crystals. You have found ${p.shardCount}/3. Scout Wren can tell you more.';
      button = 'Restore the Sky Archive';
      actionable = p.shards == 7 && !p.ruinsRestored;
    } else if (encounter == Encounter.friend) {
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
          ? '${map.consequence}\n\nNext: ${IslandMap.generate(_world.seed, _world.islandIndex + 1).name} — ${IslandMap.generate(_world.seed, _world.islandIndex + 1).title}. Find 12 sky coins to earn a glowing scarf here. Revisit islands from your trail book.'
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
                  fontSize: 18,
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
        const SizedBox(height: 10),
        Text(
          body,
          style: const TextStyle(
            fontSize: 13,
            height: 1.3,
            color: Color(0xff607276),
          ),
        ),
        const SizedBox(height: 12),
        if (actionable)
          _AdventureButton(
            label: button,
            icon: Icons.auto_awesome,
            onTap: _perform,
          ),
        if (encounter == Encounter.friend && p.complete && _world.run == null)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _AdventureButton(
                  label: p.favorGiven
                      ? 'Favor remembered'
                      : 'Give a skyseed · Bond rank ${_world.profile.rank(map.adventure)}/3',
                  icon: Icons.favorite_rounded,
                  onTap: p.favorGiven || _world.profile.seeds < 1
                      ? null
                      : () {
                          if (EngagementRules.favor(_world)) {
                            _game.refresh();
                            _closePanel();
                            _changed(
                                '${map.friendName} remembers your gift. Bond rank ${_world.profile.rank(map.adventure)}/3!');
                          }
                        })),
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
          const SizedBox(height: 12),
          Text(
              '✦ ${_world.profile.coins} Starlight · ◈ ${_world.profile.cores} cores · ${_world.profile.seeds} skyseeds\n'
              '${_world.map.condition}: ${_world.map.conditionHint}\n'
              '${_world.map.friendName} bond rank ${_world.profile.rank(_world.map.adventure)}/3',
              style: const TextStyle(fontSize: 12, color: _ink, height: 1.4)),
          Text(
              'DISCOVERIES · ${_world.map.landform}\n'
              '${_world.progress.scoutMet ? '✓' : '○'} Meet Wren in the lodge\n'
              '${_world.progress.shards == 7 ? '✓' : '○'} Cave crystals ${_world.progress.shardCount}/3\n'
              '${_world.progress.ruinsRestored ? '✓' : '○'} Restore the Sky Archive',
              style: const TextStyle(fontSize: 12, height: 1.5, color: _ink)),
          const SizedBox(height: 12),
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
                    onTap: index == _world.islandIndex || _world.run != null
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
            onTap: () {
              setState(() {
                _game.calmMotion = !_game.calmMotion;
                _world.calm = _game.calmMotion;
              });
              unawaited(_save());
            },
          ),
          const SizedBox(height: 13),
          const Text(
            'Drag the stick to move. Keyboard: WASD / arrows, Shift to run, E to interact, J for your trail.\n\nThe sky has no final island. Adventures remix a growing set of authored wonders.',
            style:
                TextStyle(fontSize: 12, height: 1.5, color: Color(0xff7f887a)),
          ),
        ],
      );

  Widget _runResult() => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                _world.run!.won
                    ? 'Trailblazer complete!'
                    : 'The starlight settled',
                style: const TextStyle(
                    color: _ink, fontWeight: FontWeight.w800, fontSize: 21)),
            const SizedBox(height: 10),
            Text(
                _world.run!.won
                    ? 'Three islands restored in ${_world.run!.elapsed.toStringAsFixed(1)} seconds. Your first victory earns the permanent Trailblazer Cape, 24 Starlight and 2 cores. Later victories improve your best time.'
                    : 'The optional 7-minute run ended. Your normal world and its progress are safe. You can try a new route from the lobby.',
                style: const TextStyle(color: _ink, height: 1.4)),
            const SizedBox(height: 12),
            _AdventureButton(
                label: 'Return to lobby',
                icon: Icons.home_rounded,
                onTap: _returnToLobby),
          ]);
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
