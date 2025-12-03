String formatEth(double value) {
  if (value.isNaN || value.isInfinite || value <= 0) {
    return '0.00';
  }

  // Always use 2 decimal places for consistency
  return value.toStringAsFixed(2);
}

/// Get current DateTime in Malaysia timezone (UTC+8)
DateTime getMalaysiaTime() {
  return DateTime.now().toUtc().add(const Duration(hours: 8));
}

/// Format DateTime to Malaysia time string
String formatMalaysiaTime(DateTime dateTime) {
  final malaysiaTime = dateTime.toUtc().add(const Duration(hours: 8));
  return malaysiaTime.toString().replaceAll('.000', '');
}
