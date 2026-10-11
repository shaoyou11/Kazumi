// Keep the middle third for play/pause and ignore invalid geometry.
int doubleTapSeekDirection(double x, double width) {
  if (!x.isFinite || !width.isFinite || width <= 0 || x < 0 || x > width) return 0;
  if (x < width / 3) return -1;
  if (x > width * 2 / 3) return 1;
  return 0;
}
