import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../members/domain/member.dart';
import '../../application/session_controller.dart';
import '../../domain/game_round.dart';
import 'court_capacity.dart';
import 'player_drag_payload.dart';

/// 인원별 보기: a matrix with one row per person and one column per game,
/// so it's easy to scan at a glance who played on which court (or rested)
/// across the whole session -- the mirror image of the table view, which
/// is organized by game rather than by person.
///
/// Any cell can be dragged onto any other cell -- even across different
/// games -- to swap the two players' participation status. e.g. player A
/// has been on a long consecutive-games streak in game 3; drag A's game-3
/// cell onto player B's game-5 cell to trade them: A gets B's old game-5
/// status (maybe a rest) and B takes over A's game-3 court.
///
/// The name column stays fixed while the game columns scroll horizontally;
/// both vertical lists (names, cells) are kept in lockstep via a pair of
/// [ScrollController]s that mirror each other's offset.
class ScheduleGridView extends ConsumerStatefulWidget {
  const ScheduleGridView({
    required this.sessionId,
    required this.rounds,
    required this.memberById,
    required this.attendeeIds,
    required this.courtLabel,
    super.key,
  });

  final int sessionId;
  final List<GameRound> rounds;
  final Map<int, Member> memberById;
  final List<int> attendeeIds;
  final String Function(int courtNumber) courtLabel;

  @override
  ConsumerState<ScheduleGridView> createState() => _ScheduleGridViewState();
}

class _ScheduleGridViewState extends ConsumerState<ScheduleGridView> {
  static const _nameColumnWidth = 120.0;
  // Floor for a game column's width -- with few enough games to fit the
  // available space, columns stretch wider than this to fill it; with more
  // games than fit, columns stay at this minimum and the grid scrolls
  // horizontally instead.
  static const _minGameColumnWidth = 84.0;
  static const _headerHeight = 48.0;
  static const _rowHeight = 44.0;

  final _nameScrollController = ScrollController();
  final _gridScrollController = ScrollController();
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _nameScrollController.addListener(
      () => _sync(from: _nameScrollController, to: _gridScrollController),
    );
    _gridScrollController.addListener(
      () => _sync(from: _gridScrollController, to: _nameScrollController),
    );
  }

  void _sync({required ScrollController from, required ScrollController to}) {
    if (_syncing || !to.hasClients || !from.hasClients) return;
    final target = from.offset.clamp(0.0, to.position.maxScrollExtent);
    if (target == to.offset) return;
    _syncing = true;
    to.jumpTo(target);
    _syncing = false;
  }

  @override
  void dispose() {
    _nameScrollController.dispose();
    _gridScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allIds = <int>{...widget.attendeeIds};
    for (final round in widget.rounds) {
      allIds.addAll(round.restingPlayerIds);
      for (final court in round.courts) {
        allIds.addAll(court.playerIds);
      }
    }

    String nameOf(int id) =>
        widget.memberById[id]?.name ?? Member.unknown(id).name;
    final people = allIds.toList()
      ..sort((a, b) => nameOf(a).compareTo(nameOf(b)));

    if (people.isEmpty || widget.rounds.isEmpty) {
      return const Center(child: Text('참여 인원이나 생성된 게임이 없습니다.'));
    }

    final notifier = ref.read(
      sessionControllerProvider(widget.sessionId).notifier,
    );

    Future<void> swap(
      PlayerDragPayload incoming,
      int roundId,
      int playerId,
    ) async {
      try {
        await notifier.swapPlayers(
          roundIdA: incoming.roundId,
          playerIdA: incoming.playerId,
          roundIdB: roundId,
          playerIdB: playerId,
        );
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장하지 못했습니다: $error')));
      }
    }

    Future<void> reorderGame(int roundIdA, int roundIdB) async {
      try {
        await notifier.swapGamePositions(roundIdA, roundIdB);
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장하지 못했습니다: $error')));
      }
    }

    Future<void> setStatus(int roundId, int playerId, int? courtNumber) async {
      try {
        await notifier.movePlayer(
          roundId: roundId,
          playerId: playerId,
          toCourtNumber: courtNumber,
        );
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장하지 못했습니다: $error')));
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: _nameColumnWidth,
          child: Column(
            children: [
              const _HeaderCell(
                width: _nameColumnWidth,
                height: _headerHeight,
                label: '이름',
              ),
              Expanded(
                child: ListView.builder(
                  controller: _nameScrollController,
                  itemCount: people.length,
                  itemBuilder: (context, index) => _NameCell(
                    height: _rowHeight,
                    name: nameOf(people[index]),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final naturalWidth = _minGameColumnWidth * widget.rounds.length;
              // Stretch columns to fill the available width when there's
              // room for it; once there are more games than fit at the
              // minimum width, fall back to that minimum and let the
              // SingleChildScrollView below take over instead.
              final columnWidth = naturalWidth < constraints.maxWidth
                  ? constraints.maxWidth / widget.rounds.length
                  : _minGameColumnWidth;
              final totalWidth = columnWidth * widget.rounds.length;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: totalWidth,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          for (final round in widget.rounds)
                            _ReorderableHeaderCell(
                              width: columnWidth,
                              height: _headerHeight,
                              label: '게임 ${round.gameNumber}',
                              roundId: round.id,
                              onReorder: reorderGame,
                            ),
                        ],
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: _gridScrollController,
                          itemCount: people.length,
                          itemBuilder: (context, index) {
                            final personId = people[index];
                            return Row(
                              children: [
                                for (final round in widget.rounds)
                                  _ScheduleCell(
                                    key: ValueKey(
                                      'schedule-cell-${round.id}-$personId',
                                    ),
                                    width: columnWidth,
                                    height: _rowHeight,
                                    roundId: round.id,
                                    playerId: personId,
                                    entry: _entryFor(round, personId),
                                    courtOptions: [
                                      for (final court in round.courts)
                                        (
                                          court.courtNumber,
                                          widget.courtLabel(court.courtNumber),
                                        ),
                                    ],
                                    onSwapRequested: (incoming) =>
                                        swap(incoming, round.id, personId),
                                    onSetStatus: (courtNumber) => setStatus(
                                      round.id,
                                      personId,
                                      courtNumber,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  _RoundEntry _entryFor(GameRound round, int personId) {
    for (final court in round.courts) {
      if (court.playerIds.contains(personId)) {
        return _RoundEntry(
          courtLabel: widget.courtLabel(court.courtNumber),
          status: capacityStatusOf(court),
        );
      }
    }
    return const _RoundEntry(
      courtLabel: null,
      status: CourtCapacityStatus.normal,
    );
  }
}

class _RoundEntry {
  const _RoundEntry({required this.courtLabel, required this.status});

  final String? courtLabel;
  final CourtCapacityStatus status;
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.width,
    required this.height,
    required this.label,
  });

  final double width;
  final double height;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

/// A [_HeaderCell] for a game column that can also be dragged onto another
/// game column's header to reorder the games themselves (as opposed to
/// [_ScheduleCell], which reorders *players between* games).
class _ReorderableHeaderCell extends StatelessWidget {
  const _ReorderableHeaderCell({
    required this.width,
    required this.height,
    required this.label,
    required this.roundId,
    required this.onReorder,
  });

  final double width;
  final double height;
  final String label;
  final int roundId;
  final void Function(int roundIdA, int roundIdB) onReorder;

  @override
  Widget build(BuildContext context) {
    final cell = _HeaderCell(width: width, height: height, label: label);

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != roundId,
      onAcceptWithDetails: (details) => onReorder(details.data, roundId),
      builder: (context, candidateData, rejectedData) {
        final highlighting = candidateData.isNotEmpty;
        return Container(
          // Explicit size -- without it this Container only shrink-wraps
          // its child, and any mismatch between that and the fixed-width
          // Row of header cells above the SizedBox-constrained body below
          // is exactly what produced the horizontal RenderFlex overflow
          // when reordering.
          width: width,
          height: height,
          decoration: highlighting
              ? BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                )
              : null,
          child: Draggable<int>(
            data: roundId,
            feedback: Material(
              color: Colors.transparent,
              child: Opacity(opacity: 0.85, child: cell),
            ),
            childWhenDragging: Opacity(opacity: 0.3, child: cell),
            child: cell,
          ),
        );
      },
    );
  }
}

class _NameCell extends StatelessWidget {
  const _NameCell({required this.height, required this.name});

  final double height;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Text(
        name,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _ScheduleCell extends StatelessWidget {
  const _ScheduleCell({
    required this.width,
    required this.height,
    required this.roundId,
    required this.playerId,
    required this.entry,
    required this.courtOptions,
    required this.onSwapRequested,
    required this.onSetStatus,
    super.key,
  });

  final double width;
  final double height;
  final int roundId;
  final int playerId;
  final _RoundEntry entry;

  /// Every court in this round, as (courtNumber, display label) pairs, for
  /// the right-click "set status directly" menu.
  final List<(int, String)> courtOptions;
  final void Function(PlayerDragPayload incoming) onSwapRequested;

  /// Sets this player's status in this round directly (a court number, or
  /// null for resting) -- the right-click alternative to dragging.
  final void Function(int? courtNumber) onSetStatus;

  Future<void> _showContextMenu(
    BuildContext context,
    Offset globalPosition,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    const restSentinel = 0;
    final selected = await showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(globalPosition, globalPosition),
        Offset.zero & overlay.size,
      ),
      items: [
        for (final (courtNumber, label) in courtOptions)
          PopupMenuItem<int>(value: courtNumber, child: Text(label)),
        const PopupMenuItem<int>(value: restSentinel, child: Text('휴식')),
      ],
    );
    if (selected == null) return;
    onSetStatus(selected == restSentinel ? null : selected);
  }

  @override
  Widget build(BuildContext context) {
    final played = entry.courtLabel != null;
    final color = entry.status.color;

    final cellContent = played
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: color.shade100,
              child: FittedBox(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Text(
                    entry.courtLabel!,
                    style: TextStyle(
                      color: color.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          )
        : Text(
            '휴식',
            style: TextStyle(
              color: Theme.of(context).colorScheme.outline,
              fontSize: 12,
            ),
          );

    final draggableContent = Draggable<PlayerDragPayload>(
      data: PlayerDragPayload(roundId: roundId, playerId: playerId),
      // Must be the SAME size as `child` below -- Draggable's default drag
      // anchor is computed from where the pointer landed within `child`,
      // then re-applied to `feedback`'s own top-left corner. If feedback
      // were only as big as `cellContent` while `child` is the full,
      // larger cell box, that offset would be computed against the wrong
      // size and the feedback would visibly drift away from the cursor
      // instead of tracking it.
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: width,
          height: height,
          child: Center(child: Opacity(opacity: 0.85, child: cellContent)),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: cellContent),
      // Fills the whole cell instead of just wrapping `cellContent` --
      // otherwise a resting ("휴식") cell's drag-start hit area would be
      // only its small text label, much smaller than a played cell's
      // CircleAvatar, making it unreliable to grab.
      child: SizedBox(
        width: width,
        height: height,
        child: Center(child: cellContent),
      ),
    );

    return GestureDetector(
      onSecondaryTapDown: (details) =>
          _showContextMenu(context, details.globalPosition),
      child: DragTarget<PlayerDragPayload>(
        onWillAcceptWithDetails: (details) =>
            details.data.roundId != roundId ||
            details.data.playerId != playerId,
        onAcceptWithDetails: (details) => onSwapRequested(details.data),
        builder: (context, candidateData, rejectedData) {
          final highlighting = candidateData.isNotEmpty;
          return Container(
            width: width,
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: highlighting
                  ? Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.12)
                  : entry.status != CourtCapacityStatus.normal
                  ? entry.status.color.withValues(alpha: 0.08)
                  : null,
              border: Border(
                left: BorderSide(color: Theme.of(context).dividerColor),
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: draggableContent,
          );
        },
      ),
    );
  }
}
