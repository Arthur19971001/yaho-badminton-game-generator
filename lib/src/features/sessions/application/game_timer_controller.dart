import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../navigation/router_provider.dart';

part 'game_timer_controller.g.dart';

/// A single running (or just-expired) per-game timer. Only one can exist
/// app-wide at a time -- see [GameTimerController.start].
class GameTimerState {
  const GameTimerState({
    required this.sessionId,
    required this.roundId,
    required this.totalDuration,
    required this.endAt,
    required this.isRinging,
    this.pausedRemaining,
  });

  final int sessionId;
  final int roundId;
  final Duration totalDuration;
  final DateTime endAt;
  final bool isRinging;

  /// Non-null while paused: the remaining time frozen at the moment pause
  /// was pressed. When null, the timer is actively counting down toward
  /// [endAt].
  final Duration? pausedRemaining;

  bool get isPaused => pausedRemaining != null;

  Duration get remaining {
    if (pausedRemaining != null) return pausedRemaining!;
    final left = endAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  GameTimerState copyWith({bool? isRinging}) => GameTimerState(
        sessionId: sessionId,
        roundId: roundId,
        totalDuration: totalDuration,
        endAt: endAt,
        isRinging: isRinging ?? this.isRinging,
        pausedRemaining: pausedRemaining,
      );

  GameTimerState paused(Duration remainingAtPause) => GameTimerState(
        sessionId: sessionId,
        roundId: roundId,
        totalDuration: totalDuration,
        endAt: endAt,
        isRinging: isRinging,
        pausedRemaining: remainingAtPause,
      );

  GameTimerState resumed(DateTime newEndAt) => GameTimerState(
        sessionId: sessionId,
        roundId: roundId,
        totalDuration: totalDuration,
        endAt: newEndAt,
        isRinging: isRinging,
      );
}

/// App-wide, per-game countdown timer -- lives independently of any screen,
/// so it keeps running when the user navigates away from the game it was
/// started for (or to a different view entirely), and only one can be
/// active anywhere in the app at once. When it hits zero it loops a loud
/// siren and pops a modal "시간 종료" dialog (on the root navigator, so it
/// surfaces no matter what screen is currently showing) until dismissed.
@Riverpod(keepAlive: true)
class GameTimerController extends _$GameTimerController {
  Timer? _ticker;
  final AudioPlayer _alarmPlayer = AudioPlayer()
    ..setReleaseMode(ReleaseMode.loop);

  @override
  GameTimerState? build() {
    ref.onDispose(() {
      _ticker?.cancel();
      _alarmPlayer.dispose();
    });
    return null;
  }

  /// True if a timer for a round *other than* [roundId] is currently
  /// active -- the UI should refuse to start a new one in that case, since
  /// only one timer may run at a time.
  bool isBlockedByAnotherRound(int roundId) {
    final current = state;
    return current != null && current.roundId != roundId;
  }

  void start({
    required int sessionId,
    required int roundId,
    Duration duration = const Duration(minutes: 10),
  }) {
    if (isBlockedByAnotherRound(roundId)) return;
    _ticker?.cancel();
    state = GameTimerState(
      sessionId: sessionId,
      roundId: roundId,
      totalDuration: duration,
      endAt: DateTime.now().add(duration),
      isRinging: false,
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// Freezes the countdown at its current remaining time. No-op if there's
  /// no timer, it's already paused, or it has already rung (pausing a
  /// finished timer makes no sense -- dismiss it instead).
  void pause() {
    final current = state;
    if (current == null || current.isPaused || current.isRinging) return;
    _ticker?.cancel();
    _ticker = null;
    state = current.paused(current.remaining);
  }

  /// Resumes a paused countdown from wherever it was frozen.
  void resume() {
    final current = state;
    if (current == null || !current.isPaused) return;
    state = current.resumed(DateTime.now().add(current.remaining));
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final current = state;
    if (current == null) {
      _ticker?.cancel();
      return;
    }
    if (current.remaining == Duration.zero) {
      if (!current.isRinging) {
        state = current.copyWith(isRinging: true);
        _showAlarm();
      }
      // While ringing, the siren keeps looping on its own (ReleaseMode.loop)
      // -- nothing to do here every tick.
    } else {
      // Reassign (even to an equivalent value) so watchers rebuild with the
      // updated `remaining` every second -- GameTimerState uses identity
      // equality, so this always counts as a change.
      state = current.copyWith();
    }
  }

  void _showAlarm() {
    // Max volume, looping siren -- a plain system alert sound is too quiet
    // and easy to miss/ignore, especially over gym noise.
    unawaited(_alarmPlayer.play(AssetSource('sounds/siren.wav'), volume: 1.0));
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('시간 종료!'),
        content: const Text('설정한 게임 시간이 끝났습니다.'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              dismiss();
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// Stops the alarm/countdown and clears the timer entirely -- called
  /// when the user acknowledges the "시간 종료" dialog, or cancels a
  /// still-running timer outright.
  void dismiss() {
    _ticker?.cancel();
    _ticker = null;
    unawaited(_alarmPlayer.stop());
    state = null;
  }
}
