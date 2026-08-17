import 'package:flutter/material.dart';

import '../../domain/court_assignment.dart';

/// Whether a court ended up with exactly 4 players (normal), fewer (under
/// -- e.g. mid-drag before someone's been placed), or more (over -- a bad
/// drag-and-drop edit). Used to render the same warning look everywhere a
/// court shows up: the table view, the full view, and the per-person grid.
enum CourtCapacityStatus { normal, under, over }

CourtCapacityStatus capacityStatusOf(CourtAssignment court) {
  if (court.isOverCapacity) return CourtCapacityStatus.over;
  if (court.playerIds.length < CourtAssignment.capacity) {
    return CourtCapacityStatus.under;
  }
  return CourtCapacityStatus.normal;
}

extension CourtCapacityStatusStyle on CourtCapacityStatus {
  /// Base color for borders/backgrounds/badges -- pair with `.shadeNNN` or
  /// `withValues(alpha:)` at the call site for the exact tone needed.
  MaterialColor get color => switch (this) {
        CourtCapacityStatus.normal => Colors.green,
        CourtCapacityStatus.under => Colors.orange,
        CourtCapacityStatus.over => Colors.red,
      };

  /// Non-null only when something is actually wrong, so callers can do
  /// `if (status.warningIcon case final icon?) Icon(icon)`.
  IconData? get warningIcon => switch (this) {
        CourtCapacityStatus.normal => null,
        CourtCapacityStatus.under => Icons.warning_amber_rounded,
        CourtCapacityStatus.over => Icons.error,
      };

  String get label => switch (this) {
        CourtCapacityStatus.normal => '정상',
        CourtCapacityStatus.under => '인원 부족',
        CourtCapacityStatus.over => '인원 초과',
      };
}
