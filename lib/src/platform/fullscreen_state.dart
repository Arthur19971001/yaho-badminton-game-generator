import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'fullscreen_state.g.dart';

/// Whether the app is currently in real OS-level fullscreen (the PPT-style
/// presentation view). [ResultsScreen] owns the actual toggle/listener and
/// updates this; other widgets -- like [GameTimerBadge], which needs to
/// disable its tap-to-jump-to-game behavior during a presentation instead
/// of disrupting it -- just read it.
@Riverpod(keepAlive: true)
class FullscreenState extends _$FullscreenState {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}
