/// Drag payload carried by a player chip in the results table view.
/// In table view, drops can target a different game/round: the payload's
/// [playerId] is treated as "which player to place" and the drop target
/// decides that player's status for *its own* round.
///
/// Carries the round's stable [roundId] rather than its display-only
/// gameNumber, since deleting/reordering games renumbers gameNumber for
/// every remaining round -- a payload captured at drag-start could
/// otherwise go stale (or silently target the wrong round) if a delete or
/// reorder lands mid-gesture.
class PlayerDragPayload {
  const PlayerDragPayload({required this.roundId, required this.playerId});

  final int roundId;
  final int playerId;
}
