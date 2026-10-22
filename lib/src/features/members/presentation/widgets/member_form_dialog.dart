import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../grades/application/grades_controller.dart';
import '../../../grades/domain/grade.dart';
import '../../domain/gender.dart';
import '../../domain/member.dart';

class MemberFormResult {
  const MemberFormResult(this.name, this.gender, this.gradeId);

  final String name;
  final Gender gender;

  /// Always one of the defined grades; null only if no grades exist at all.
  final int? gradeId;
}

/// Add/edit dialog for a club member (or a session guest, reusing the same
/// name+gender+grade form). Pass [existing] to pre-fill for edits, and
/// [title] to override the default "회원 추가"/"회원 수정" heading -- e.g.
/// callers adding a guest should pass "게스트 추가" so it's not mistaken for
/// adding a permanent club member.
Future<MemberFormResult?> showMemberFormDialog(
  BuildContext context, {
  Member? existing,
  String? title,
}) {
  return showDialog<MemberFormResult>(
    context: context,
    builder: (context) => _MemberFormDialog(existing: existing, title: title),
  );
}

class _MemberFormDialog extends ConsumerStatefulWidget {
  const _MemberFormDialog({this.existing, this.title});

  final Member? existing;
  final String? title;

  @override
  ConsumerState<_MemberFormDialog> createState() => _MemberFormDialogState();
}

class _MemberFormDialogState extends ConsumerState<_MemberFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late Gender _gender = widget.existing?.gender ?? Gender.male;
  late int? _gradeId = widget.existing?.gradeId;
  List<Grade> _grades = const [];

  /// The grade shown/saved: the chosen one, or -- for a new member, or one
  /// whose grade is unset or was since deleted -- the lowest grade, which
  /// is what an ungraded member counts as anyway.
  int? get _effectiveGradeId => _grades.any((g) => g.id == _gradeId)
      ? _gradeId
      : _grades.lastOrNull?.id;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sorted highest points first, so the last one is the lowest grade.
    _grades = ref.watch(gradesControllerProvider).value ?? const <Grade>[];

    return AlertDialog(
      title: Text(
        widget.title ?? (widget.existing == null ? '회원 추가' : '회원 수정'),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: '이름'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? '이름을 입력하세요' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            SegmentedButton<Gender>(
              segments: const [
                ButtonSegment(value: Gender.male, label: Text('남')),
                ButtonSegment(value: Gender.female, label: Text('여')),
              ],
              selected: {_gender},
              onSelectionChanged: (selection) =>
                  setState(() => _gender = selection.first),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _effectiveGradeId,
              key: ValueKey('grade-${_grades.length}-$_effectiveGradeId'),
              decoration: const InputDecoration(labelText: '급수'),
              items: [
                for (final grade in _grades)
                  DropdownMenuItem(
                    value: grade.id,
                    child: Text('${grade.name} (${grade.points}점)'),
                  ),
              ],
              onChanged: (value) => setState(() => _gradeId = value),
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
      MemberFormResult(_nameController.text.trim(), _gender, _effectiveGradeId),
    );
  }
}
