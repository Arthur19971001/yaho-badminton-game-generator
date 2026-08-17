import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../navigation/router_provider.dart';
import '../../../../platform/fullscreen_state.dart';
import '../../application/game_timer_controller.dart';
import '../../application/results_jump_request.dart';
import '../../application/session_controller.dart';

/// A slim bar pinned above every screen (wired in via [MaterialApp.router]'s
/// `builder`) showing the running per-game timer's remaining time, if any,
/// with its own pause/resume control. Tapping the rest of the bar jumps to
/// that game's full view -- if a [ResultsScreen] for that session is
/// already mounted, it just updates itself in place (via
/// [ResultsJumpRequestController]) instead of navigating, so tapping the
/// badge never stacks a redundant page. Renders nothing when no timer is
/// active.
///
/// That jump-to-game tap is disabled entirely while the app is in
/// fullscreen presentation mode ([fullscreenStateProvider]) -- a
/// presentation shouldn't be disrupted by a state/page change from tapping
/// the badge; switching games there is only via the full view's own arrow
/// buttons. Pause/resume/stop still work regardless, since those don't
/// change which game or page is shown.
class GameTimerBadge extends ConsumerWidget {
  const GameTimerBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(gameTimerControllerProvider);
    if (timer == null) return const SizedBox.shrink();

    final isFullscreen = ref.watch(fullscreenStateProvider);
    final notifier = ref.read(gameTimerControllerProvider.notifier);
    final sessionAsync = ref.watch(sessionControllerProvider(timer.sessionId));
    final gameNumber = sessionAsync.value?.rounds
        .firstWhere(
          (r) => r.id == timer.roundId,
          orElse: () => sessionAsync.value!.rounds.first,
        )
        .gameNumber;

    final remaining = timer.remaining;
    final minutes = remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');

    final background = timer.isRinging
        ? Colors.red
        : timer.isPaused
        ? Colors.orange.shade800
        : Colors.green.shade700;

    return Material(
      color: background,
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: InkWell(
                // Not `context.push` on this widget's own context -- this
                // badge is a sibling of the routed content in
                // MaterialApp.router's `builder` (see app.dart), sitting
                // outside the Router's widget subtree, so
                // GoRouter.of(context) can't find a router from here. The
                // root navigator's own context (inside that subtree) can.
                //
                // null (not a no-op callback) while in fullscreen, so
                // InkWell also drops the tap ripple -- the badge visibly
                // isn't interactive there, not just silently ignored.
                onTap: isFullscreen
                    ? null
                    : () {
                        ref
                            .read(resultsJumpRequestControllerProvider.notifier)
                            .request(timer.sessionId, timer.roundId);
                        final navContext = rootNavigatorKey.currentContext;
                        if (navContext == null) return;
                        // If the results screen for this exact session is
                        // already the current page, the jump request above
                        // is enough -- its own ref.listen updates the
                        // view/game in place, no navigation at all. When
                        // it's NOT already open (e.g. tapped from the
                        // members or sessions screen), `push` -- not `go`
                        // -- onto the current stack: `go` reparses the
                        // whole location and replaces the stack outright,
                        // which silently drops the back button (nothing
                        // left to pop back to).
                        final currentPath =
                            GoRouter.of(navContext).state.uri.path;
                        if (currentPath ==
                            '/sessions/${timer.sessionId}/results') {
                          return;
                        }
                        navContext.push(
                          '/sessions/${timer.sessionId}/results?view=full&roundId=${timer.roundId}',
                        );
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        timer.isRinging
                            ? Icons.alarm
                            : timer.isPaused
                            ? Icons.pause_circle_outline
                            : Icons.timer_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        gameNumber == null
                            ? '$minutes:$seconds'
                            : '게임 $gameNumber 타이머  $minutes:$seconds',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!timer.isRinging)
              IconButton(
                icon: Icon(
                  timer.isPaused ? Icons.play_arrow : Icons.pause,
                  color: Colors.white,
                ),
                onPressed: timer.isPaused ? notifier.resume : notifier.pause,
              ),
            if (!timer.isRinging)
              IconButton(
                icon: const Icon(Icons.stop, color: Colors.white),
                onPressed: notifier.dismiss,
              ),
          ],
        ),
      ),
    );
  }
}
