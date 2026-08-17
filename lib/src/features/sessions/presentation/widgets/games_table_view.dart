import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../members/domain/member.dart';
import '../../application/session_controller.dart';
import '../../domain/game_round.dart';
import 'court_slot.dart';
import 'play_count_summary.dart';
import 'player_chip.dart';
import 'player_drag_payload.dart';
import 'player_streak.dart';

/// 데이터 뷰: every generated game as a card, courts laid out with
/// drag-and-drop player reassignment, and the game cards themselves
/// reorderable via the drag handle.
class GamesTableView extends ConsumerWidget {
  const GamesTableView({
    required this.sessionId,
    required this.rounds,
    required this.memberById,
    required this.courtLabel,
    super.key,
  });

  final int sessionId;
  final List<GameRound> rounds;
  final Map<int, Member> memberById;
  final String Function(int courtNumber) courtLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(sessionControllerProvider(sessionId).notifier);

    return Column(
      children: [
        PlayCountSummary(rounds: rounds, memberById: memberById),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.all(16),
            itemCount: rounds.length,
            onReorder: (oldIndex, newIndex) => _runOrShowError(
              context,
              () => notifier.reorderGames(oldIndex, newIndex),
            ),
            itemBuilder: (context, index) {
              final round = rounds[index];
              final streaks = {
                for (final playerId in round.courts.expand((c) => c.playerIds))
                  playerId: consecutiveGamesPlayed(rounds, index, playerId),
              };

              void swap(PlayerDragPayload incoming, int targetId) =>
                  _runOrShowError(
                    context,
                    () => notifier.swapPlayers(
                      roundIdA: incoming.roundId,
                      playerIdA: incoming.playerId,
                      roundIdB: round.id,
                      playerIdB: targetId,
                    ),
                  );

              return Card(
                key: ValueKey(round.id),
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ReorderableDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_indicator),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '게임 ${round.gameNumber}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: '이 게임 삭제',
                            onPressed: () => _confirmDelete(
                              context,
                              notifier,
                              roundId: round.id,
                              gameNumber: round.gameNumber,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final court in round.courts)
                            CourtSlot(
                              roundId: round.id,
                              court: court,
                              label: courtLabel(court.courtNumber),
                              memberById: memberById,
                              streakByPlayerId: streaks,
                              onDrop: (playerId) => _runOrShowError(
                                context,
                                () => notifier.movePlayer(
                                  roundId: round.id,
                                  playerId: playerId,
                                  toCourtNumber: court.courtNumber,
                                ),
                              ),
                              onSwap: swap,
                              onDelete: () => _confirmDeleteCourt(
                                context,
                                notifier,
                                roundId: round.id,
                                courtNumber: court.courtNumber,
                                courtLabel: courtLabel(court.courtNumber),
                                gameNumber: round.gameNumber,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _RestingBench(
                        roundId: round.id,
                        restingPlayerIds: round.restingPlayerIds,
                        memberById: memberById,
                        onDrop: (playerId) => _runOrShowError(
                          context,
                          () => notifier.movePlayer(
                            roundId: round.id,
                            playerId: playerId,
                            toCourtNumber: null,
                          ),
                        ),
                        onSwap: swap,
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

  Future<void> _confirmDelete(
    BuildContext context,
    SessionController notifier, {
    required int roundId,
    required int gameNumber,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('게임 삭제'),
        content: Text('게임 $gameNumber을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _runOrShowError(context, () => notifier.deleteGame(roundId));
  }

  Future<void> _confirmDeleteCourt(
    BuildContext context,
    SessionController notifier, {
    required int roundId,
    required int courtNumber,
    required String courtLabel,
    required int gameNumber,
  }) async {
    // 0 = cancel, 1 = this game only, 2 = every game.
    final choice = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('코트 삭제'),
        content: Text(
          '$courtLabel 코트를 삭제하시겠습니까?\n'
          '게임 $gameNumber에서만 삭제할지, 전체 게임에서 삭제할지 선택하세요.\n'
          '배정된 인원은 쉬는 인원으로 이동하고, 코트가 없어지는 게임은 함께 삭제됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(0),
            child: const Text('취소'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(1),
            child: Text('게임 $gameNumber에서만 삭제'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(2),
            child: const Text('전체 게임에서 삭제'),
          ),
        ],
      ),
    );
    if (choice == null || choice == 0 || !context.mounted) return;
    await _runOrShowError(
      context,
      () => choice == 2
          ? notifier.deleteCourtFromAllGames(courtNumber)
          : notifier.deleteCourt(roundId: roundId, courtNumber: courtNumber),
    );
  }
}

/// Runs a fire-and-forget controller mutation but surfaces any failure (e.g.
/// a database write error) as a snackbar instead of silently swallowing it.
Future<void> _runOrShowError(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('저장하지 못했습니다: $error')));
  }
}

class _RestingBench extends StatelessWidget {
  const _RestingBench({
    required this.roundId,
    required this.restingPlayerIds,
    required this.memberById,
    required this.onDrop,
    required this.onSwap,
  });

  final int roundId;
  final List<int> restingPlayerIds;
  final Map<int, Member> memberById;
  final void Function(int playerId) onDrop;
  final void Function(PlayerDragPayload incoming, int targetPlayerId) onSwap;

  @override
  Widget build(BuildContext context) {
    return DragTarget<PlayerDragPayload>(
      onWillAcceptWithDetails: (details) =>
          !restingPlayerIds.contains(details.data.playerId),
      onAcceptWithDetails: (details) => onDrop(details.data.playerId),
      builder: (context, candidateData, rejectedData) {
        final highlighting = candidateData.isNotEmpty;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: highlighting
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: Text(
                  '쉬는 인원',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (restingPlayerIds.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '없음',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    for (final playerId in restingPlayerIds)
                      PlayerChip(
                        member:
                            memberById[playerId] ?? Member.unknown(playerId),
                        roundId: roundId,
                        onSwapRequested: (incoming) =>
                            onSwap(incoming, playerId),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
