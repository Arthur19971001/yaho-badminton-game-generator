import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/members_controller.dart';
import '../../domain/gender.dart';
import '../../domain/korean_search.dart';
import '../../domain/member.dart';
import '../widgets/member_form_dialog.dart';

class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('회원 관리')),
      body: Column(
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
          Expanded(
            child: membersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('오류: $error')),
              data: (members) {
                if (members.isEmpty) {
                  return const Center(
                    child: Text('등록된 회원이 없습니다. 우측 하단 + 버튼으로 추가하세요.'),
                  );
                }
                final filtered = members
                    .where((m) => matchesKoreanQuery(m.name, _query))
                    .toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('검색 결과가 없습니다.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _MemberTile(member: filtered[index]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'membersScreenFab',
        onPressed: _addMember,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _addMember() async {
    final result = await showMemberFormDialog(context);
    if (result == null) return;
    await ref
        .read(membersControllerProvider.notifier)
        .addMember(result.name, result.gender);
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: member.gender == Gender.male
            ? Colors.blue.shade100
            : Colors.pink.shade100,
        child: Text(member.gender.label),
      ),
      title: Text(member.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final result =
                  await showMemberFormDialog(context, existing: member);
              if (result == null) return;
              await ref.read(membersControllerProvider.notifier).updateMember(
                    member.copyWith(name: result.name, gender: result.gender),
                  );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('회원 삭제'),
                  content: Text('${member.name} 님을 삭제하시겠습니까?'),
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
                    .read(membersControllerProvider.notifier)
                    .deleteMember(member.id);
              }
            },
          ),
        ],
      ),
    );
  }
}
