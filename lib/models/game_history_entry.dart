/// One row of the persisted game-history list (see `GameState.history`):
/// a snapshot of a finished game, either won or abandoned via "New game"
/// after at least one move.
class GameHistoryEntry {
  /// Wall-clock date/time the game ended (won or abandoned).
  final DateTime endedAt;

  /// Active elapsed time for the game, excluding any time spent paused.
  final Duration duration;

  /// Total moves made (tableau-to-tableau moves plus stock deals).
  final int moveCount;

  /// True only when the game ended by completing all 8 sequences.
  final bool won;

  /// Always true for any entry that made it into the history list — this
  /// project doesn't (yet) log partial/in-progress entries, but the field
  /// exists so the stats screen can show a "Finished" column as requested.
  final bool finished;

  const GameHistoryEntry({
    required this.endedAt,
    required this.duration,
    required this.moveCount,
    required this.won,
    required this.finished,
  });

  Map<String, dynamic> toJson() => {
        'endedAt': endedAt.toIso8601String(),
        'durationMs': duration.inMilliseconds,
        'moveCount': moveCount,
        'won': won,
        'finished': finished,
      };

  factory GameHistoryEntry.fromJson(Map<String, dynamic> json) {
    return GameHistoryEntry(
      endedAt: DateTime.tryParse(json['endedAt'] as String? ?? '') ?? DateTime.now(),
      duration: Duration(milliseconds: (json['durationMs'] as num?)?.toInt() ?? 0),
      moveCount: (json['moveCount'] as num?)?.toInt() ?? 0,
      won: json['won'] as bool? ?? false,
      finished: json['finished'] as bool? ?? true,
    );
  }
}

/// Formats a [Duration] as `m:ss` (e.g. `4:07`) or, once it reaches an
/// hour, `h:mm:ss` (e.g. `1:04:07`). Shared by the game screen's live
/// clock and the stats screen's per-entry duration column.
String formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final secondsStr = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    final minutesStr = minutes.toString().padLeft(2, '0');
    return '$hours:$minutesStr:$secondsStr';
  }
  return '$minutes:$secondsStr';
}
