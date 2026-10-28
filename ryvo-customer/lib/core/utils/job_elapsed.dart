/// Server-anchored service elapsed time (survives app restarts).
///
/// Uses [startedAt] from the API — set when the provider marks the job
/// `in_progress`. Both customer and provider apps stay in sync this way.
Duration serviceElapsedDuration({
  DateTime? startedAt,
  DateTime? now,
}) {
  if (startedAt == null) return Duration.zero;

  final elapsed = (now ?? DateTime.now()).difference(startedAt.toLocal());
  return elapsed.isNegative ? Duration.zero : elapsed;
}

String formatElapsedClock(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
