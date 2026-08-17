import 'package:flutter/material.dart';

import '../../../members/domain/member.dart';
import '../../domain/game_round.dart';

/// Total games played so far by each id who has ever appeared in a round
/// (playing or resting), across every generated round passed in.
Map<int, int> computePlayCounts(List<GameRound> rounds) {
  final counts = <int, int>{};
  for (final r in rounds) {
    for (final id in r.restingPlayerIds) {
      counts.putIfAbsent(id, () => 0);
    }
    for (final court in r.courts) {
      for (final id in court.playerIds) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
  }
  return counts;
}

/// A collapsible row of "이름 N게임" chips, one per attendee, so it's
/// obvious at a glance whether play counts are staying balanced -- fold it
/// away when it's just taking up space. Shared by the table view and the
/// full view so it looks the same in both.
class PlayCountSummary extends StatelessWidget {
  const PlayCountSummary({required this.rounds, required this.memberById, super.key});

  final List<GameRound> rounds;
  final Map<int, Member> memberById;

  @override
  Widget build(BuildContext context) {
    final playCounts = computePlayCounts(rounds);
    if (playCounts.isEmpty) return const SizedBox.shrink();

    final sortedIds = playCounts.keys.toList()
      ..sort((a, b) =>
          (memberById[a]?.name ?? '').compareTo(memberById[b]?.name ?? ''));

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          title: Text('참여 횟수', style: Theme.of(context).textTheme.labelLarge),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final id in sortedIds)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      '${memberById[id]?.name ?? Member.unknown(id).name} ${playCounts[id]}게임',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
