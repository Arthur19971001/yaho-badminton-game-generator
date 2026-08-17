import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../application/sessions_controller.dart';
import '../../domain/game_session.dart';

class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  static final _dateFormat = DateFormat('yyyy년 M월 d일 (E)', 'ko_KR');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('세션')),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('오류: $error')),
        data: (sessions) {
          if (sessions.isEmpty) {
            return const Center(
              child: Text('등록된 세션이 없습니다. 우측 하단 + 버튼으로 날짜를 추가하세요.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: sessions.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                _SessionTile(session: sessions[index], dateFormat: _dateFormat),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'sessionsScreenFab',
        onPressed: () => _createSession(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _createSession(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    if (!context.mounted) return;

    final session = await ref
        .read(sessionsControllerProvider.notifier)
        .createSession(picked);
    if (!context.mounted) return;
    context.push('/sessions/${session.id}/attendance');
  }
}

class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.session, required this.dateFormat});

  final GameSession session;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.event_outlined),
      title: Text(dateFormat.format(session.date)),
      subtitle: Text(
        '참여 인원 ${session.attendeeIds.length}명 · 생성된 게임 ${session.rounds.length}개',
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('세션 삭제'),
              content: Text('${dateFormat.format(session.date)} 세션을 삭제하시겠습니까?'),
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
          if (confirmed == true) {
            await ref
                .read(sessionsControllerProvider.notifier)
                .deleteSession(session.id);
          }
        },
      ),
      onTap: () {
        final path = session.rounds.isEmpty
            ? '/sessions/${session.id}/attendance'
            : '/sessions/${session.id}/results';
        context.push(path);
      },
    );
  }
}
