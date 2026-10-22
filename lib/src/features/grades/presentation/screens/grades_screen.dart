import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/grades_controller.dart';
import '../../domain/grade.dart';

/// 급수 관리: the admin-editable list of grades and how many points each is
/// worth for grade-balanced game generation. Persisted in the `grades`
/// table, so changes carry over to every future session.
class GradesScreen extends ConsumerWidget {
  const GradesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradesAsync = ref.watch(gradesControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('급수 관리')),
      body: gradesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('오류: $error')),
        data: (grades) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                '급수 밸런스로 게임을 생성하면 2명씩 팀을 나눴을 때 두 팀의 점수 합이 '
                '비슷해지도록 배정합니다. (예: A10 + C6 = B8 + B8 = 16점)\n'
                '급수가 없는 회원은 가장 낮은 급수의 점수로 계산합니다.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Expanded(
              child: grades.isEmpty
                  ? const Center(
                      child: Text('등록된 급수가 없습니다. 우측 하단 + 버튼으로 추가하세요.'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: grades.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) =>
                          _GradeTile(grade: grades[index]),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'gradesScreenFab',
        tooltip: '급수 추가',
        onPressed: () async {
          final result = await _showGradeFormDialog(context);
          if (result == null) return;
          await ref
              .read(gradesControllerProvider.notifier)
              .addGrade(result.name, result.points);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _GradeTile extends ConsumerWidget {
  const _GradeTile({required this.grade});

  final Grade grade;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: CircleAvatar(child: Text(grade.name)),
      title: Text('${grade.name}급'),
      subtitle: Text('${grade.points}점'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '급수 수정',
            onPressed: () async {
              final result =
                  await _showGradeFormDialog(context, existing: grade);
              if (result == null) return;
              await ref.read(gradesControllerProvider.notifier).updateGrade(
                    grade.copyWith(name: result.name, points: result.points),
                  );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '급수 삭제',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('급수 삭제'),
                  content: Text(
                    '${grade.name}급을 삭제하시겠습니까?\n'
                    '이 급수였던 회원은 삭제되지 않고 가장 낮은 급수로 배정됩니다.',
                  ),
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
                    .read(gradesControllerProvider.notifier)
                    .deleteGrade(grade.id);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _GradeFormResult {
  const _GradeFormResult(this.name, this.points);

  final String name;
  final int points;
}

Future<_GradeFormResult?> _showGradeFormDialog(
  BuildContext context, {
  Grade? existing,
}) {
  return showDialog<_GradeFormResult>(
    context: context,
    builder: (context) => _GradeFormDialog(existing: existing),
  );
}

class _GradeFormDialog extends StatefulWidget {
  const _GradeFormDialog({this.existing});

  final Grade? existing;

  @override
  State<_GradeFormDialog> createState() => _GradeFormDialogState();
}

class _GradeFormDialogState extends State<_GradeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.existing?.name ?? '');
  late final _pointsController = TextEditingController(
    text: widget.existing?.points.toString() ?? '',
  );

  @override
  void dispose() {
    _nameController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '급수 추가' : '급수 수정'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '급수 이름',
                hintText: '예: A',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? '급수 이름을 입력하세요'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pointsController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '점수',
                suffixText: '점',
              ),
              validator: (value) => int.tryParse(value?.trim() ?? '') == null
                  ? '점수를 숫자로 입력하세요'
                  : null,
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _submit, child: const Text('저장')),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _GradeFormResult(
        _nameController.text.trim(),
        int.parse(_pointsController.text.trim()),
      ),
    );
  }
}
