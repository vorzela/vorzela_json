import 'dart:typed_data';

import 'codec.dart';
import 'pick.dart';

/// Bag-backed model: JSON map in → typed getters out. No codegen.
///
/// ```dart
/// // API sent: {"name":"Ada","role":"admin"}
/// final user = User({'name': 'Ada', 'role': 'admin'});
/// print(user.role); // Role.admin   ← matched from Role.values by name
///
/// user.role = Role.member;          ← you assign a case when writing
/// print(user.toJson());             // {"name":"Ada","role":"member"}
/// ```
///
/// Nested models: [$model] / [$setModel]. Files: see [JsonFile].
///
/// The model wraps its map by reference (see the constructor), so nested
/// models read via [$model] / [$models] share the parent's data — mutating
/// one is visible through the other.
class JsonModel implements JsonEncodable {
  /// Wraps [data] directly — no defensive copy. This is the fast, common
  /// path: a freshly `jsonDecode`-d body (or a sub-map pulled out for a
  /// nested model) isn't referenced anywhere else, so there's nothing to
  /// protect by cloning it. Because the map is shared, mutating a nested
  /// model (`user.photo?.name = 'x'`) is immediately visible through the
  /// parent (`user.toJson()`), and vice versa.
  ///
  /// If you're wrapping a map you still hold a reference to elsewhere and
  /// want the model to be independent of later changes to it, use
  /// [JsonModel.copyOf] instead.
  ///
  /// This is always safe for real JSON: `jsonDecode()` (and this package's
  /// own [JsonCodecX.decodeMap]) always hand back a proper
  /// `Map<String, dynamic>` that accepts any value type, no matter what
  /// values happened to be in the JSON. The one case to watch for is
  /// wrapping a Dart map *literal* you built and stored in a variable by
  /// hand (not passed straight into `fromJson(...)`), where every value
  /// happens to share a type — Dart can infer that as e.g.
  /// `Map<String, String>`, and a later `$set` with a differently-typed
  /// value (a `DateTime`, an `int`, ...) would throw at runtime. Use
  /// [JsonModel.copyOf] for those, since it normalizes the copy to
  /// `Map<String, dynamic>`.
  JsonModel([Map<String, dynamic>? data])
      : $data = data ?? <String, dynamic>{};

  /// Same as `Model(json)` — explicit name for Dio/http call sites.
  JsonModel.fromJson(Map<String, dynamic> json) : this(json);

  /// Like the default constructor, but clones [data] first so this model is
  /// fully isolated from any other holder of that map. Use this when [data]
  /// is a long-lived map you keep mutating elsewhere and don't want that
  /// bleeding into the model (or vice versa).
  JsonModel.copyOf(Map<String, dynamic> data)
      : this(Map<String, dynamic>.from(data));

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
  Uint8List? $bytes(String key) => $data.bytes(key);
  BigInt? $bigInt(String key) => $data.bigInt(key);

  /// Read an enum from JSON.
  ///
  /// - [among] is **every** case: pass `Role.values` (the lookup table).
  /// - JSON `"admin"` becomes `Role.admin` by matching `.name`.
  /// - [or] is only used when the key is missing or the string is unknown —
  ///   it is **not** “the value of the field”.
  ///
  /// ```dart
  /// // JSON: { "role": "admin" }
  /// Role get role => $enumAt('role', among: Role.values, or: Role.member);
  /// //                           ^^^^^^^^^^^              ^^^^^^^^^^^^^^^
  /// //                           all cases to search      default if absent
  ///
  /// // To *set* admin:
  /// set role(Role v) => $set('role', v);  // user.role = Role.admin;
  /// ```
  T $enumAt<T extends Enum>(
    String key, {
    required List<T> among,
    required T or,
  }) =>
      $data.enumReq(key, among, or);

  /// Like [$enumAt] but returns `null` when missing/unknown (no default).
  T? $enumAtOrNull<T extends Enum>(
    String key, {
    required List<T> among,
  }) =>
      $data.enumOrNull(key, among);

  /// Deprecated alias — prefer [$enumAt] (clearer parameter names).
  T $enum<T extends Enum>(String key, List<T> values, T fallback) =>
      $enumAt(key, among: values, or: fallback);

  T? $enumOrNull<T extends Enum>(String key, List<T> values) =>
      $enumAtOrNull(key, among: values);

  List<T> $list<T>(String key, T Function(dynamic) map) =>
      $data.listOf(key, map);

  List<T> $models<T extends JsonModel>(
    String key,
    T Function(Map<String, dynamic>) create,
  ) {
    final v = $data[key];
    if (v is! List) return const [];
    // Build the model list directly instead of materializing an
    // intermediate List<Map> first — halves the allocations for arrays of
    // nested models.
    return [
      for (final e in v)
        create(
          e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map),
        ),
    ];
  }

  T? $model<T extends JsonModel>(
    String key,
    T Function(Map<String, dynamic>) create,
  ) {
    final m = $data.mapOrNull(key);
    if (m == null) return null;
    return create(m);
  }

  T $modelReq<T extends JsonModel>(
    String key,
    T Function(Map<String, dynamic>) create,
  ) =>
      create($data.mapReq(key));

  JsonFile? $file(String key) => $model(key, JsonFile.new);

  List<JsonFile> $files(String key) => $models(key, JsonFile.new);

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
      // Share the nested model's bag so later mutations on [model] stay
      // visible on this parent (same contract as [$model] reads).
      $data[key] = model.$data;
    }
  }

  void $merge(Map<String, dynamic> other) {
    other.forEach((k, v) => $set(k, v));
  }

  // ── codec ────────────────────────────────────────────────────────────

  @override
  Map<String, dynamic> toJson() {
    // JsonCodecX.encode(Map) already builds a fresh Map<String, dynamic>
    // (see codec.dart), so re-wrapping it in Map.from() was a second,
    // pointless full copy on every single serialize call.
    final encoded = JsonCodecX.encode($data);
    return encoded is Map<String, dynamic>
        ? encoded
        : Map<String, dynamic>.from(encoded as Map);
  }

  String toJsonString({bool pretty = false}) =>
      JsonCodecX.encodeString(toJson(), pretty: pretty);

  /// Replace bag contents from a decoded JSON object.
  ///
  /// Clears and [Map.addAll]s into the existing bag (does not swap the map
  /// identity), so nested models that already share this bag keep working.
  void loadJson(Map<String, dynamic> json) {
    $data
      ..clear()
      ..addAll(json);
  }

  @override
  String toString() => '$runtimeType(${toJsonString()})';
}

/// File metadata as APIs usually return it in JSON (not a dart:io [File]).
///
/// ```json
/// {
///   "name": "clip.mp4",
///   "url": "https://cdn/clip.mp4",
///   "mimeType": "video/mp4",
///   "size": 1024,
///   "bytes": "<base64 optional>"
/// }
/// ```
///
/// Multipart upload still uses Dio `FormData` / `MultipartFile` — [JsonFile]
/// is for **JSON fields that describe a file** (URL, name, size, embedded bytes).
class JsonFile extends JsonModel {
  JsonFile([super.data]);
  JsonFile.fromJson(super.json) : super.fromJson();
  JsonFile.copyOf(super.data) : super.copyOf();

  String get name => $str('name');
  set name(String v) => $set('name', v);

  /// Local path when the API echoes one (rare on mobile).
  String? get path => $strOrNull('path') ?? $strOrNull('filePath');
  set path(String? v) => $set('path', v);

  /// Public / signed URL.
  String? get url => $strOrNull('url') ?? $strOrNull('href');
  set url(String? v) => $set('url', v);

  Uri? get uri {
    final u = $uri('url') ?? $uri('href');
    if (u != null) return u;
    final p = path;
    return p != null ? Uri.tryParse(p) : null;
  }

  String? get mimeType =>
      $strOrNull('mimeType') ?? $strOrNull('mime') ?? $strOrNull('contentType');
  set mimeType(String? v) => $set('mimeType', v);

  int? get size => $intOrNull('size') ?? $intOrNull('length');
  set size(int? v) => $set('size', v);

  /// Optional base64 payload inside JSON (small files / avatars).
  Uint8List? get bytes => $bytes('bytes') ?? $bytes('content') ?? $bytes('data');
  set bytes(Uint8List? v) => $set('bytes', v);

  bool get hasUrl => url != null && url!.isNotEmpty;
  bool get hasBytes => bytes != null && bytes!.isNotEmpty;
}
