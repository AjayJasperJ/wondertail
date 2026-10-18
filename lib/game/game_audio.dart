import 'dart:async';
import 'package:flutter/services.dart';

/// Android synthesizer. Other platforms remain silent without blocking play.
class GameAudio {
  static const _channel = MethodChannel('wondertail/audio');
  bool _muted = false;
  int? _theme;
  void start(int theme) {
    if (_muted || _theme == theme) return;
    _theme = theme;
    _send('music', theme);
  }

  void cue(String cue) {
    if (!_muted) _send('cue', cue);
  }

  void pause() {
    _theme = null;
    _send('pause', null);
  }

  void setMuted(bool value, int theme) {
    _muted = value;
    if (value) {
      pause();
    } else {
      start(theme);
    }
  }

  void _send(String method, Object? value) {
    unawaited(_invoke(method, value));
  }

  Future<void> _invoke(String method, Object? value) async {
    try {
      await _channel.invokeMethod<void>(method, value);
    } on MissingPluginException {
      // Web/tests have no native audio engine.
    } on PlatformException {
      // Audio availability must never interrupt an adventure.
    }
  }
}
