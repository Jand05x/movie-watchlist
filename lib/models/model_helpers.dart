DateTime? parseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);

  try {
    return (value as dynamic).toDate() as DateTime?;
  } catch (_) {
    return null;
  }
}
