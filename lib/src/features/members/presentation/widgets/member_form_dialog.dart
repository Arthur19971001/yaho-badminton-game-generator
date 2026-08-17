import 'package:flutter/material.dart';

import '../../domain/gender.dart';
import '../../domain/member.dart';

class MemberFormResult {
  const MemberFormResult(this.name, this.gender);

  final String name;
  final Gender gender;
}

/// Add/edit dialog for a club member (or a session guest, reusing the same
/// name+gender form). Pass [existing] to pre-fill for edits, and [title] to
/// override the default "회원 추가"/"회원 수정" heading -- e.g. callers
/// adding a guest should pass "게스트 추가" so it's not mistaken for adding
/// a permanent club member.
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

class _MemberFormDialog extends StatefulWidget {
  const _MemberFormDialog({this.existing, this.title});

  final Member? existing;
  final String? title;

  @override
  State<_MemberFormDialog> createState() => _MemberFormDialogState();
}

class _MemberFormDialogState extends State<_MemberFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late Gender _gender = widget.existing?.gender ?? Gender.male;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      MemberFormResult(_nameController.text.trim(), _gender),
    );
  }
}
