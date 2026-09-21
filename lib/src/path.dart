/// Walk a JSON tree by dotted path or segment list — no intermediate models.
///
/// Paths use `.` for objects and integers for list indexes:
/// `user.address.city`, `items.0.name`, or `['items', 0, 'name']`.
library;

Object? jsonAt(Object? root, Object path) {
  final segments = _segments(path);
  Object? cur = root;
  for (final seg in segments) {
    if (cur == null) return null;
    if (seg is int) {
      if (cur is! List || seg < 0 || seg >= cur.length) return null;
      cur = cur[seg];
      continue;
    }
    if (cur is Map) {
      cur = cur[seg];
      continue;
    }
    return null;
  }
  return cur;
}

Map<String, dynamic>? jsonMapAt(Object? root, Object path) {
  final v = jsonAt(root, path);
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}

String jsonStrAt(Object? root, Object path, [String fallback = '']) {
  final v = jsonAt(root, path);
  if (v == null) return fallback;
  if (v is String) return v;
  return v.toString();
}

String? jsonStrAtOrNull(Object? root, Object path) {
  final v = jsonAt(root, path);
  if (v == null) return null;
  if (v is String) return v;
  return v.toString();
}

int jsonIntAt(Object? root, Object path, [int fallback = 0]) {
  final v = jsonAt(root, path);
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

int? jsonIntAtOrNull(Object? root, Object path) {
  final v = jsonAt(root, path);
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

bool jsonBoolAt(Object? root, Object path, [bool fallback = false]) {
  final v = jsonAt(root, path);
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().toLowerCase();
  if (s == 'true' || s == '1' || s == 'yes') return true;
  if (s == 'false' || s == '0' || s == 'no') return false;
  return fallback;
}

double jsonDoubleAt(Object? root, Object path, [double fallback = 0]) {
  final v = jsonAt(root, path);
  if (v == null) return fallback;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

List<Object> _segments(Object path) {
  if (path is List) {
    return [
      for (final s in path)
        if (s is int)
          s
        else if (s is num)
          s.toInt()
        else
          s.toString(),
    ];
  }
  final text = path.toString();
  if (text.isEmpty) return const [];
  return [
    for (final part in text.split('.'))
      int.tryParse(part) ?? part,
  ];
}

extension JsonPathPick on Map<String, dynamic> {
  Object? at(Object path) => jsonAt(this, path);
  Map<String, dynamic>? mapAt(Object path) => jsonMapAt(this, path);
  String strAt(Object path, [String fallback = '']) =>
      jsonStrAt(this, path, fallback);
  String? strAtOrNull(Object path) => jsonStrAtOrNull(this, path);
  int intAt(Object path, [int fallback = 0]) => jsonIntAt(this, path, fallback);
  int? intAtOrNull(Object path) => jsonIntAtOrNull(this, path);
  bool boolAt(Object path, [bool fallback = false]) =>
      jsonBoolAt(this, path, fallback);
  double doubleAt(Object path, [double fallback = 0]) =>
      jsonDoubleAt(this, path, fallback);

  /// Set a deep path, creating intermediate maps/lists as needed.
  void setAt(Object path, Object? value) {
    final segments = _segments(path);
    if (segments.isEmpty) return;
    Object cur = this;
    for (var i = 0; i < segments.length - 1; i++) {
      final seg = segments[i];
      final next = segments[i + 1];
      final wantList = next is int;
      if (seg is int) {
        if (cur is! List) return;
        while (cur.length <= seg) {
          cur.add(null);
        }
        var child = cur[seg];
        if (child is! Map && child is! List) {
          child = wantList ? <dynamic>[] : <String, dynamic>{};
          cur[seg] = child;
        }
        cur = child!;
      } else {
        if (cur is! Map) return;
        final k = seg.toString();
        var child = cur[k];
        if (child is! Map && child is! List) {
          child = wantList ? <dynamic>[] : <String, dynamic>{};
          cur[k] = child;
        }
        cur = child as Object;
      }
    }
    final last = segments.last;
    if (last is int) {
      if (cur is! List) return;
      while (cur.length <= last) {
        cur.add(null);
      }
      cur[last] = value;
    } else if (cur is Map) {
      final k = last.toString();
      if (value == null) {
        cur.remove(k);
      } else {
        cur[k] = value;
      }
    }
  }
}
