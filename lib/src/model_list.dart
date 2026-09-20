import 'dart:collection';

import 'json_model.dart';

/// Lazy list of [JsonModel]s over a raw JSON array.
///
/// Built for ecommerce-scale payloads (hundreds of objects): constructing the
/// list does **not** allocate a model per element. Each [JsonModel] is created
/// only when that index is read (e.g. a [ListView] cell), and is cached so
/// scrolling back to the same row reuses the instance.
///
/// The list shares the underlying JSON array by reference — mutating
/// `list[i].name = 'x'` writes through to the parent document's JSON.
///
/// ```dart
/// // Prefer this over eagerly mapping 200 products:
/// final products = JsonHttp.models(res.data, Product.fromJson);
/// // or: parent.$models('items', Product.fromJson)
///
/// Text(products[index].name); // only this row is wrapped
/// ```
class JsonModelList<T extends JsonModel> extends ListBase<T> {
  JsonModelList(this._raw, this._create)
      : _cache = List<T?>.filled(_raw.length, null, growable: true);

  /// Empty list (missing / non-list JSON).
  JsonModelList.empty(this._create)
      : _raw = <dynamic>[],
        _cache = <T?>[];

  /// Wrap an already-decoded JSON array (Dio `data`, `jsonDecode`, …).
  factory JsonModelList.from(
    Object? data,
    T Function(Map<String, dynamic>) create,
  ) {
    if (data == null) return JsonModelList.empty(create);
    if (data is! List) {
      throw FormatException(
        'Expected JSON array for JsonModelList, got ${data.runtimeType}',
      );
    }
    return JsonModelList(data, create);
  }

  final List<dynamic> _raw;
  final T Function(Map<String, dynamic>) _create;
  final List<T?> _cache;

  /// The underlying JSON array (maps / primitives). Shared with the parent.
  List<dynamic> get raw => _raw;

  Map<String, dynamic> _mapAt(int index) {
    final e = _raw[index];
    if (e is Map<String, dynamic>) return e;
    if (e is Map) {
      final copied = Map<String, dynamic>.from(e);
      _raw[index] = copied; // normalize once so later reads share
      return copied;
    }
    throw FormatException(
      'Expected object at index $index, got ${e.runtimeType}',
    );
  }

  /// Read the raw map at [index] without allocating a [JsonModel].
  /// Useful in hot list builders that only need one or two fields.
  Map<String, dynamic> mapAt(int index) => _mapAt(index);

  /// Project every element as a raw map (no model allocations).
  Iterable<Map<String, dynamic>> get maps sync* {
    for (var i = 0; i < _raw.length; i++) {
      yield _mapAt(i);
    }
  }

  /// Eagerly materialize every model (use when you truly need all of them).
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
    final cached = _cache[index];
    if (cached != null) return cached;
    final model = _create(_mapAt(index));
    _cache[index] = model;
    return model;
  }

  @override
  void operator []=(int index, T value) {
    _raw[index] = value.$data;
    _cache[index] = value;
  }

  @override
  void add(T element) {
    _raw.add(element.$data);
    _cache.add(element);
  }

  @override
  void insert(int index, T element) {
    _raw.insert(index, element.$data);
    _cache.insert(index, element);
  }

  @override
  T removeAt(int index) {
    final had = this[index];
    _raw.removeAt(index);
    _cache.removeAt(index);
    return had;
  }

  @override
  void clear() {
    _raw.clear();
    _cache.clear();
  }

  /// Drop cached model wrappers (underlying JSON is untouched). Call after
  /// bulk raw edits if you replaced maps out-of-band.
  void invalidateCache() {
    for (var i = 0; i < _cache.length; i++) {
      _cache[i] = null;
    }
  }
}
