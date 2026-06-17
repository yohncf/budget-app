DateTime parseDateTime(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is String) return DateTime.parse(value);
  if (value is DateTime) return value;
  try {
    return (value as dynamic).toDate() as DateTime;
  } catch (_) {
    return DateTime.now();
  }
}
