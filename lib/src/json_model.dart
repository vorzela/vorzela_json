import 'codec.dart';
import 'pick.dart';

/// Bag-backed model: write getters/setters, get `toJson` / `fromJson` free.
///
/// ```dart
/// class User extends JsonModel {
///   User([super.data]);
///
///   String get name => $str('name');
///   set name(String v) => $set('name', v);
///
///   DateTime? get createdAt => $dateTime('createdAt');
///   set createdAt(DateTime? v) => $set('createdAt', v);
///
///   Role get role => $enum('role', Role.values, Role.member);
///   set role(Role v) => $set('role', v);
/// }
///
/// final u = User({'name': 'Ada', 'createdAt': '2026-01-01T00:00:00Z'});
/// print(u.toJsonString());
/// ```
///
/// No `build_runner`. Nested models use [$model] / [$setModel].
class JsonModel implements JsonEncodable {
  JsonModel([Map<String, dynamic>? data])
      : $data = data == null
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(data);

  /// Raw JSON bag (mutated by setters).
  final Map<String, dynamic> $data;

  // ── read ─────────────────────────────────────────────────────────────

  String $str(String key, [String fallback = '']) => $data.str(key, fallback);
  String? $strOrNull(String key) => $data.strOrNull(key);
  int $int(String key, [int fallback = 0]) => $data.integer(key, fallback);
  int? $intOrNull(String key) => $data.intOrNull(key);
  double $double(String key, [double fallback = 0]) =>
      $data.number(key, fallback);
  bool $bool(String key, [bool fallback = false]) =>
      $data.boolean(key, fallback);
  DateTime? $dateTime(String key) => $data.dateTime(key);
  Duration? $duration(String key) => $data.duration(key);
  Uri? $uri(String key) => $data.uri(key);
  T $enum<T extends Enum>(String key, List<T> values, T fallback) =>
      $data.enumReq(key, values, fallback);
  T? $enumOrNull<T extends Enum>(String key, List<T> values) =>
      $data.enumOrNull(key, values);

  List<T> $list<T>(String key, T Function(dynamic) map) =>
      $data.listOf(key, map);

  T? $model<T extends JsonModel>(
    String key,
    T Function(Map<String, dynamic>) create,
  ) {
    final m = $data.mapOrNull(key);
    if (m == null) return null;
    return create(m);
  }

  // ── write ────────────────────────────────────────────────────────────

  void $set(String key, Object? value) {
    if (value == null) {
      $data.remove(key);
    } else {
      $data[key] = JsonCodecX.encode(value);
    }
  }

  void $setModel(String key, JsonModel? model) {
    if (model == null) {
      $data.remove(key);
    } else {
      $data[key] = model.toJson();
    }
  }

  void $merge(Map<String, dynamic> other) {
    other.forEach((k, v) => $set(k, v));
  }

  // ── codec ────────────────────────────────────────────────────────────

  @override
  Map<String, dynamic> toJson() =>
      Map<String, dynamic>.from(JsonCodecX.encode($data) as Map);

  String toJsonString({bool pretty = false}) =>
      JsonCodecX.encodeString(toJson(), pretty: pretty);

  /// Rehydrate from a JSON map (replaces [$data] keys).
  void loadJson(Map<String, dynamic> json) {
    $data
      ..clear()
      ..addAll(json);
  }

  @override
  String toString() => '$runtimeType(${toJsonString()})';
}
