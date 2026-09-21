import 'dart:collection';

import 'json_model.dart';

/// Lazy list of [JsonModel]s over a raw JSON array.
///
/// Constructing the list does **not** allocate a model per element. Each
/// [JsonModel] is created when that index is read, and optionally cached.
///
/// For huge arrays (thousands of rows), [maxCached] caps how many wrappers
/// stay alive (default: all if length ≤ 256, else 64).
class JsonModelList<T extends JsonModel> extends ListBase<T> {
  JsonModelList(
    this._raw,
    this._create, {
    int? maxCached,
  })  : _maxCached = maxCached ?? (_raw.length <= 256 ? _raw.length : 64),
        _cache = List<T?>.filled(_raw.length, null, growable: true);

  JsonModelList.empty(this._create, {int maxCached = 0})
      : _raw = <dynamic>[],
        _cache = <T?>[],
        _maxCached = maxCached;

  factory JsonModelList.from(
    Object? data,
    T Function(Map<String, dynamic>) create, {
    int? maxCached,
  }) {
    if (data == null) return JsonModelList.empty(create);
    if (data is! List) {
      throw FormatException(
        'Expected JSON array for JsonModelList, got ${data.runtimeType}',
      );
    }
    return JsonModelList(data, create, maxCached: maxCached);
  }

  final List<dynamic> _raw;
  final T Function(Map<String, dynamic>) _create;
  final List<T?> _cache;
  final int _maxCached;
  int _cachedCount = 0;

  List<dynamic> get raw => _raw;

  /// How many model wrappers may be retained (0 = never cache).
  int get maxCached => _maxCached;

  Map<String, dynamic> _mapAt(int index) {
    final e = _raw[index];
    if (e is Map<String, dynamic>) return e;
    if (e is Map) {
      final copied = Map<String, dynamic>.from(e);
      _raw[index] = copied;
      return copied;
    }
    throw FormatException(
      'Expected object at index $index, got ${e.runtimeType}',
    );
  }

  Map<String, dynamic> mapAt(int index) => _mapAt(index);

  Iterable<Map<String, dynamic>> get maps sync* {
    for (var i = 0; i < _raw.length; i++) {
      yield _mapAt(i);
    }
  }

  List<T> toEagerList() => [for (var i = 0; i < length; i++) this[i]];

  @override
  int get length => _raw.length;

  @override
  set length(int newLength) {
    if (newLength < 0) throw RangeError.value(newLength, 'length');
    _raw.length = newLength;
    if (newLength <= _cache.length) {
      _cache.length = newLength;
    } else {
      _cache.addAll(List<T?>.filled(newLength - _cache.length, null));
    }
  }

  @override
  T operator [](int index) {
    if (_maxCached <= 0) return _create(_mapAt(index));
    final cached = _cache[index];
    if (cached != null) return cached;
    final model = _create(_mapAt(index));
    // Stay within budget: once full, return fresh wrappers (no thrash).
    if (_cachedCount < _maxCached) {
      _cache[index] = model;
      _cachedCount++;
    }
    return model;
  }

  @override
  void operator []=(int index, T value) {
    _raw[index] = value.$data;
    if (_maxCached > 0) {
      if (_cache[index] == null) _cachedCount++;
      _cache[index] = value;
    }
  }

  @override
  void add(T element) {
    _raw.add(element.$data);
    _cache.add(_maxCached > 0 ? element : null);
    if (_maxCached > 0) _cachedCount++;
  }

  @override
  void insert(int index, T element) {
    _raw.insert(index, element.$data);
    _cache.insert(index, _maxCached > 0 ? element : null);
    if (_maxCached > 0) _cachedCount++;
  }

  @override
  T removeAt(int index) {
    final had = this[index];
    _raw.removeAt(index);
    final removed = _cache.removeAt(index);
    if (removed != null) _cachedCount--;
    return had;
  }

  @override
  void clear() {
    _raw.clear();
    _cache.clear();
    _cachedCount = 0;
  }

  void invalidateCache() {
    for (var i = 0; i < _cache.length; i++) {
      _cache[i] = null;
    }
    _cachedCount = 0;
  }
}
