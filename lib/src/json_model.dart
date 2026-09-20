import 'dart:typed_data';

import 'codec.dart';
import 'model_list.dart';
import 'pick.dart';

/// Bag-backed model: JSON map in → typed getters out. No codegen.
///
/// Nested models: [$model] / [$setModel]. Files: see [JsonFile].
///
/// The model wraps its map by reference (see the constructor), so nested
/// models read via [$model] / [$models] share the parent's data — mutating
/// one is visible through the other.
///
/// Large arrays (product catalogs, ~200+ items): prefer [$models] /
/// [JsonHttp.models] — they return a [JsonModelList] that wraps each
/// element only when that index is read (ListView-friendly).
class JsonModel implements JsonEncodable {
  /// Wraps [data] directly — no defensive copy. See [JsonModel.copyOf] when
  /// you need isolation from a map you still mutate elsewhere.
  JsonModel([Map<String, dynamic>? data])
      : $data = data ?? <String, dynamic>{};

  /// Same as `Model(json)` — explicit name for Dio/http call sites.
  JsonModel.fromJson(Map<String, dynamic> json) : this(json);

  /// Defensive-copy constructor — isolates this model from [data].
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

  /// Read an enum from JSON — [among] is every case (`Role.values`);
  /// [or] is fallback only when missing/unknown.
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

  /// Deprecated alias — prefer [$enumAt].
  T $enum<T extends Enum>(String key, List<T> values, T fallback) =>
      $enumAt(key, among: values, or: fallback);

  T? $enumOrNull<T extends Enum>(String key, List<T> values) =>
      $enumAtOrNull(key, among: values);

  List<T> $list<T>(String key, T Function(dynamic) map) =>
      $data.listOf(key, map);

  /// Nested models as a [JsonModelList] — **lazy**, index-cached.
  ///
  /// Prefer this for arrays of tens–hundreds of objects (product lists,
  /// search hits). `list[i]` allocates a model only when that row is read.
  JsonModelList<T> $models<T extends JsonModel>(
    String key,
    T Function(Map<String, dynamic>) create,
  ) {
    final v = $data[key];
    if (v is! List) return JsonModelList.empty(create);
    return JsonModelList(v, create);
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

  JsonModelList<JsonFile> $files(String key) => $models(key, JsonFile.new);

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
      $data[key] = model.$data;
    }
  }

  /// Replace / set a nested array, sharing [list.raw] when possible.
  void $setModels(String key, JsonModelList<JsonModel>? list) {
    if (list == null) {
      $data.remove(key);
    } else {
      $data[key] = list.raw;
    }
  }

  void $merge(Map<String, dynamic> other) {
    other.forEach((k, v) => $set(k, v));
  }

  // ── codec ────────────────────────────────────────────────────────────

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
