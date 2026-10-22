import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../members/domain/member.dart';
import '../../application/game_timer_controller.dart';
import '../../domain/court_assignment.dart';
import '../../domain/game_round.dart';
import 'court_capacity.dart';
import 'player_actions.dart';
import 'player_streak.dart';

/// Korean names first (in 가나다 order), then everything else
/// alphabetically -- plain string comparison would put Latin letters
/// first (they sit at lower Unicode code points than Hangul syllables).
int _compareDisplayNames(String a, String b) {
  bool isKorean(String s) {
    if (s.isEmpty) return false;
    final code = s.codeUnitAt(0);
    return code >= 0xAC00 && code <= 0xD7A3;
  }

  final aKorean = isKorean(a);
  final bKorean = isKorean(b);
  if (aKorean != bKorean) return aKorean ? -1 : 1;
  return a.compareTo(b);
}

/// Picks the (columns, rows) grid that fits [count] cards into the
/// available (width, height) as large as possible -- tries every column
/// count from 1 to [count] and keeps whichever produces the biggest
/// (most square-ish) card, so callers can size every card to exactly fill
/// its slot instead of scrolling to see the rest.
(int, int) _bestGrid(int count, double width, double height) {
  if (count <= 1) return (1, count.clamp(1, 1 << 31));
  var bestColumns = 1;
  var bestScore = -1.0;
  for (var columns = 1; columns <= count; columns++) {
    final rows = (count / columns).ceil();
    final score = min(width / columns, height / rows);
    if (score > bestScore) {
      bestScore = score;
      bestColumns = columns;
    }
  }
  return (bestColumns, (count / bestColumns).ceil());
}

/// 전체 뷰: one game at a time, every court shown with the players inside
/// it. Arrow buttons move to the previous/next game, and the dropdown
/// jumps straight to any game number. Normally laid out 2-per-row and
/// scrollable; in [isPresentation] mode (the PPT-style fullscreen view)
/// every court is instead sized to fit on screen at once, with larger
/// text for readability from a distance.
class GameFullView extends ConsumerWidget {
  const GameFullView({
    required this.sessionId,
    required this.rounds,
    required this.memberById,
    required this.attendeeIds,
    required this.gameIndex,
    required this.onIndexChanged,
    required this.courtLabel,
    this.isPresentation = false,
    super.key,
  });

  final int sessionId;
  final List<GameRound> rounds;
  final Map<int, Member> memberById;
  final List<int> attendeeIds;
  final int gameIndex;
  final ValueChanged<int> onIndexChanged;
  final String Function(int courtNumber) courtLabel;
  final bool isPresentation;

  static const _cardSpacing = 24.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final round = rounds[gameIndex];
    final actions = PlayerActions(
      sessionId: sessionId,
      rounds: rounds,
      memberById: memberById,
      attendeeIds: attendeeIds,
    );
    void showCourtmates(int playerId) => actions.showCourtmates(
          context,
          playerId: playerId,
          throughIndex: gameIndex,
        );
    void showMenu(int playerId, Offset position) => actions.showMenuAt(
          context,
          ref,
          position,
          playerId: playerId,
          throughIndex: gameIndex,
        );
    final streaks = {
      for (final playerId in round.courts.expand((c) => c.playerIds))
        playerId: consecutiveGamesPlayed(rounds, gameIndex, playerId),
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: '이전 게임',
                onPressed:
                    gameIndex > 0 ? () => onIndexChanged(gameIndex - 1) : null,
              ),
              const SizedBox(width: 8),
              DropdownMenu<int>(
                key: ValueKey(round.gameNumber),
                initialSelection: round.gameNumber,
                label: const Text('게임 선택'),
                dropdownMenuEntries: [
                  for (final r in rounds)
                    DropdownMenuEntry(value: r.gameNumber, label: '게임 ${r.gameNumber}'),
                ],
                onSelected: (value) {
                  if (value == null) return;
                  final idx = rounds.indexWhere((r) => r.gameNumber == value);
                  if (idx != -1) onIndexChanged(idx);
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: '다음 게임',
                onPressed: gameIndex < rounds.length - 1
                    ? () => onIndexChanged(gameIndex + 1)
                    : null,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _TimerControls(sessionId: sessionId, round: round),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final sortedCourts = [...round.courts]
                  ..sort((a, b) => a.courtNumber.compareTo(b.courtNumber));

                if (isPresentation) {
                  // Every court sized to fit the screen at once -- no
                  // scrolling -- with larger text for readability from a
                  // distance.
                  final (columns, rows) = _bestGrid(
                    sortedCourts.length,
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final cardWidth =
                      (constraints.maxWidth - (columns - 1) * _cardSpacing) /
                          columns;
                  final cardHeight =
                      (constraints.maxHeight - (rows - 1) * _cardSpacing) /
                          rows;
                  final rowsOfCourts = <List<CourtAssignment>>[];
                  for (var i = 0; i < sortedCourts.length; i += columns) {
                    rowsOfCourts.add(sortedCourts.sublist(
                      i,
                      min(i + columns, sortedCourts.length),
                    ));
                  }

                  return Column(
                    children: [
                      for (var r = 0; r < rowsOfCourts.length; r++) ...[
                        if (r > 0) const SizedBox(height: _cardSpacing),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < rowsOfCourts[r].length; i++) ...[
                                if (i > 0)
                                  const SizedBox(width: _cardSpacing),
                                SizedBox(
                                  width: cardWidth,
                                  height: cardHeight,
                                  child: _CourtCard(
                                    court: rowsOfCourts[r][i],
                                    label: courtLabel(
                                      rowsOfCourts[r][i].courtNumber,
                                    ),
                                    memberById: memberById,
                                    streakByPlayerId: streaks,
                                    onPlayerTap: showCourtmates,
                                    onPlayerSecondaryTap: showMenu,
                                    large: true,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                }

                final cardWidth = (constraints.maxWidth - _cardSpacing) / 2;
                final rowsOfCourts = <List<CourtAssignment>>[];
                for (var i = 0; i < sortedCourts.length; i += 2) {
                  rowsOfCourts.add(sortedCourts.sublist(
                    i,
                    min(i + 2, sortedCourts.length),
                  ));
                }

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final rowCourts in rowsOfCourts)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: _cardSpacing),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var i = 0; i < rowCourts.length; i++) ...[
                                if (i > 0)
                                  const SizedBox(width: _cardSpacing),
                                SizedBox(
                                  width: cardWidth,
                                  child: _CourtCard(
                                    court: rowCourts[i],
                                    label: courtLabel(rowCourts[i].courtNumber),
                                    memberById: memberById,
                                    streakByPlayerId: streaks,
                                    onPlayerTap: showCourtmates,
                                    onPlayerSecondaryTap: showMenu,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        if (round.restingPlayerIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _RestingNames(
              restingPlayerIds: round.restingPlayerIds,
              memberById: memberById,
              onPlayerTap: showCourtmates,
              onPlayerSecondaryTap: showMenu,
            ),
          ),
      ],
    );
  }

}

/// A player's name that opens the "같이 친 횟수" dialog on click and the
/// player menu on right-click.
class _ClickableName extends StatelessWidget {
  const _ClickableName({
    required this.playerId,
    required this.onTap,
    required this.onSecondaryTap,
    required this.child,
  });

  final int playerId;
  final void Function(int playerId) onTap;
  final void Function(int playerId, Offset globalPosition) onSecondaryTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(playerId),
      onSecondaryTapDown: (details) =>
          onSecondaryTap(playerId, details.globalPosition),
      child: MouseRegion(cursor: SystemMouseCursors.click, child: child),
    );
  }
}

/// "쉬는 인원: 가, 나, 다" with each name individually clickable.
class _RestingNames extends StatelessWidget {
  const _RestingNames({
    required this.restingPlayerIds,
    required this.memberById,
    required this.onPlayerTap,
    required this.onPlayerSecondaryTap,
  });

  final List<int> restingPlayerIds;
  final Map<int, Member> memberById;
  final void Function(int playerId) onPlayerTap;
  final void Function(int playerId, Offset globalPosition)
      onPlayerSecondaryTap;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    String nameOf(int id) => memberById[id]?.name ?? '알 수 없음';
    final sorted = [...restingPlayerIds]
      ..sort((a, b) => _compareDisplayNames(nameOf(a), nameOf(b)));

    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        Text('쉬는 인원: ', style: style),
        for (var i = 0; i < sorted.length; i++)
          _ClickableName(
            playerId: sorted[i],
            onTap: onPlayerTap,
            onSecondaryTap: onPlayerSecondaryTap,
            child: Text(
              i < sorted.length - 1 ? '${nameOf(sorted[i])}, ' : nameOf(sorted[i]),
              style: style,
            ),
          ),
      ],
    );
  }
}

class _CourtCard extends StatelessWidget {
  const _CourtCard({
    required this.court,
    required this.label,
    required this.memberById,
    required this.streakByPlayerId,
    required this.onPlayerTap,
    required this.onPlayerSecondaryTap,
    this.large = false,
  });

  final CourtAssignment court;
  final String label;
  final Map<int, Member> memberById;
  final Map<int, int> streakByPlayerId;
  final void Function(int playerId) onPlayerTap;
  final void Function(int playerId, Offset globalPosition)
      onPlayerSecondaryTap;

  /// Bigger text for the fullscreen/presentation view, read from further
  /// away than the normal windowed full view.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final status = capacityStatusOf(court);
    final color = status.color;
    String nameOf(int id) => (memberById[id] ?? Member.unknown(id)).name;
    final sortedPlayerIds = [...court.playerIds]
      ..sort((a, b) => _compareDisplayNames(nameOf(a), nameOf(b)));

    final labelStyle = (large
            ? Theme.of(context).textTheme.displaySmall
            : Theme.of(context).textTheme.headlineSmall)
        ?.copyWith(fontWeight: FontWeight.bold);
    // Presentation mode: no fixed name size -- each name fills its share
    // of the card via FittedBox instead, so it's always as big as the
    // card and player count allow, rather than capped at some constant
    // style. The consecutive-streak note is dropped entirely here too --
    // it's a working-view detail, not something a presentation audience
    // needs.
    final nameStyle = Theme.of(context)
        .textTheme
        .headlineMedium
        ?.copyWith(fontWeight: FontWeight.w600);

    Widget buildContent() {
      if (court.playerIds.isEmpty) {
        return Text(
          '빈 코트',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
                fontStyle: FontStyle.italic,
              ),
        );
      }

      if (large) {
        // A single name is short and wide, and a whole stack of them is
        // narrow and tall -- neither one's *aspect ratio* matches a wide
        // court card's, so any approach that scales by aspect ratio
        // (FittedBox/BoxFit.contain) necessarily leaves one dimension
        // mostly empty. Instead, size the font directly off the actual
        // available height per player (using the space fully), and only
        // fall back to shrinking an individual name if -- at that size --
        // it's too wide for the card.
        return LayoutBuilder(
          builder: (context, constraints) {
            final perPlayerHeight =
                constraints.maxHeight / sortedPlayerIds.length;
            final fontSize = (perPlayerHeight * 0.55).clamp(32.0, 200.0);
            final bigNameStyle =
                nameStyle?.copyWith(fontSize: fontSize) ??
                    TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600);

            return Column(
              children: [
                for (final id in sortedPlayerIds)
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _ClickableName(
                          playerId: id,
                          onTap: onPlayerTap,
                          onSecondaryTap: onPlayerSecondaryTap,
                          child: Text(
                            (memberById[id] ?? Member.unknown(id)).name,
                            style: bigNameStyle,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final id in sortedPlayerIds)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  _ClickableName(
                    playerId: id,
                    onTap: onPlayerTap,
                    onSecondaryTap: onPlayerSecondaryTap,
                    child: Text(
                      (memberById[id] ?? Member.unknown(id)).name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if ((streakByPlayerId[id] ?? 0) > 1)
                    Text(
                      '${streakByPlayerId[id]}연속',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: (streakByPlayerId[id] ?? 0) >= 3
                            ? Colors.orange.shade800
                            : Theme.of(context).colorScheme.outline,
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
    }

    final content = buildContent();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: status != CourtCapacityStatus.normal ? color : Colors.green.shade700,
          width: status != CourtCapacityStatus.normal ? 3 : 2,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: status != CourtCapacityStatus.normal
                ? color.withValues(alpha: 0.15)
                : Colors.green.withValues(alpha: 0.1),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, textAlign: TextAlign.center, style: labelStyle),
                if (status.warningIcon case final icon?) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: status.label,
                    child: Icon(icon, color: color.shade700),
                  ),
                ],
              ],
            ),
          ),
          // In presentation mode the card has a fixed height (sized to fit
          // the whole grid on screen), so the content area fills whatever
          // space is left -- each name's FittedBox scales it up to use
          // that space, rather than capping it at some fixed style.
          if (large)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 12,
                ),
                child: court.playerIds.isEmpty
                    ? Center(child: content)
                    : content,
              ),
            )
          else
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              child: content,
            ),
        ],
      ),
    );
  }
}

/// Start/stop controls and live countdown for this game's timer. Only one
/// timer may run app-wide, so when a different round's timer is active the
/// start button is disabled with an explanatory message instead of silently
/// no-op'ing. Duration defaults to 10 minutes but is user-selectable before
/// starting.
class _TimerControls extends ConsumerStatefulWidget {
  const _TimerControls({required this.sessionId, required this.round});

  final int sessionId;
  final GameRound round;

  @override
  ConsumerState<_TimerControls> createState() => _TimerControlsState();
}

class _TimerControlsState extends ConsumerState<_TimerControls> {
  final _minutesController = TextEditingController(text: '10');

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(gameTimerControllerProvider);
    final notifier = ref.read(gameTimerControllerProvider.notifier);
    final isThisRound = timer?.roundId == widget.round.id;
    final blockedByOther = timer != null && !isThisRound;

    if (isThisRound) {
      final remaining = timer!.remaining;
      final minutes = remaining.inMinutes.toString().padLeft(2, '0');
      final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            timer.isRinging
                ? Icons.alarm
                : timer.isPaused
                    ? Icons.pause_circle_outline
                    : Icons.timer,
            color: timer.isRinging
                ? Colors.red
                : timer.isPaused
                    ? Colors.orange.shade800
                    : Colors.green.shade700,
          ),
          const SizedBox(width: 8),
          Text('$minutes:$seconds', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(width: 12),
          if (!timer.isRinging)
            OutlinedButton(
              onPressed: timer.isPaused ? notifier.resume : notifier.pause,
              child: Text(timer.isPaused ? '재개' : '일시정지'),
            ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: notifier.dismiss,
            child: const Text('타이머 중지'),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 72,
          child: TextField(
            controller: _minutesController,
            enabled: !blockedByOther,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              isDense: true,
              suffixText: '분',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: blockedByOther
              ? null
              : () {
                  final minutes = int.tryParse(_minutesController.text);
                  if (minutes == null || minutes <= 0) return;
                  notifier.start(
                    sessionId: widget.sessionId,
                    roundId: widget.round.id,
                    duration: Duration(minutes: minutes),
                  );
                },
          icon: const Icon(Icons.timer_outlined),
          label: const Text('타이머 시작'),
        ),
        if (blockedByOther) ...[
          const SizedBox(width: 8),
          Text(
            '다른 게임에서 타이머가 진행 중입니다',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}
