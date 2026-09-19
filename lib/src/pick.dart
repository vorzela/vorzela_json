import 'dart:convert';
import 'dart:typed_data';

import 'codec.dart';

/// Typed readers over a JSON [Map] — no codegen.
extension JsonPick on Map<String, dynamic> {
  Map<String, dynamic>? mapOrNull(String key) {
    final v = this[key];
    if (v == null) return null;
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  Map<String, dynamic> mapReq(String key) {
    final m = mapOrNull(key);
    if (m == null) throw FormatException('Missing object "$key"');
    return m;
  }

  String str(String key, [String fallback = '']) {
    final v = this[key];
    if (v == null) return fallback;
    return v.toString();
  }

  String? strOrNull(String key) {
    final v = this[key];
    if (v == null) return null;
    return v.toString();
  }

  int integer(String key, [int fallback = 0]) {
    final v = this[key];
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  int? intOrNull(String key) {
    final v = this[key];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  double number(String key, [double fallback = 0]) {
    final v = this[key];
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  double? doubleOrNull(String key) {
    final v = this[key];
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  bool boolean(String key, [bool fallback = false]) {
    final v = this[key];
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
    return fallback;
  }

  bool? boolOrNull(String key) {
    if (!containsKey(key) || this[key] == null) return null;
    return boolean(key);
  }

  DateTime? dateTime(String key) {
    final v = this[key];
    if (v == null) return null;
    if (v is DateTime) return v.toUtc();
    if (v is int) {
      // Heuristic: ms vs seconds.
      final ms = v > 9999999999 ? v : v * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    }
    if (v is num) {
      final n = v.toInt();
      final ms = n > 9999999999 ? n : n * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    }
    return DateTime.tryParse(v.toString())?.toUtc();
  }

  DateTime dateTimeReq(String key) {
    final d = dateTime(key);
    if (d == null) throw FormatException('Missing DateTime "$key"');
    return d;
  }

  Duration? duration(String key) {
    final v = this[key];
    if (v == null) return null;
    if (v is Duration) return v;
    if (v is int) return Duration(milliseconds: v);
    if (v is num) return Duration(milliseconds: v.toInt());
    final s = v.toString();
    final ms = int.tryParse(s);
    if (ms != null) return Duration(milliseconds: ms);
    return null;
  }

  Uri? uri(String key) {
    final v = this[key];
    if (v == null) return null;
    if (v is Uri) return v;
    return Uri.tryParse(v.toString());
  }

  Uint8List? bytes(String key) {
    final v = this[key];
    if (v == null) return null;
    if (v is Uint8List) return v;
    if (v is List<int>) return Uint8List.fromList(v);
    if (v is String) {
      try {
        return base64Decode(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  T? enumOrNull<T extends Enum>(String key, List<T> values) {
    final v = this[key];
    if (v == null) return null;
    final name = v is Enum ? v.name : v.toString();
    for (final e in values) {
      if (e.name == name || e.toString() == name) return e;
    }
    // also allow index
    final i = int.tryParse(name);
    if (i != null && i >= 0 && i < values.length) return values[i];
    return null;
  }

  T enumReq<T extends Enum>(String key, List<T> values, T fallback) {
    return enumOrNull(key, values) ?? fallback;
  }

  List<T> listOf<T>(String key, T Function(dynamic) map) {
    final v = this[key];
    if (v is! List) return const [];
    return [for (final e in v) map(e)];
  }

  List<Map<String, dynamic>> listOfMaps(String key) {
    return listOf(key, (e) {
      if (e is Map<String, dynamic>) return e;
      if (e is Map) return Map<String, dynamic>.from(e);
      return <String, dynamic>{};
    });
  }

  T? modelOrNull<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final m = mapOrNull(key);
    if (m == null) return null;
    return fromJson(m);
  }

  T modelReq<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    return fromJson(mapReq(key));
  }
}

/// Parse helpers for dynamic JSON values.
extension JsonDynamicPick on Object? {
  DateTime? asDateTime() {
    final v = this;
    if (v == null) return null;
    if (v is DateTime) return v.toUtc();
    if (v is int) {
      final ms = v > 9999999999 ? v : v * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    }
    return DateTime.tryParse(v.toString())?.toUtc();
  }
}

/// Encode a value for JSON (same as [JsonCodecX.encode]).
dynamic jsonValue(Object? value) => JsonCodecX.encode(value);
