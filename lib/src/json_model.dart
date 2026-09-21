import 'dart:typed_data';

import 'codec.dart';
import 'model_list.dart';
import 'path.dart';
import 'pick.dart';

/// Bag-backed model: JSON map in → typed getters out. No codegen.
///
/// Nested models share the parent's map. Deep fields: prefer [$strAt] /
/// [$at] so you never allocate intermediate models. Large arrays: [$models]
/// returns a lazy [JsonModelList].
class JsonModel implements JsonEncodable {
  /// Wraps [data] by reference — no copy. See [JsonModel.copyOf] to isolate.
  JsonModel([Map<String, dynamic>? data])
      : $data = data ?? <String, dynamic>{};

  JsonModel.fromJson(Map<String, dynamic> json) : this(json);

  JsonModel.copyOf(Map<String, dynamic> data)
      : this(Map<String, dynamic>.from(data));

  /// Raw JSON bag (mutated by setters). Already JSON-safe when filled via
  /// [$set] / network `jsonDecode`.
  final Map<String, dynamic> $data;

  /// Soft cache of nested [$model] / [$file] wrappers (same map identity).
  Map<String, JsonModel>? _nest;

  // ── read (one key) ───────────────────────────────────────────────────

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

  T $enumAt<T extends Enum>(
    String key, {
    required List<T> among,
    required T or,
  }) =>
      $data.enumReq(key, among, or);

  T? $enumAtOrNull<T extends Enum>(
    String key, {
    required List<T> among,
  }) =>
      $data.enumOrNull(key, among);

  T $enum<T extends Enum>(String key, List<T> values, T fallback) =>
      $enumAt(key, among: values, or: fallback);

  T? $enumOrNull<T extends Enum>(String key, List<T> values) =>
      $enumAtOrNull(key, among: values);

  List<T> $list<T>(String key, T Function(dynamic) map) =>
      $data.listOf(key, map);

  // ── deep path (no intermediate models) ───────────────────────────────

  /// Walk `a.b.0.c` or `['a','b',0,'c']` without building nested models.
  Object? $at(Object path) => jsonAt($data, path);

  Map<String, dynamic>? $mapAt(Object path) => jsonMapAt($data, path);

  String $strAt(Object path, [String fallback = '']) =>
      jsonStrAt($data, path, fallback);

  String? $strAtOrNull(Object path) => jsonStrAtOrNull($data, path);

  int $intAt(Object path, [int fallback = 0]) =>
      jsonIntAt($data, path, fallback);

  int? $intAtOrNull(Object path) => jsonIntAtOrNull($data, path);

  bool $boolAt(Object path, [bool fallback = false]) =>
      jsonBoolAt($data, path, fallback);

  double $doubleAt(Object path, [double fallback = 0]) =>
      jsonDoubleAt($data, path, fallback);

  /// Lightweight nested bag view (shares map). Prefer [$strAt] when you
  /// only need one field under a deep path.
  JsonModel? $view(String key) {
    final m = $data.mapOrNull(key);
    if (m == null) return null;
    return JsonModel(m);
  }

  // ── nested models / lists ────────────────────────────────────────────

  /// Lazy [JsonModelList]. Caps the in-memory model cache for huge arrays
  /// (default: cache all if ≤256 items, else 64 hot slots).
  JsonModelList<T> $models<T extends JsonModel>(
    String key,
    T Function(Map<String, dynamic>) create, {
    int? maxCached,
  }) {
    final v = $data[key];
    if (v is! List) return JsonModelList.empty(create);
    return JsonModelList(v, create, maxCached: maxCached);
  }

  /// Nested model — **cached** while the underlying map identity stays put.
  T? $model<T extends JsonModel>(
    String key,
    T Function(Map<String, dynamic>) create,
  ) {
    final m = $data.mapOrNull(key);
    if (m == null) {
      _nest?.remove(key);
      return null;
    }
    final hit = _nest?[key];
    if (hit is T && identical(hit.$data, m)) return hit;
    final created = create(m);
    (_nest ??= <String, JsonModel>{})[key] = created;
    return created;
  }

  T $modelReq<T extends JsonModel>(
    String key,
    T Function(Map<String, dynamic>) create,
  ) {
    final v = $model(key, create);
    if (v == null) throw FormatException('Missing object "$key"');
    return v;
  }

  JsonFile? $file(String key) => $model(key, JsonFile.new);

  JsonModelList<JsonFile> $files(String key, {int? maxCached}) =>
      $models(key, JsonFile.new, maxCached: maxCached);

  // ── write ────────────────────────────────────────────────────────────

  void $set(String key, Object? value) {
    _nest?.remove(key);
    if (value == null) {
      $data.remove(key);
      return;
    }
    // Fast path: values that are already JSON-safe — skip encode tree walk.
    if (value is String || value is num || value is bool) {
      $data[key] = value;
      return;
    }
    if (value is Enum) {
      $data[key] = value.name;
      return;
    }
    $data[key] = JsonCodecX.encode(value);
  }

  void $setModel(String key, JsonModel? model) {
    _nest?.remove(key);
    if (model == null) {
      $data.remove(key);
    } else {
      $data[key] = model.$data;
      (_nest ??= <String, JsonModel>{})[key] = model;
    }
  }

  void $setModels(String key, JsonModelList<JsonModel>? list) {
    _nest?.remove(key);
    if (list == null) {
      $data.remove(key);
    } else {
      $data[key] = list.raw;
    }
  }

  /// Set a deep path, creating intermediate maps as needed.
  void $setAt(Object path, Object? value) {
    final encoded = value == null ||
            value is String ||
            value is num ||
            value is bool
        ? value
        : value is Enum
            ? value.name
            : JsonCodecX.encode(value);
    $data.setAt(path, encoded);
    // Best-effort: drop direct-child nest cache if path starts with that key.
    final segs = path is List
        ? path
        : path.toString().split('.');
    if (segs.isNotEmpty) {
      _nest?.remove(segs.first.toString());
    }
  }

  void $merge(Map<String, dynamic> other) {
    other.forEach((k, v) => $set(k, v));
  }

  // ── codec ────────────────────────────────────────────────────────────

  /// Zero-copy view of the bag for Dio/`http` when values were set via
  /// [$set] or came from `jsonDecode`. Do not mutate if you still use the model.
  Map<String, dynamic> get $json => $data;

  /// Deep-encode (DateTime, custom `toJson`, …). Prefer [$json] for
  /// already-safe bags — avoids a full tree copy on every request.
  @override
  Map<String, dynamic> toJson() {
    final encoded = JsonCodecX.encode($data);
    return encoded is Map<String, dynamic>
        ? encoded
        : Map<String, dynamic>.from(encoded as Map);
  }

  String toJsonString({bool pretty = false}) =>
      JsonCodecX.encodeString(toJson(), pretty: pretty);

  void loadJson(Map<String, dynamic> json) {
    _nest = null;
    $data
      ..clear()
      ..addAll(json);
  }

  @override
  String toString() => '$runtimeType(${toJsonString()})';
}

/// File metadata as APIs usually return it in JSON (not a dart:io [File]).
class JsonFile extends JsonModel {
  JsonFile([super.data]);
  JsonFile.fromJson(super.json) : super.fromJson();
  JsonFile.copyOf(super.data) : super.copyOf();

  String get name => $str('name');
  set name(String v) => $set('name', v);

  String? get path => $strOrNull('path') ?? $strOrNull('filePath');
  set path(String? v) => $set('path', v);

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

  Uint8List? get bytes => $bytes('bytes') ?? $bytes('content') ?? $bytes('data');
  set bytes(Uint8List? v) => $set('bytes', v);

  bool get hasUrl => url != null && url!.isNotEmpty;
  bool get hasBytes => bytes != null && bytes!.isNotEmpty;
}
