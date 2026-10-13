import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/player/playback_handoff.dart';

void main() {
  late List<String> calls;
  late bool current;
  setUp(() {
    calls = [];
    current = true;
  });
  Future<bool> run(
    Future<Map<String, dynamic>?> Function() open, {
    bool playing = true,
  }) => handoffPlayback(
    snapshot: PlaybackHandoffState(
      position: const Duration(seconds: 42),
      rate: 1.5,
      playing: playing,
    ),
    isCurrent: () => current,
    pause: () async {
      calls.add('pause');
    },
    open: open,
    seek: (p) async {
      calls.add('seek:${p.inMilliseconds}');
    },
    setRate: (r) async {
      calls.add('rate:$r');
    },
    play: () async {
      calls.add('play');
    },
    onPosition: (p) {
      calls.add('history:${p.inMilliseconds}');
    },
  );
  test(
    'native position and paused state return without starting playback',
    () async {
      expect(
        await run(() async => {'position': 80.25, 'playing': false}),
        isTrue,
      );
      expect(calls, ['pause', 'seek:80250', 'rate:1.5', 'history:80250']);
    },
  );
  test(
    'failed launch restores original progress, speed and playing state',
    () async {
      expect(await run(() async => throw StateError('failed')), isFalse);
      expect(calls, [
        'pause',
        'seek:42000',
        'rate:1.5',
        'history:42000',
        'play',
      ]);
    },
  );
  test('failure does not unpause an originally paused video', () async {
    expect(await run(() async => null, playing: false), isFalse);
    expect(calls.contains('play'), isFalse);
  });
  test(
    'stale native return cannot seek another episode or write its history',
    () async {
      final native = Completer<Map<String, dynamic>?>();
      final pending = run(() => native.future);
      await Future<void>.delayed(Duration.zero);
      current = false;
      native.complete({'position': 180.0, 'playing': true});
      expect(await pending, isFalse);
      expect(calls, ['pause']);
    },
  );
  for (final value in [double.nan, double.infinity, -5, 1e15, 'bad']) {
    test('invalid native position $value keeps original progress', () async {
      await run(() async => {'position': value, 'playing': false});
      expect(calls, contains('seek:42000'));
    });
  }
}
