String formatEth(double value) {
  if (value.isNaN || value.isInfinite || value <= 0) {
    return '0.00';
  }

  // Always use 2 decimal places for consistency
  return value.toStringAsFixed(2);
}
