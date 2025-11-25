String formatEth(double value) {
  if (value.isNaN || value.isInfinite || value <= 0) {
    return '0';
  }

  if (value >= 1) {
    return value.toStringAsFixed(1);
  }

  if (value >= 0.01) {
    return value.toStringAsFixed(3);
  }

  return value.toStringAsFixed(6);
}
