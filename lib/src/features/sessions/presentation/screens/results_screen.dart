import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../platform/fullscreen_channel.dart';
import '../../../../platform/fullscreen_state.dart';
import '../../../members/application/members_controller.dart';
import '../../../members/domain/member.dart';
import '../../application/results_jump_request.dart';
import '../../application/session_controller.dart';
import '../widgets/game_full_view.dart';
import '../widgets/games_table_view.dart';
import '../widgets/schedule_grid_view.dart';

enum _ViewMode { table, full, person }

/// Holds the table/full/person-view switch and, for full view, which game
/// is currently focused (defaults to game 1).
class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({
    required this.sessionId,
    this.initialViewMode,
    this.initialRoundId,
    super.key,
  });

  final int sessionId;

  /// Optional deep-link params (e.g. from the running timer badge):
  /// `initialViewMode` selects the starting tab ('full'/'person'/anything
  /// else falls back to table), and `initialRoundId` jumps full view
  /// straight to the game with that round id once rounds are loaded.
  final String? initialViewMode;
  final int? initialRoundId;

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  late _ViewMode _viewMode = switch (widget.initialViewMode) {
    'full' => _ViewMode.full,
    'person' => _ViewMode.person,
    _ => _ViewMode.table,
  };
  int _fullViewIndex = 0;
  bool _resolvedInitialRound = false;

  @override
  void initState() {
    super.initState();
    // Pushed into fullscreenStateProvider (not local state) so other
    // widgets -- namely GameTimerBadge, which must stop navigating on tap
    // once a presentation is running -- see the same fullscreen state.
    FullscreenChannel.setChangeListener((isFullScreen) {
      if (!mounted) return;
      ref.read(fullscreenStateProvider.notifier).set(isFullScreen);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isFullscreen = ref.watch(fullscreenStateProvider);
    // The timer badge sets this when tapped so an already-open results
    // screen for the same session just jumps in place, instead of the
    // badge navigating to (and stacking a redundant copy of) this screen.
    ref.listen(resultsJumpRequestControllerProvider, (previous, next) {
      if (next == null || next.sessionId != widget.sessionId) return;
      final rounds = ref
          .read(sessionControllerProvider(widget.sessionId))
          .value
          ?.rounds;
      final idx = rounds?.indexWhere((r) => r.id == next.roundId) ?? -1;
      if (idx != -1) {
        setState(() {
          _viewMode = _ViewMode.full;
          _fullViewIndex = idx;
          _resolvedInitialRound = true;
        });
      }
      ref.read(resultsJumpRequestControllerProvider.notifier).clear();
    });

    final sessionAsync = ref.watch(sessionControllerProvider(widget.sessionId));
    final membersAsync = ref.watch(membersControllerProvider);

    Widget body;
    if (sessionAsync.isLoading || membersAsync.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (sessionAsync.hasError) {
      body = Center(child: Text('오류: ${sessionAsync.error}'));
    } else if (membersAsync.hasError) {
      body = Center(child: Text('오류: ${membersAsync.error}'));
    } else {
      final session = sessionAsync.requireValue;
      final members = membersAsync.requireValue;
      final memberById = <int, Member>{
        for (final m in members) m.id: m,
        for (final g in session.guests) g.id: g,
      };

      if (session.rounds.isEmpty) {
        body = const Center(child: Text('생성된 게임이 없습니다.'));
      } else {
        switch (_viewMode) {
          case _ViewMode.full:
            if (!_resolvedInitialRound && widget.initialRoundId != null) {
              final idx = session.rounds.indexWhere(
                (r) => r.id == widget.initialRoundId,
              );
              if (idx != -1) _fullViewIndex = idx;
              _resolvedInitialRound = true;
            }
            _fullViewIndex = _fullViewIndex.clamp(0, session.rounds.length - 1);
            body = GameFullView(
              sessionId: widget.sessionId,
              rounds: session.rounds,
              memberById: memberById,
              attendeeIds: session.attendeeIds,
              gameIndex: _fullViewIndex,
              onIndexChanged: (index) => setState(() => _fullViewIndex = index),
              courtLabel: session.labelForCourt,
              isPresentation: isFullscreen,
            );
          case _ViewMode.person:
            body = ScheduleGridView(
              sessionId: widget.sessionId,
              rounds: session.rounds,
              memberById: memberById,
              attendeeIds: session.attendeeIds,
              courtLabel: session.labelForCourt,
            );
          case _ViewMode.table:
            body = GamesTableView(
              sessionId: widget.sessionId,
              rounds: session.rounds,
              memberById: memberById,
              attendeeIds: session.attendeeIds,
              courtLabel: session.labelForCourt,
            );
        }
      }
    }

    Future<void> undo() async {
      try {
        await ref
            .read(sessionControllerProvider(widget.sessionId).notifier)
            .undo();
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('되돌리지 못했습니다: $error')));
      }
    }

    return CallbackShortcuts(
      bindings: {
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyZ): undo,
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ):
            undo,
        if (isFullscreen)
          LogicalKeySet(LogicalKeyboardKey.escape): FullscreenChannel.toggle,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: isFullscreen
              ? null
              : AppBar(
                  title: const Text('게임 결과'),
                  actions: [
                    SegmentedButton<_ViewMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: _ViewMode.table,
                          icon: Icon(Icons.table_chart_outlined),
                          tooltip: '테이블 뷰 (게임별 보기)',
                        ),
                        ButtonSegment(
                          value: _ViewMode.full,
                          icon: Icon(Icons.grid_view),
                          tooltip: '전체 뷰 (게임 하나씩 크게 보기)',
                        ),
                        ButtonSegment(
                          value: _ViewMode.person,
                          icon: Icon(Icons.person_search),
                          tooltip: '인원별 보기 (사람 기준 참여/휴식)',
                        ),
                      ],
                      selected: {_viewMode},
                      onSelectionChanged: (selection) =>
                          setState(() => _viewMode = selection.first),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.undo),
                      tooltip: '되돌리기 (Cmd+Z)',
                      onPressed: undo,
                    ),
                    if (_viewMode == _ViewMode.full) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.fullscreen),
                        tooltip: '전체화면으로 보기 (PPT 스타일)',
                        onPressed: FullscreenChannel.toggle,
                      ),
                    ],
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: '게임 추가 생성',
                      onPressed: () => context.push(
                        '/sessions/${widget.sessionId}/setup?from=results',
                      ),
                    ),
                  ],
                ),
          body: isFullscreen
              ? Stack(
                  children: [
                    Positioned.fill(child: body),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filledTonal(
                        icon: const Icon(Icons.fullscreen_exit),
                        tooltip: '전체화면 종료 (Esc)',
                        onPressed: FullscreenChannel.toggle,
                      ),
                    ),
                  ],
                )
              : body,
        ),
      ),
    );
  }
}
