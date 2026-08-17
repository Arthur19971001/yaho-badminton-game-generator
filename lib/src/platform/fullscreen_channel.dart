import 'package:flutter/services.dart';

/// Bridges to the native macOS window's real (OS-level) fullscreen mode --
/// hides the menu bar/dock and gives a distraction-free "presentation"
/// view, the same as PowerPoint's slideshow mode -- via a couple of lines
/// of Swift in MainFlutterWindow.swift rather than pulling in a whole
/// window-management package for one toggle.
class FullscreenChannel {
  FullscreenChannel._();

  static const _channel = MethodChannel(
    'yaho_badminton_game_generator/fullscreen',
  );

  /// Toggles native fullscreen. Fire-and-forget -- the resulting state
  /// change (whether triggered by this call, the window's own green
  /// button, or an OS gesture) arrives via [setChangeListener].
  static Future<void> toggle() => _channel.invokeMethod('toggleFullScreen');

  /// Reports every fullscreen state change, however it happened -- our own
  /// [toggle] call, the native traffic-light button, or an OS fullscreen
  /// gesture -- so the Dart-side UI (e.g. hiding the app bar) always
  /// matches the real window state instead of just the button's own
  /// intent.
  static void setChangeListener(void Function(bool isFullScreen) onChanged) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'fullScreenChanged') {
        onChanged(call.arguments as bool);
      }
    });
  }
}
