import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../members/application/members_controller.dart';
import '../../../members/domain/gender.dart';
import '../../../members/domain/korean_search.dart';
import '../../../members/domain/member.dart';
import '../../../members/presentation/widgets/member_form_dialog.dart';
import '../../application/session_controller.dart';
import '../../domain/game_session.dart';

/// "오늘 참여하는 사람" picker: choose today's attendees out of the full club
/// roster, plus any one-off guests added just for this session. Selections
/// are saved immediately so leaving and coming back to this session later
/// keeps the picks.
///
/// Reached two ways: from the sessions list when a session has no games yet
/// (first-time pick, [returnToSetup] true, moves forward to game setup on
/// save), or from the game setup screen's "참여 인원 수정" action when adding
/// more games to a session that already has some (edit mode, pops back to
/// setup on save instead).
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({
    required this.sessionId,
    this.returnToSetup = true,
    super.key,
  });

  final int sessionId;
  final bool returnToSetup;

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  Set<int>? _selected;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionControllerProvider(widget.sessionId));
    final membersAsync = ref.watch(membersControllerProvider);

    Widget listBody;
    if (sessionAsync.isLoading || membersAsync.isLoading) {
      listBody = const Center(child: CircularProgressIndicator());
    } else if (sessionAsync.hasError) {
      listBody = Center(child: Text('오류: ${sessionAsync.error}'));
    } else if (membersAsync.hasError) {
      listBody = Center(child: Text('오류: ${membersAsync.error}'));
    } else {
      listBody =
          _buildBody(sessionAsync.requireValue, membersAsync.requireValue);
    }

    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '이름 검색 (초성 검색 가능, 예: ㄱㅇ)',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: '검색어 지우기',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(child: listBody),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('참여 인원 선택'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: '게스트 추가',
            onPressed: () => _addGuest(context),
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _selected == null ? null : () => _save(context),
            child: Text(widget.returnToSetup ? '저장하고 게임 설정으로' : '저장'),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(GameSession session, List<Member> members) {
    _selected ??= session.attendeeIds.toSet();

    if (members.isEmpty && session.guests.isEmpty) {
      return const Center(child: Text('먼저 회원 관리 화면에서 회원을 등록하거나 게스트를 추가하세요.'));
    }

    final filteredMembers =
        members.where((m) => matchesKoreanQuery(m.name, _query)).toList();
    final filteredGuests = session.guests
        .where((g) => matchesKoreanQuery(g.name, _query))
        .toList();

    if (filteredMembers.isEmpty && filteredGuests.isEmpty) {
      return const Center(child: Text('검색 결과가 없습니다.'));
    }

    return ListView(
      key: const Key('attendanceRosterList'),
      children: [
        for (final member in filteredMembers) _memberTile(member),
        if (filteredGuests.isNotEmpty) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              '게스트',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          for (final guest in filteredGuests) _guestTile(guest),
        ],
      ],
    );
  }

  Widget _memberTile(Member member) {
    final checked = _selected!.contains(member.id);
    return CheckboxListTile(
      value: checked,
      title: Text(member.name),
      secondary: CircleAvatar(
        backgroundColor: member.gender == Gender.male
            ? Colors.blue.shade100
            : Colors.pink.shade100,
        child: Text(member.gender.label),
      ),
      onChanged: (value) => setState(() {
        if (value ?? false) {
          _selected!.add(member.id);
        } else {
          _selected!.remove(member.id);
        }
      }),
    );
  }

  Widget _guestTile(Member guest) {
    final checked = _selected!.contains(guest.id);
    return CheckboxListTile(
      value: checked,
      title: Text(guest.name),
      secondary: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: guest.gender == Gender.male
                ? Colors.blue.shade100
                : Colors.pink.shade100,
            child: Text(guest.gender.label),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: '게스트 삭제',
            onPressed: () => _removeGuest(guest.id),
          ),
        ],
      ),
      onChanged: (value) => setState(() {
        if (value ?? false) {
          _selected!.add(guest.id);
        } else {
          _selected!.remove(guest.id);
        }
      }),
    );
  }

  Future<void> _removeGuest(int guestId) async {
    await ref
        .read(sessionControllerProvider(widget.sessionId).notifier)
        .removeGuest(guestId);
    setState(() => _selected?.remove(guestId));
  }

  Future<void> _addGuest(BuildContext context) async {
    final result = await showMemberFormDialog(context, title: '게스트 추가');
    if (result == null) return;
    await ref
        .read(sessionControllerProvider(widget.sessionId).notifier)
        .addGuest(result.name, result.gender, gradeId: result.gradeId);
    if (!context.mounted) return;
    final latest = ref.read(sessionControllerProvider(widget.sessionId)).value;
    if (latest != null) {
      setState(() => _selected = latest.attendeeIds.toSet());
    }
  }

  Future<void> _save(BuildContext context) async {
    await ref
        .read(sessionControllerProvider(widget.sessionId).notifier)
        .updateAttendees(_selected!.toList());
    if (!context.mounted) return;
    if (widget.returnToSetup) {
      context.push('/sessions/${widget.sessionId}/setup');
    } else {
      context.pop();
    }
  }
}
