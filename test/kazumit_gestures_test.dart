import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/player/double_tap_seek.dart';

void main() {
  test('left and right seek, middle and exact boundaries preserve pause', () {
    expect(doubleTapSeekDirection(99, 300), -1);
    expect(doubleTapSeekDirection(100, 300), 0);
    expect(doubleTapSeekDirection(150, 300), 0);
    expect(doubleTapSeekDirection(200, 300), 0);
    expect(doubleTapSeekDirection(201, 300), 1);
    expect(doubleTapSeekDirection(0, 300), -1);
    expect(doubleTapSeekDirection(300, 300), 1);
  });
  test('invalid and stale layout coordinates do not seek', () {
    for (final pair in [[-1.0, 300.0], [301.0, 300.0], [0.0, 0.0], [double.nan, 300.0], [1.0, double.infinity]]) {
      expect(doubleTapSeekDirection(pair[0], pair[1]), 0);
    }
  });
}
