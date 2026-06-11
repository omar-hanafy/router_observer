/// Signature for a value redactor applied to route arguments and results
/// before they are attached to navigation events.
///
/// Implementations must be pure, fast, and must never throw. Return any
/// JSON-encodable value.
typedef Redactor = Object? Function(
  Object? value, {
  required Set<String> maskKeys,
  required int maxChars,
});

/// The default set of key fragments masked by [defaultRedactor].
///
/// Matching is case-insensitive and uses substring containment, so `apiKey`,
/// `API_KEY`, and `refreshToken` are all masked.
const Set<String> defaultMaskKeys = <String>{
  'token',
  'password',
  'secret',
  'email',
  'authorization',
  'apikey',
  'api_key',
};

/// The placeholder written in place of masked values.
const String maskedValue = '***';

const int _maxIterableItems = 50;
const int _maxDepth = 6;

/// A conservative, PII-safe [Redactor] used by default.
///
/// Behavior:
///
/// - Map values whose key contains any entry of [maskKeys]
///   (case-insensitive) are replaced with [maskedValue].
/// - Maps and iterables are converted recursively, capped at
///   50 items per iterable and 6 levels of nesting.
/// - Strings, numbers, and booleans are kept; strings longer than
///   [maxChars] are truncated with a `...(n more)` suffix.
/// - Any other object is stringified and truncated.
/// - Never throws: a value whose `toString` fails becomes
///   `<unserializable:Type>`.
Object? defaultRedactor(
  Object? value, {
  required Set<String> maskKeys,
  required int maxChars,
}) =>
    _redact(value, maskKeys: maskKeys, maxChars: maxChars, depth: 0);

Object? _redact(
  Object? value, {
  required Set<String> maskKeys,
  required int maxChars,
  required int depth,
}) {
  try {
    if (value == null) return null;
    if (depth >= _maxDepth) return _truncate(value, maxChars);

    if (value is Map) {
      final Map<String, Object?> out = <String, Object?>{};
      for (final MapEntry<dynamic, dynamic> entry in value.entries) {
        final String key = entry.key.toString();
        final String lower = key.toLowerCase();
        final bool mask = maskKeys.any((k) => lower.contains(k.toLowerCase()));
        out[key] = mask
            ? maskedValue
            : _redact(
                entry.value,
                maskKeys: maskKeys,
                maxChars: maxChars,
                depth: depth + 1,
              );
      }
      return out;
    }

    if (value is Iterable) {
      return value
          .take(_maxIterableItems)
          .map(
            (Object? e) => _redact(
              e,
              maskKeys: maskKeys,
              maxChars: maxChars,
              depth: depth + 1,
            ),
          )
          .toList(growable: false);
    }

    if (value is num || value is bool) return value;

    return _truncate(value, maxChars);
  } catch (_) {
    return '<unserializable:${value.runtimeType}>';
  }
}

Object _truncate(Object value, int maxChars) {
  final String s = value.toString();
  if (s.length <= maxChars) return s;
  return '${s.substring(0, maxChars)}...(${s.length - maxChars} more)';
}
