import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../members/presentation/widgets/member_form_dialog.dart';
import '../../application/session_controller.dart';

/// 게임생성화면: choose how many games to generate, how many courts are
/// booked, name each court, and whether gender balance should be enforced,
/// then run the generator. If the session already has games, this appends
/// more using the same generator (which factors in the existing history).
class GameSetupScreen extends ConsumerStatefulWidget {
  const GameSetupScreen({
    required this.sessionId,
    this.fromResults = false,
    super.key,
  });

  final int sessionId;

  /// True when reached via the results screen's "게임 추가 생성" action --
  /// in that case an existing Results screen is already open underneath,
  /// so we pop back to it instead of pushing a brand-new one on top.
  final bool fromResults;

  @override
  ConsumerState<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends ConsumerState<GameSetupScreen> {
  static const _maxCourts = 50;

  final _gamesController = TextEditingController(text: '4');
  final _courtsController = TextEditingController(text: '2');
  final List<TextEditingController> _courtNameControllers = [];
  bool _genderBalance = false;
  bool _gradeBalance = false;
  bool _initialized = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _courtsController.addListener(_onCourtsFieldChanged);
  }

  @override
  void dispose() {
    _gamesController.dispose();
    _courtsController.dispose();
    for (final controller in _courtNameControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onCourtsFieldChanged() {
    final count = (int.tryParse(_courtsController.text.trim()) ?? 0).clamp(
      0,
      _maxCourts,
    );
    if (count == _courtNameControllers.length) return;
    setState(() => _resizeCourtNameControllers(count));
  }

  void _resizeCourtNameControllers(int count) {
    while (_courtNameControllers.length < count) {
      _courtNameControllers.add(TextEditingController());
    }
    while (_courtNameControllers.length > count) {
      _courtNameControllers.removeLast().dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionControllerProvider(widget.sessionId));

    return Scaffold(
      appBar: AppBar(title: const Text('게임 생성 설정')),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('오류: $error')),
        data: (session) {
          if (!_initialized) {
            // Setting .text notifies listeners synchronously, and
            // _onCourtsFieldChanged calls setState -- detach it first so
            // this initial sync doesn't trigger a "setState during build".
            _courtsController.removeListener(_onCourtsFieldChanged);
            _courtsController.text = session.courts.toString();
            _courtsController.addListener(_onCourtsFieldChanged);
            _genderBalance = session.genderBalance;
            _gradeBalance = session.gradeBalance;
            _resizeCourtNameControllers(session.courts);
            for (var i = 0; i < _courtNameControllers.length; i++) {
              _courtNameControllers[i].text = i < session.courtNames.length
                  ? session.courtNames[i]
                  : '';
            }
            _initialized = true;
          }

          final existingCount = session.rounds.length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (existingCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      '이미 $existingCount개의 게임이 생성되어 있습니다. '
                      '아래 설정으로 게임을 추가 생성하면 기존 기록을 참고해 최적화됩니다.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                Row(
                  children: [
                    Text(
                      '참여 인원: ${session.attendeeIds.length}명',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => context.push(
                        '/sessions/${widget.sessionId}/attendance?editing=true',
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('참여 인원 수정'),
                    ),
                    TextButton.icon(
                      onPressed: () => _addGuest(context),
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('게스트 추가'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _gamesController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: existingCount > 0 ? '추가로 생성할 게임 수' : '생성할 게임 수',
                    suffixText: '게임',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _courtsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '예약한 코트 수',
                    suffixText: '개',
                  ),
                ),
                if (_courtNameControllers.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    '코트 이름 (선택)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '비워두면 "코트 N"으로 표시됩니다. 예: 코트 1을 실제 코트 번호인 "19번"으로.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < _courtNameControllers.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: _courtNameControllers[i],
                        decoration: InputDecoration(
                          labelText: '코트 ${i + 1} 이름',
                          hintText: '코트 ${i + 1}',
                        ),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _saveCourtNames(context),
                      child: const Text('코트 이름 저장'),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text('성별 밸런스', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '켜면 각 코트가 항상 남2:여2, 남자만, 또는 여자만으로 구성됩니다. '
                  '끄면 성별과 무관하게 무작위로 배정합니다.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('예')),
                    ButtonSegment(value: false, label: Text('아니오')),
                  ],
                  selected: {_genderBalance},
                  onSelectionChanged: (selection) =>
                      setState(() => _genderBalance = selection.first),
                ),
                const SizedBox(height: 16),
                Text('급수 밸런스', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '켜면 각 코트의 4명을 2명씩 팀으로 나눴을 때 두 팀의 급수 점수 합이 '
                  '비슷하도록 배정합니다. (예: A+C = B+B) 성별 밸런스와 함께 켤 수 있고, '
                  '급수가 없는 회원은 가장 낮은 급수로 계산합니다.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('예')),
                    ButtonSegment(value: false, label: Text('아니오')),
                  ],
                  selected: {_gradeBalance},
                  onSelectionChanged: (selection) =>
                      setState(() => _gradeBalance = selection.first),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => _addEmptyGame(context),
                        child: const Text('빈 게임 추가'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _generate(
                                context,
                                session.attendeeIds.length,
                              ),
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(existingCount > 0 ? '게임 추가 생성' : '게임 생성'),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '빈 게임 추가는 코트만 준비된 빈 게임을 만들어, 결과 화면에서 인원을 직접 '
                    '드래그해 배치할 수 있게 합니다.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _addGuest(BuildContext context) async {
    final result = await showMemberFormDialog(context, title: '게스트 추가');
    if (result == null) return;
    await ref
        .read(sessionControllerProvider(widget.sessionId).notifier)
        .addGuest(result.name, result.gender, gradeId: result.gradeId);
  }

  Future<void> _saveCourtNames(BuildContext context) async {
    final names = _courtNameControllers.map((c) => c.text.trim()).toList();
    await ref
        .read(sessionControllerProvider(widget.sessionId).notifier)
        .updateCourtNames(names);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('코트 이름이 저장되었습니다.')));
  }

  Future<void> _generate(BuildContext context, int attendeeCount) async {
    final games = int.tryParse(_gamesController.text.trim());
    final courts = int.tryParse(_courtsController.text.trim());

    if (games == null || games < 1) {
      _showError(context, '게임 수를 올바르게 입력하세요.');
      return;
    }
    if (courts == null || courts < 1) {
      _showError(context, '코트 수를 올바르게 입력하세요.');
      return;
    }
    if (attendeeCount < 4) {
      _showError(context, '참여 인원이 4명 미만이면 게임을 생성할 수 없습니다.');
      return;
    }

    await _run(context, () async {
      final notifier = ref.read(
        sessionControllerProvider(widget.sessionId).notifier,
      );
      await notifier.updateCourtNames(
        _courtNameControllers.map((c) => c.text.trim()).toList(),
      );
      await notifier.generateGames(
        courts: courts,
        gamesToGenerate: games,
        genderBalance: _genderBalance,
        gradeBalance: _gradeBalance,
      );
    });
  }

  Future<void> _addEmptyGame(BuildContext context) async {
    final courts = int.tryParse(_courtsController.text.trim());
    if (courts == null || courts < 1) {
      _showError(context, '코트 수를 올바르게 입력하세요.');
      return;
    }

    await _run(context, () async {
      final notifier = ref.read(
        sessionControllerProvider(widget.sessionId).notifier,
      );
      await notifier.updateCourtNames(
        _courtNameControllers.map((c) => c.text.trim()).toList(),
      );
      await notifier.addEmptyGame(courts: courts);
    });
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!context.mounted) return;
      if (widget.fromResults) {
        context.pop();
      } else {
        context.push('/sessions/${widget.sessionId}/results');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
