import 'codec.dart';
import 'json_model.dart';
import 'model_list.dart';

/// Helpers for Dio / `package:http` / `fetch`-style responses.
///
/// No HTTP client dependency — pass the body / decoded `data` you already have.
///
/// Dio:
/// ```dart
/// final res = await dio.get('/users/1');
/// final user = JsonHttp.map(res.data, User.fromJson);
/// ```
///
/// package:http:
/// ```dart
/// final res = await http.get(Uri.parse('$base/users/1'));
/// final user = JsonHttp.body(res.body, User.fromJson);
/// ```
class JsonHttp {
  JsonHttp._();

  /// Decode a JSON **object** string → model.
  static T body<T>(
    String source,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    return fromJson(JsonCodecX.decodeMap(source));
  }

  /// Decode a JSON **array** string → list of models.
  ///
  /// Prefer [modelsBody] / [models] for large arrays (lazy wrap).
  static List<T> bodyList<T>(
    String source,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    return list(JsonCodecX.decodeList(source), fromJson);
  }

  /// Lazy [JsonModelList] from a JSON **array** string (ecommerce catalogs).
  static JsonModelList<T> modelsBody<T extends JsonModel>(
    String source,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    return JsonModelList.from(JsonCodecX.decodeList(source), fromJson);
  }

  /// Dio / already-decoded `response.data` as a Map → model.
  static T map<T>(
    Object? data,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    if (data is Map<String, dynamic>) return fromJson(data);
    if (data is Map) return fromJson(Map<String, dynamic>.from(data));
    if (data is String) return body(data, fromJson);
    throw FormatException(
      'Expected Map or JSON object string, got ${data.runtimeType}',
    );
  }

  /// Dio `response.data` as a List → models (eager — wraps every element).
  ///
  /// For catalogs of ~100+ items prefer [models], which wraps on demand.
  static List<T> list<T>(
    Object? data,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    if (data is String) return bodyList(data, fromJson);
    if (data is! List) {
      throw FormatException('Expected List, got ${data.runtimeType}');
    }
    return [
      for (final e in data)
        fromJson(
          e is Map<String, dynamic>
              ? e
              : Map<String, dynamic>.from(e as Map),
        ),
    ];
  }

  /// Dio `response.data` as a List → [JsonModelList] (lazy, cached wraps).
  ///
  /// Use this for product grids / search results (~200 items is fine):
  /// ```dart
  /// final products = JsonHttp.models(res.data, Product.fromJson);
  /// Text(products[index].title); // only visible rows allocate
  /// ```
  static JsonModelList<T> models<T extends JsonModel>(
    Object? data,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    if (data is String) return modelsBody(data, fromJson);
    return JsonModelList.from(data, fromJson);
  }

  /// Encode a model / map for `dio.post(data: …)` or `http.post(body: …)`.
  ///
  /// Returns a `Map` (Dio default JSON) — use [bodyString] for raw body text.
  static Map<String, dynamic> data(Object? value) {
    final encoded = JsonCodecX.encode(value);
    if (encoded is Map<String, dynamic>) return encoded;
    if (encoded is Map) return Map<String, dynamic>.from(encoded);
    throw FormatException(
      'Expected object for request data, got ${encoded.runtimeType}',
    );
  }

  /// Encode to a JSON string for `http.post(body: …)`.
  static String bodyString(Object? value, {bool pretty = false}) =>
      JsonCodecX.encodeString(value, pretty: pretty);
}

/// Sugar on [JsonModel] for request/response.
extension JsonModelHttp on JsonModel {
  /// Ready for `dio.post(..., data: model.asRequestData)`.
  Map<String, dynamic> get asRequestData => JsonHttp.data(this);

  /// Ready for `http.post(..., body: model.asRequestBody)`.
  String get asRequestBody => JsonHttp.bodyString(this);
}
