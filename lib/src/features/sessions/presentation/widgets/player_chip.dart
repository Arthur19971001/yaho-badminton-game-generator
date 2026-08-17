import 'package:flutter/material.dart';

import '../../../members/domain/gender.dart';
import '../../../members/domain/member.dart';
import 'player_drag_payload.dart';

/// A draggable chip representing one player, shown inside a court or the
/// resting bench. Drag-and-drop reassignment picks this up and drops it on
/// another [DragTarget].
///
/// When [onSwapRequested] is given, this chip doubles as a drop target: a
/// chip dropped directly onto this one swaps the two players' participation
/// status instead of just being added alongside (which is what dropping
/// into the surrounding court/bench's general area still does).
///
/// [consecutiveStreak], when positive, is shown as a small caption below
/// the chip -- how many games in a row (ending at this one) this player has
/// been assigned to a court without a rest in between.
class PlayerChip extends StatelessWidget {
  const PlayerChip({
    required this.member,
    required this.roundId,
    this.onSwapRequested,
    this.consecutiveStreak,
    super.key,
  });

  final Member member;
  final int roundId;
  final void Function(PlayerDragPayload incoming)? onSwapRequested;
  final int? consecutiveStreak;

  @override
  Widget build(BuildContext context) {
    final draggable = Draggable<PlayerDragPayload>(
      data: PlayerDragPayload(roundId: roundId, playerId: member.id),
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        child: _chip(context, dragging: false),
      ),
      childWhenDragging: _chip(context, dragging: true),
      child: _chip(context, dragging: false),
    );

    final content = onSwapRequested == null
        ? draggable
        : DragTarget<PlayerDragPayload>(
            onWillAcceptWithDetails: (details) =>
                details.data.playerId != member.id,
            onAcceptWithDetails: (details) => onSwapRequested!(details.data),
            builder: (context, candidateData, rejectedData) {
              final highlighting = candidateData.isNotEmpty;
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: highlighting
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        )
                      : null,
                ),
                child: draggable,
              );
            },
          );

    if (consecutiveStreak == null || consecutiveStreak! <= 0) return content;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        content,
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '$consecutiveStreak연속',
            style: TextStyle(
              fontSize: 10,
              color: consecutiveStreak! >= 3
                  ? Colors.orange.shade800
                  : Theme.of(context).colorScheme.outline,
              fontWeight: consecutiveStreak! >= 3 ? FontWeight.bold : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, {required bool dragging}) {
    if (member.isUnknown) {
      return Opacity(
        opacity: dragging ? 0.3 : 1,
        child: Chip(
          avatar: const CircleAvatar(
            backgroundColor: Colors.grey,
            child: Icon(Icons.question_mark, size: 14, color: Colors.white),
          ),
          label: Text(member.name),
          backgroundColor: Colors.grey.shade200,
        ),
      );
    }

    final color = member.gender == Gender.male
        ? Colors.blue.shade100
        : Colors.pink.shade100;

    return Opacity(
      opacity: dragging ? 0.3 : 1,
      child: Chip(
        avatar: CircleAvatar(
          backgroundColor: color,
          child: Text(
            member.gender.label,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        label: Text(member.name),
      ),
    );
  }
}
