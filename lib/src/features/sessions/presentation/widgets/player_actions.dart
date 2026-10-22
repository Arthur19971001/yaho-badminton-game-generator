import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../members/domain/member.dart';
import '../../application/session_controller.dart';
import '../../domain/courtmate_counts.dart';
import '../../domain/game_round.dart';

/// Shared click/right-click behavior for a player's name anywhere on the
/// results screen (table view chips, full view court cards, person view):
/// a left click shows who they've shared a court with so far, and a right
/// click offers that plus "사용자 빼기".
class PlayerActions {
  const PlayerActions({
    required this.sessionId,
    required this.rounds,
    required this.memberById,
    required this.attendeeIds,
  });

  final int sessionId;
  final List<GameRound> rounds;
  final Map<int, Member> memberById;
  final List<int> attendeeIds;

  Member memberOf(int id) => memberById[id] ?? Member.unknown(id);

  /// Opens the "같이 친 횟수" dialog for [playerId], counting games
  /// 1..(throughIndex + 1) -- i.e. up to and including the game that was
  /// clicked.
  Future<void> showCourtmates(
    BuildContext context, {
    required int playerId,
    required int throughIndex,
  }) {
    final last = throughIndex.clamp(0, rounds.length - 1);
    final counts = courtmateCounts(
      rounds,
      playerId: playerId,
      throughIndex: last,
    );
    // Everyone attending today, plus anyone who shared a court with them
    // but has since been removed from the attendee list.
    final others = {...attendeeIds, ...counts.keys}..remove(playerId);
    final sorted = others.toList()
      ..sort((a, b) {
        final byCount = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
        if (byCount != 0) return byCount;
        return memberOf(a).name.compareTo(memberOf(b).name);
      });
    final throughGameNumber = rounds[last].gameNumber;

    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${memberOf(playerId).name} · 같이 친 횟수'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                throughGameNumber == 1
                    ? '게임 1 기준 · 같은 코트에서 친 횟수'
                    : '게임 1~$throughGameNumber 기준 · 같은 코트에서 친 횟수',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              if (sorted.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('함께 참여한 인원이 없습니다.'),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: sorted.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final id = sorted[index];
                      final count = counts[id] ?? 0;
                      return ListTile(
                        dense: true,
                        title: Text(memberOf(id).name),
                        trailing: Text(
                          '$count회',
                          style: TextStyle(
                            fontWeight: count > 0 ? FontWeight.bold : null,
                            color: count > 0
                                ? null
                                : Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  /// Right-click menu for a player: "같이 친 횟수 보기" / "사용자 빼기".
  Future<void> showMenuAt(
    BuildContext context,
    WidgetRef ref,
    Offset globalPosition, {
    required int playerId,
    required int throughIndex,
  }) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<Object>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(globalPosition, globalPosition),
        Offset.zero & overlay.size,
      ),
      items: playerMenuItems,
    );
    if (selected == null || !context.mounted) return;
    await handleMenuSelection(
      context,
      ref,
      selected,
      playerId: playerId,
      throughIndex: throughIndex,
    );
  }

  /// The menu entries [showMenuAt] shows -- exposed so a view with its own
  /// right-click menu (the person view) can append them to it.
  static const playerMenuItems = <PopupMenuEntry<Object>>[
    PopupMenuItem(
      value: PlayerMenuAction.courtmates,
      child: ListTile(
        leading: Icon(Icons.people_alt_outlined),
        title: Text('같이 친 횟수 보기'),
        dense: true,
        contentPadding: EdgeInsets.zero,
      ),
    ),
    PopupMenuItem(
      value: PlayerMenuAction.remove,
      child: ListTile(
        leading: Icon(Icons.person_remove_outlined),
        title: Text('사용자 빼기'),
        dense: true,
        contentPadding: EdgeInsets.zero,
      ),
    ),
  ];

  Future<void> handleMenuSelection(
    BuildContext context,
    WidgetRef ref,
    Object? selected, {
    required int playerId,
    required int throughIndex,
  }) async {
    switch (selected) {
      case PlayerMenuAction.courtmates:
        await showCourtmates(
          context,
          playerId: playerId,
          throughIndex: throughIndex,
        );
      case PlayerMenuAction.remove:
        await confirmRemove(context, ref, playerId: playerId);
    }
  }

  /// "사용자 빼기": asks from which game number on to remove [playerId]
  /// (0 = keep every existing game as-is), then removes them from those
  /// games and from today's attendee list.
  Future<void> confirmRemove(
    BuildContext context,
    WidgetRef ref, {
    required int playerId,
  }) async {
    final maxGameNumber = rounds.isEmpty
        ? 0
        : rounds.map((r) => r.gameNumber).reduce((a, b) => a > b ? a : b);
    final fromGameNumber = await showDialog<int>(
      context: context,
      builder: (context) => _RemovePlayerDialog(
        name: memberOf(playerId).name,
        maxGameNumber: maxGameNumber,
      ),
    );
    if (fromGameNumber == null || !context.mounted) return;

    try {
      await ref
          .read(sessionControllerProvider(sessionId).notifier)
          .removePlayerFromGames(
            playerId: playerId,
            fromGameNumber: fromGameNumber,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fromGameNumber == 0
                ? '${memberOf(playerId).name} 님을 참여 인원에서 뺐습니다. (기존 게임은 그대로)'
                : '${memberOf(playerId).name} 님을 게임 $fromGameNumber부터 모든 게임에서 뺐습니다.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장하지 못했습니다: $error')));
    }
  }
}

/// Entries of the player right-click menu built by [PlayerActions].
enum PlayerMenuAction { courtmates, remove }

class _RemovePlayerDialog extends StatefulWidget {
  const _RemovePlayerDialog({required this.name, required this.maxGameNumber});

  final String name;
  final int maxGameNumber;

  @override
  State<_RemovePlayerDialog> createState() => _RemovePlayerDialogState();
}

class _RemovePlayerDialogState extends State<_RemovePlayerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController(text: '0');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.name} 빼기'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '입력한 번호의 게임부터 마지막 게임까지 모든 게임에서 빠집니다. '
                '빠진 자리는 비워두고 경고로 표시됩니다.\n'
                '0이면 기존 게임은 그대로 두고, 참여 인원에서만 빠져 이후 '
                '추가 생성되는 게임에 배정되지 않습니다.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: '몇 번 게임부터 뺄까요?',
                  suffixText: '번 게임부터',
                  helperText: '0 ~ ${widget.maxGameNumber}',
                ),
                validator: (value) {
                  final n = int.tryParse(value?.trim() ?? '');
                  if (n == null || n < 0 || n > widget.maxGameNumber) {
                    return '0 ~ ${widget.maxGameNumber} 사이로 입력하세요';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _submit, child: const Text('빼기')),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(int.parse(_controller.text.trim()));
  }
}
