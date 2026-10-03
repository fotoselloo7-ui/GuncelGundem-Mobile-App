/// Tolerant JSON primitives shared only by the blog data contract.
abstract final class BlogJson {
  static Map<String, dynamic> map(dynamic value) =>
      value is Map<String, dynamic> ? value : const {};
  static List<Map<String, dynamic>> maps(dynamic value) => value is List
      ? value.whereType<Map<String, dynamic>>().toList()
      : const [];
  static String? string(dynamic value) =>
      value is String ? value : (value is num ? value.toString() : null);
  static int integer(dynamic value, [int fallback = 0]) => value is num
      ? value.toInt()
      : int.tryParse(string(value) ?? '') ?? fallback;
  static List<String> strings(dynamic value) =>
      value is List ? value.map((v) => string(v) ?? '').toList() : const [];
}
