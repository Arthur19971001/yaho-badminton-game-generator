import 'package:flutter/material.dart';

import '../../../members/domain/member.dart';
import '../../domain/court_assignment.dart';
import 'court_capacity.dart';
import 'player_chip.dart';
import 'player_drag_payload.dart';

/// One court's drop target within the table view. Flagged (amber/red)
/// when the court doesn't have exactly 4 players so the user notices a bad
/// drag-and-drop edit.
class CourtSlot extends StatelessWidget {
  const CourtSlot({
    required this.roundId,
    required this.court,
    required this.label,
    required this.memberById,
    required this.onDrop,
    required this.onSwap,
    this.onDelete,
    this.streakByPlayerId = const {},
    super.key,
  });

  final int roundId;
  final CourtAssignment court;
  final String label;
  final Map<int, Member> memberById;
  final void Function(int playerId) onDrop;
  final void Function(PlayerDragPayload incoming, int targetPlayerId) onSwap;

  /// Deletes this court from its game. Null hides the delete button (not
  /// currently used anywhere, but keeps this widget usable without it).
  final VoidCallback? onDelete;
  final Map<int, int> streakByPlayerId;

  @override
  Widget build(BuildContext context) {
    final status = capacityStatusOf(court);

    return DragTarget<PlayerDragPayload>(
      onWillAcceptWithDetails: (details) =>
          !court.playerIds.contains(details.data.playerId),
      onAcceptWithDetails: (details) => onDrop(details.data.playerId),
      builder: (context, candidateData, rejectedData) {
        final highlighting = candidateData.isNotEmpty;
        return Container(
          constraints: const BoxConstraints(minWidth: 220, minHeight: 96),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: status != CourtCapacityStatus.normal
                ? status.color.withValues(alpha: 0.12)
                : highlighting
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                : null,
            border: Border.all(
              color: status != CourtCapacityStatus.normal
                  ? status.color
                  : Theme.of(context).colorScheme.outlineVariant,
              width: status != CourtCapacityStatus.normal ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(width: 6),
                  Text(
                    '${court.playerIds.length}/4',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  if (status.warningIcon case final icon?) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: status.label,
                      child: Icon(icon, color: status.color.shade700, size: 16),
                    ),
                  ],
                  if (onDelete != null) ...[
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      tooltip: '이 코트 삭제',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: onDelete,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final playerId in court.playerIds)
                    PlayerChip(
                      member: memberById[playerId] ?? Member.unknown(playerId),
                      roundId: roundId,
                      consecutiveStreak: streakByPlayerId[playerId],
                      onSwapRequested: (incoming) => onSwap(incoming, playerId),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
