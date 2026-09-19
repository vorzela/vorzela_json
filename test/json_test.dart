import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vorzela_json/vorzela_json.dart';

enum Role { admin, member }

class User extends JsonModel {
  User([super.data]);

  String get name => $str('name');
  set name(String v) => $set('name', v);

  DateTime? get createdAt => $dateTime('createdAt');
  set createdAt(DateTime? v) => $set('createdAt', v);

  Role get role => $enum('role', Role.values, Role.member);
  set role(Role v) => $set('role', v);

  Duration? get ttl => $duration('ttl');
  set ttl(Duration? v) => $set('ttl', v);

  Uint8List? get avatar => $data.bytes('avatar');
  set avatar(Uint8List? v) => $set('avatar', v);
}

void main() {
  test('JsonModel round-trips DateTime Enum Duration bytes', () {
    final u = User()
      ..name = 'Ada'
      ..createdAt = DateTime.utc(2026, 1, 2, 3, 4, 5)
      ..role = Role.admin
      ..ttl = const Duration(seconds: 90)
      ..avatar = Uint8List.fromList([1, 2, 3]);

    final raw = u.toJsonString();
    final map = jsonDecode(raw) as Map<String, dynamic>;
    expect(map['createdAt'], '2026-01-02T03:04:05.000Z');
    expect(map['role'], 'admin');
    expect(map['ttl'], 90000);

    final back = User(map);
    expect(back.name, 'Ada');
    expect(back.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
    expect(back.role, Role.admin);
    expect(back.ttl, const Duration(seconds: 90));
    expect(back.avatar, Uint8List.fromList([1, 2, 3]));
  });

  test('jsonMap encodes nested values', () {
    final m = jsonMap({
      'when': DateTime.utc(2020),
      'tags': ['a', 'b'],
      'nested': {'d': const Duration(days: 1)},
    });
    expect(m['when'], '2020-01-01T00:00:00.000Z');
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
}
