# vorzela_json

Write Dart models. Skip `build_runner`. JSON in/out for **DateTime**, **Duration**,
**Uri**, **Enum**, **Uint8List**, nested models, lists, and maps.

**License:** MIT  
**Repo:** https://github.com/vorzela/vorzela_json

---

## Why

`json_serializable` / `freezed` need codegen. This package is for teams that want
to stay in the model file and ship:

```dart
class User extends JsonModel {
  User([super.data]);

  String get name => $str('name');
  set name(String v) => $set('name', v);

  DateTime? get createdAt => $dateTime('createdAt');
  set createdAt(DateTime? v) => $set('createdAt', v);

  Role get role => $enum('role', Role.values, Role.member);
  set role(Role v) => $set('role', v);
}

final user = User({'name': 'Ada', 'createdAt': '2026-01-01T00:00:00.000Z'});
user.name = 'Ada Lovelace';
print(user.toJsonString());
```

Or keep immutable classes and only use the helpers:

```dart
class Order {
  Order({required this.id, required this.at});
  final String id;
  final DateTime at;

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j.str('id'),
        at: j.dateTimeReq('at'),
      );

  Map<String, dynamic> toJson() => jsonMap({'id': id, 'at': at});
}
```

---

## Install

```yaml
dependencies:
  vorzela_json:
    git:
      url: https://github.com/vorzela/vorzela_json.git
```

Pure Dart — works in Flutter and server.

---

## Types

| Dart | JSON |
|------|------|
| `DateTime` | ISO-8601 UTC string (also accepts epoch ms/s on read) |
| `Duration` | milliseconds `int` |
| `Uri` | string |
| `Enum` | `.name` |
| `Uint8List` | base64 string |
| `JsonModel` / `toJson()` | object |
| `List` / `Map` | deep-encoded |

---

## API

- `JsonModel` — bag + `$str` / `$int` / `$dateTime` / `$enum` / `$set` / `toJson`
- `JsonPick` on `Map<String, dynamic>` — `str`, `dateTime`, `enumOrNull`, …
- `jsonMap({...})` / `JsonCodecX.encode` — make any tree JSON-safe
- `JsonCodecX.encodeString` / `decodeMap`
