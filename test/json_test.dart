import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vorzela_json/vorzela_json.dart';

enum Role { admin, member }

class User extends JsonModel {
  User([super.data]);
  User.fromJson(super.json) : super.fromJson();
  User.copyOf(super.data) : super.copyOf();

  String get name => $str('name');
  set name(String v) => $set('name', v);

  DateTime? get createdAt => $dateTime('createdAt');
  set createdAt(DateTime? v) => $set('createdAt', v);

  /// Role.values = lookup table; or: = fallback if JSON missing/unknown.
  Role get role => $enumAt('role', among: Role.values, or: Role.member);
  set role(Role v) => $set('role', v);

  Duration? get ttl => $duration('ttl');
  set ttl(Duration? v) => $set('ttl', v);

  Uint8List? get avatar => $bytes('avatar');
  set avatar(Uint8List? v) => $set('avatar', v);

  BigInt? get balance => $bigInt('balance');
  set balance(BigInt? v) => $set('balance', v);

  JsonFile? get photo => $file('photo');
  set photo(JsonFile? v) => $setModel('photo', v);

  JsonModelList<JsonFile> get files => $files('files');
}

class Order {
  Order({required this.id, required this.at, required this.total});
  final String id;
  final DateTime at;
  final BigInt total;

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j.str('id'),
        at: j.dateTimeReq('at'),
        total: j.bigIntReq('total'),
      );

  Map<String, dynamic> toJson() => jsonMap({
        'id': id,
        'at': at,
        'total': total,
      });
}

class _BrokenToJson {
  Map<String, dynamic> toJson() => throw StateError('boom');
}

void main() {
  test('JSON string role "admin" becomes Role.admin via Role.values', () {
    // This is the confusing bit: values = search list, not the assigned case.
    final user = User.fromJson({'name': 'Ada', 'role': 'admin'});
    expect(user.role, Role.admin);

    user.role = Role.member;
    expect(user.toJson()['role'], 'member');

    // Missing role → fallback Role.member
    expect(User.fromJson({'name': 'x'}).role, Role.member);
  });

  test('JsonModel round-trips DateTime Enum Duration bytes BigInt', () {
    final u = User()
      ..name = 'Ada'
      ..createdAt = DateTime.utc(2026, 1, 2, 3, 4, 5)
      ..role = Role.admin
      ..ttl = const Duration(seconds: 90)
      ..avatar = Uint8List.fromList([1, 2, 3])
      ..balance = BigInt.parse('9007199254740993');

    final raw = u.toJsonString();
    final map = jsonDecode(raw) as Map<String, dynamic>;
    expect(map['createdAt'], '2026-01-02T03:04:05.000Z');
    expect(map['role'], 'admin');
    expect(map['ttl'], 90000);
    expect(map['balance'], '9007199254740993');

    final back = User.fromJson(map);
    expect(back.name, 'Ada');
    expect(back.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
    expect(back.role, Role.admin);
    expect(back.ttl, const Duration(seconds: 90));
    expect(back.avatar, Uint8List.fromList([1, 2, 3]));
    expect(back.balance, BigInt.parse('9007199254740993'));
  });

  test('JsonFile from API metadata JSON', () {
    final post = User.fromJson({
      'name': 'Ada',
      'role': 'admin',
      'photo': {
        'name': 'me.png',
        'url': 'https://cdn/me.png',
        'mimeType': 'image/png',
        'size': 12,
        'bytes': base64Encode([9, 8, 7]),
      },
      'files': [
        {'name': 'a.pdf', 'url': 'https://cdn/a.pdf'},
      ],
    });

    expect(post.photo?.name, 'me.png');
    expect(post.photo?.url, 'https://cdn/me.png');
    expect(post.photo?.mimeType, 'image/png');
    expect(post.photo?.size, 12);
    expect(post.photo?.bytes, Uint8List.fromList([9, 8, 7]));
    expect(post.files.single.name, 'a.pdf');
    expect(post.files.single.hasUrl, isTrue);
  });

  test('jsonMap encodes nested values and Set', () {
    final m = jsonMap({
      'when': DateTime.utc(2020),
      'tags': {'a', 'b'},
      'nested': {'d': const Duration(days: 1)},
    });
    expect(m['when'], '2020-01-01T00:00:00.000Z');
    expect(m['tags'], isA<List>());
    expect((m['nested'] as Map)['d'], 86400000);
  });

  test('pick reads epoch ms and seconds', () {
    expect(
      {'t': 1700000000000}.dateTime('t')!.millisecondsSinceEpoch,
      1700000000000,
    );
    expect(
      {'t': 1700000000}.dateTime('t')!.millisecondsSinceEpoch,
      1700000000000,
    );
  });

  test('unsupported type throws', () {
    expect(
      () => JsonCodecX.encode(Object()),
      throwsA(isA<JsonCodecException>()),
    );
  });

  test('nested model writes propagate back to the parent (no silent loss)', () {
    final user = User.fromJson({
      'name': 'Ada',
      'photo': {'name': 'old.png', 'url': 'https://cdn/old.png'},
      'files': [
        {'name': 'a.pdf'},
        {'name': 'b.pdf'},
      ],
    });

    // Mutating a model read via $model must be visible on the parent —
    // previously this silently mutated a throwaway copy.
    user.photo!.name = 'new.png';
    expect(user.toJson()['photo']['name'], 'new.png');

    // Same for entries read via $models.
    user.files[0].name = 'renamed.pdf';
    expect(user.toJson()['files'][0]['name'], 'renamed.pdf');
  });

  test('toJson() output is independent of \$data (no output aliasing)', () {
    final user = User.fromJson({'name': 'Ada'});
    final json = user.toJson();
    json['name'] = 'Mutated';
    // The encoded output is a fresh map — mutating it must not reach back
    // into the model's own backing data.
    expect(user.name, 'Ada');
  });

  test('JsonModel.copyOf isolates the model from the original map', () {
    final source = <String, dynamic>{'name': 'Ada'};
    final user = User.copyOf(source);
    user.name = 'Changed';
    // copyOf clones on the way in, so the caller's map is untouched.
    expect(source['name'], 'Ada');
  });

  test('default constructor shares the map you pass it (fast path)', () {
    final source = <String, dynamic>{'name': 'Ada'};
    final user = User.fromJson(source);
    user.name = 'Changed';
    // fromJson/the default constructor wrap by reference, no copy.
    expect(source['name'], 'Changed');
  });

  test(
      'encode() propagates real errors from a custom toJson() instead of '
      'masking them as "unsupported type"', () {
    expect(
      () => JsonCodecX.encode(_BrokenToJson()),
      throwsA(isA<StateError>()),
    );
  });

  test('\$setModel shares the nested bag so later writes still propagate', () {
    final user = User({'name': 'Ada'});
    final photo = JsonFile({'name': 'a.png'});
    user.photo = photo;
    photo.name = 'b.png';
    expect(user.toJson()['photo']['name'], 'b.png');
  });

  test('JsonHttp map/list/body for Dio- and http-style payloads', () {
    final user = JsonHttp.map(
      {'name': 'Ada', 'role': 'admin'},
      User.fromJson,
    );
    expect(user.name, 'Ada');
    expect(user.role, Role.admin);

    final users = JsonHttp.list(
      [
        {'name': 'A', 'role': 'member'},
        {'name': 'B', 'role': 'admin'},
      ],
      User.fromJson,
    );
    expect(users.map((u) => u.name), ['A', 'B']);
    expect(users[1].role, Role.admin);

    final order = JsonHttp.body(
      '{"id":"1","at":"2026-01-01T00:00:00.000Z","total":"42"}',
      Order.fromJson,
    );
    expect(order.id, '1');
    expect(order.total, BigInt.from(42));

    expect(JsonHttp.data(user)['name'], 'Ada');
    expect(user.asRequestData['name'], 'Ada');
    expect(jsonDecode(user.asRequestBody), isA<Map>());
  });

  test('JsonModelList lazy-wraps a 200-item ecommerce catalog', () {
    final raw = <Map<String, dynamic>>[
      for (var i = 0; i < 200; i++)
        {
          'name': 'Product $i',
          'role': i.isEven ? 'admin' : 'member',
          'balance': '$i',
        },
    ];

    final products = JsonHttp.models(raw, User.fromJson);
    expect(products, isA<JsonModelList<User>>());
    expect(products.length, 200);

    // Touch only a window of rows (ListView-style) — still correct.
    expect(products[0].name, 'Product 0');
    expect(products[50].name, 'Product 50');
    expect(products[199].role, Role.member);

    // Cached: same index returns the identical model instance.
    expect(identical(products[50], products[50]), isTrue);

    // Writes go through to the shared raw JSON.
    products[7].name = 'Renamed';
    expect(raw[7]['name'], 'Renamed');

    // Raw map access avoids a model when you only need one field.
    expect(products.mapAt(3).str('name'), 'Product 3');

    // Full iteration still works (wraps each once).
    expect(products.where((u) => u.role == Role.admin).length, 100);
  });

  test('\$models on a parent document is lazy for nested arrays', () {
    final catalog = User.fromJson({
      'name': 'shop',
      'role': 'admin',
      'files': [
        for (var i = 0; i < 200; i++) {'name': 'f$i.pdf', 'size': i},
      ],
    });
    final files = catalog.files;
    expect(files.length, 200);
    expect(files[10].name, 'f10.pdf');
    expect(files[10].size, 10);
    files[10].name = 'edited.pdf';
    expect(catalog.toJson()['files'][10]['name'], 'edited.pdf');
  });

  test('deep path reads skip intermediate models', () {
    final order = User.fromJson({
      'name': 'Ada',
      'role': 'admin',
      'photo': {
        'name': 'me.png',
        'meta': {'city': 'Nairobi', 'zip': 100},
      },
      'files': [
        {'name': 'a.pdf', 'size': 3},
        {'name': 'b.pdf', 'size': 7},
      ],
    });

    expect(order.$strAt('photo.meta.city'), 'Nairobi');
    expect(order.$intAt('photo.meta.zip'), 100);
    expect(order.$strAt('files.0.name'), 'a.pdf');
    expect(order.$intAt(['files', 1, 'size']), 7);
    expect(order.$strAtOrNull('photo.meta.missing'), isNull);
    expect(order.$at('photo.meta'), isA<Map>());

    // Free functions / map extension.
    expect(jsonStrAt(order.$data, 'photo.name'), 'me.png');
    expect(order.$data.strAt('files.1.name'), 'b.pdf');
  });

  test('\$setAt creates nested maps/lists and writes through', () {
    final u = User({'name': 'Ada'});
    u.$setAt('photo.meta.city', 'Mombasa');
    u.$setAt('files.0.name', 'x.pdf');
    expect(u.$strAt('photo.meta.city'), 'Mombasa');
    expect(u.$strAt('files.0.name'), 'x.pdf');
    expect(u.toJson()['photo']['meta']['city'], 'Mombasa');
  });

  test('\$model nest cache reuses the same wrapper', () {
    final u = User.fromJson({
      'name': 'Ada',
      'photo': {'name': 'a.png'},
    });
    final a = u.photo;
    final b = u.photo;
    expect(identical(a, b), isTrue);
    a!.name = 'b.png';
    expect(u.$strAt('photo.name'), 'b.png');
  });

  test('\$json is zero-copy; toJson still deep-copies', () {
    final u = User.fromJson({'name': 'Ada', 'role': 'admin'});
    expect(identical(u.$json, u.$data), isTrue);
    expect(identical(u.asRequestData, u.$data), isTrue);

    final encoded = u.toJson();
    expect(identical(encoded, u.$data), isFalse);
    encoded['name'] = 'Mutated';
    expect(u.name, 'Ada');
  });

  test('JsonModelList maxCached caps wrapper retention', () {
    final raw = <Map<String, dynamic>>[
      for (var i = 0; i < 100; i++) {'name': 'P$i', 'role': 'member'},
    ];
    final products = JsonHttp.models(raw, User.fromJson, maxCached: 8);
    expect(products.maxCached, 8);

    for (var i = 0; i < 20; i++) {
      expect(products[i].name, 'P$i');
    }
    // First 8 stay cached; later indexes are fresh each read.
    expect(identical(products[0], products[0]), isTrue);
    expect(identical(products[7], products[7]), isTrue);
    final a = products[15];
    final b = products[15];
    expect(identical(a, b), isFalse);
  });
}
