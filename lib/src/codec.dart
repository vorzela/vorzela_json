import 'dart:convert';
import 'dart:typed_data';

/// Converts Dart values ↔ JSON-safe values without code generation.
///
/// Built-in encode support (same practical set as typical
/// `json_serializable` + converters):
///
/// | Dart | JSON |
/// |------|------|
/// | `null` / `bool` / `num` / `String` | as-is |
/// | `DateTime` | ISO-8601 UTC string |
/// | `Duration` | milliseconds `int` |
/// | `Uri` | string |
/// | `BigInt` | string (safe for JS / JSON numbers) |
/// | `Enum` | `.name` |
/// | `Uint8List` / `ByteBuffer` | base64 string |
/// | `JsonEncodable` / `toJson()` | object / value |
/// | `List` / `Set` / `Iterable` / `Map` | deep-encoded |
///
/// Custom types: implement [JsonEncodable] or add a `toJson()` method.
/// For one-off fields, use [JsonPick] converters on read.
class JsonCodecX {
  JsonCodecX._();

  /// Encode any value to a JSON-safe tree (Maps/Lists/primitives).
  static dynamic encode(Object? value) {
    if (value == null ||
        value is bool ||
        value is num ||
        value is String) {
      return value;
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is Duration) {
      return value.inMilliseconds;
    }
    if (value is Uri) {
      return value.toString();
    }
    if (value is BigInt) {
      return value.toString();
    }
    if (value is Enum) {
      return value.name;
    }
    if (value is Uint8List) {
      return base64Encode(value);
    }
    if (value is ByteBuffer) {
      return base64Encode(value.asUint8List());
    }
    if (value is JsonEncodable) {
      return encode(value.toJson());
    }
    // duck-typed toJson() — same pattern as many hand-written models
    try {
      final dynamic dyn = value;
      final json = dyn.toJson();
      if (!identical(json, value)) return encode(json);
    } catch (_) {}
    if (value is Map) {
      return <String, dynamic>{
        for (final e in value.entries)
          e.key.toString(): encode(e.value),
      };
    }
    if (value is Iterable) {
      return [for (final e in value) encode(e)];
    }
    throw JsonCodecException(
      'Cannot encode ${value.runtimeType}. '
      'Implement JsonEncodable / toJson(), or pass a supported type.',
    );
  }

  /// `jsonEncode(encode(value))`.
  static String encodeString(Object? value, {bool pretty = false}) {
    final encoded = encode(value);
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(encoded);
    }
    return jsonEncode(encoded);
  }

  /// `jsonDecode` then leave as dynamic tree (use [JsonPick] / [JsonModel]).
  static dynamic decodeString(String source) => jsonDecode(source);

  static Map<String, dynamic> decodeMap(String source) {
    final v = jsonDecode(source);
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    throw FormatException('Expected JSON object, got ${v.runtimeType}');
  }

  static List<dynamic> decodeList(String source) {
    final v = jsonDecode(source);
    if (v is List) return v;
    throw FormatException('Expected JSON array, got ${v.runtimeType}');
  }
}

/// Thrown when [JsonCodecX.encode] meets an unsupported type.
class JsonCodecException implements Exception {
  JsonCodecException(this.message);
  final String message;
  @override
  String toString() => 'JsonCodecException: $message';
}

/// Implement on models that own their `toJson` shape.
abstract interface class JsonEncodable {
  Object? toJson();
}

/// Deep-encode a map literal so DateTime etc. become JSON-safe.
Map<String, dynamic> jsonMap(Map<String, Object?> fields) {
  return <String, dynamic>{
    for (final e in fields.entries) e.key: JsonCodecX.encode(e.value),
  };
}

extension JsonMapEncode on Map<String, Object?> {
  Map<String, dynamic> get encoded => jsonMap(this);
}
