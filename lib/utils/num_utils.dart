/// Safe numeric parsing utilities for API responses.
/// Hostinger MySQL API may return numeric columns as strings.
/// Use these instead of `(x as num?)?.toDouble()`.
library;

double toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  if (v is bool) return v ? 1.0 : 0.0;
  return double.tryParse(v.toString().trim()) ?? 0.0;
}

double? toDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().trim());
}

int toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString().trim()) ?? 0;
}

int? toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString().trim());
}
