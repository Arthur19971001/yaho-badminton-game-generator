import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'results_jump_request.g.dart';

/// A one-shot request to jump an already-mounted [ResultsScreen] (for
/// [sessionId]) to full view on [roundId] in place, instead of navigating
/// to it -- used by the timer badge when tapped while the user is already
/// viewing that session's results, so it doesn't stack a redundant page
/// on top of itself (which would leave a stray page behind on back-nav).
class ResultsJumpRequest {
  const ResultsJumpRequest({required this.sessionId, required this.roundId});

  final int sessionId;
  final int roundId;
}

@riverpod
class ResultsJumpRequestController extends _$ResultsJumpRequestController {
  @override
  ResultsJumpRequest? build() => null;

  void request(int sessionId, int roundId) {
    state = ResultsJumpRequest(sessionId: sessionId, roundId: roundId);
  }

  void clear() {
    state = null;
  }
}
