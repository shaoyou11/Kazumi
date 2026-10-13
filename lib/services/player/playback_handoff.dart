/// State captured before pausing. The caller owns the player/source identity;
/// returning from a native view must never seek a replacement episode.
class PlaybackHandoffState {
  const PlaybackHandoffState({
    required this.position,
    required this.rate,
    required this.playing,
  });
  final Duration position;
  final double rate;
  final bool playing;
}

Future<bool> handoffPlayback({
  required PlaybackHandoffState snapshot,
  required bool Function() isCurrent,
  required Future<void> Function() pause,
  required Future<Map<String, dynamic>?> Function() open,
  required Future<void> Function(Duration) seek,
  required Future<void> Function(double) setRate,
  required Future<void> Function() play,
  required void Function(Duration) onPosition,
}) async {
  var failed = false;
  var position = snapshot.position;
  var playing = snapshot.playing;
  try {
    await pause();
    if (!isCurrent()) return false;
    final result = await open();
    if (!isCurrent()) return false;
    if (result == null) throw StateError('Native player returned no state');
    final seconds = result['position'];
    if (seconds is num && seconds.isFinite && seconds >= 0 && seconds < 1e9) {
      position = Duration(milliseconds: (seconds * 1000).round());
    }
    if (result['playing'] is bool) playing = result['playing'] as bool;
  } catch (_) {
    failed = true;
    // Original position/rate/paused state survive failed native loading.
  }
  if (!isCurrent()) return false;
  await seek(position);
  if (!isCurrent()) return false;
  await setRate(snapshot.rate);
  if (!isCurrent()) return false;
  onPosition(position);
  if (playing) await play();
  return !failed;
}
