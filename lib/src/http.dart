import 'codec.dart';
import 'json_model.dart';

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
  static List<T> bodyList<T>(
    String source,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final list = JsonCodecX.decodeList(source);
    return [
      for (final e in list)
        fromJson(
          e is Map<String, dynamic>
              ? e
              : Map<String, dynamic>.from(e as Map),
        ),
    ];
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

  /// Dio `response.data` as a List → models.
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
