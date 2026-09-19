# vorzela_json

Write Dart models. Skip `build_runner`. JSON for **DateTime**, **Duration**,
**Uri**, **BigInt**, **Enum**, **Uint8List**, nested models, lists, maps, sets.

Works with **Dio**, **`package:http`**, or any client that gives you a body /
`Map` — this package only does encode/decode.

**License:** MIT  
**Repo:** https://github.com/vorzela/vorzela_json

---

## vs `json_serializable`

| | vorzela_json | json_serializable |
|--|--------------|-------------------|
| Codegen | **None** | `build_runner` |
| Types for APIs | Same practical set (see below) | Same + custom `@JsonKey` converters |
| Compile-time field checks | Runtime (your getters) | Generated |
| Perf (typical REST) | Fine — same `dart:convert` under the hood | Slightly faster on huge lists (no map lookups) |
| Perf (10k+ nested decode) | Prefer codegen if profiling says so | Best |
| Dio / http | `JsonHttp.map` / `.body` | Hand-written `fromJson` |

For chat apps, dashboards, and Dio CRUD, vorzela_json is enough. If you decode
multi‑MB payloads in a tight loop and profiling shows cost, switch hot models to
codegen — keep vorzela_json for the rest.

---

## Install

```yaml
dependencies:
  vorzela_json:
    git:
      url: https://github.com/vorzela/vorzela_json.git
  dio: ^5.4.0          # optional
  http: ^1.2.0         # optional
```

---

## Types

| Dart | JSON encode | JSON decode |
|------|-------------|-------------|
| `null` / `bool` / `num` / `String` | as-is | as-is |
| `DateTime` | ISO-8601 UTC | ISO string **or** epoch ms/s |
| `Duration` | ms `int` | ms `int` |
| `Uri` | string | string |
| `BigInt` | decimal string | string / int |
| `Enum` | `.name` | name or index |
| `Uint8List` | base64 | base64 or `List<int>` |
| `List` / `Set` / `Map` | deep | via `listOf` / `mapOrNull` |
| nested model | `toJson()` | `fromJson` / `$model` |
| custom | `JsonEncodable` / `toJson()` | your factory |

Unsupported types **throw** on encode (no silent `toString()` surprises).

---

## Models

### Bag style (no `fromJson` boilerplate)

```dart
enum Role { admin, member }

class User extends JsonModel {
  User([super.data]);

  String get name => $str('name');
  set name(String v) => $set('name', v);

  DateTime? get createdAt => $dateTime('createdAt');
  set createdAt(DateTime? v) => $set('createdAt', v);

  Role get role => $enum('role', Role.values, Role.member);
  set role(Role v) => $set('role', v);

  List<String> get tags => $list('tags', (e) => e.toString());
  set tags(List<String> v) => $set('tags', v);

  Profile? get profile => $model('profile', Profile.new);
  set profile(Profile? v) => $setModel('profile', v);
}

class Profile extends JsonModel {
  Profile([super.data]);
  String get bio => $str('bio');
  set bio(String v) => $set('bio', v);
}
```

### Immutable style (same helpers)

```dart
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
```

---

## Dio

```dart
import 'package:dio/dio.dart';
import 'package:vorzela_json/vorzela_json.dart';

final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));

// GET one
Future<User> fetchUser(String id) async {
  final res = await dio.get('/users/$id');
  return JsonHttp.map(res.data, User.new); // or Order.fromJson
}

// GET list
Future<List<User>> fetchUsers() async {
  final res = await dio.get('/users');
  return JsonHttp.list(res.data, User.new);
}

// POST
Future<User> createUser(User user) async {
  final res = await dio.post(
    '/users',
    data: user.asRequestData, // DateTime/Enum/… already JSON-safe
  );
  return JsonHttp.map(res.data, User.new);
}

// PUT with immutable model
Future<Order> saveOrder(Order order) async {
  final res = await dio.put('/orders/${order.id}', data: JsonHttp.data(order));
  return JsonHttp.map(res.data, Order.fromJson);
}
```

Interceptor tip: keep Dio’s default JSON transformer; pass `Map`s from
`JsonHttp.data` — do **not** double-encode as a string unless the API wants raw text.

---

## package:http (fetch-style)

```dart
import 'package:http/http.dart' as http;
import 'package:vorzela_json/vorzela_json.dart';

const base = 'https://api.example.com';

Future<User> fetchUser(String id) async {
  final res = await http.get(Uri.parse('$base/users/$id'));
  if (res.statusCode >= 400) throw Exception(res.body);
  return JsonHttp.body(res.body, User.new);
}

Future<List<Order>> fetchOrders() async {
  final res = await http.get(Uri.parse('$base/orders'));
  return JsonHttp.bodyList(res.body, Order.fromJson);
}

Future<User> createUser(User user) async {
  final res = await http.post(
    Uri.parse('$base/users'),
    headers: {'content-type': 'application/json'},
    body: user.asRequestBody,
  );
  return JsonHttp.body(res.body, User.new);
}
```

---

## API cheat sheet

| Helper | Use |
|--------|-----|
| `JsonModel` | `$str` / `$dateTime` / `$enum` / `$set` / `toJson` |
| `JsonPick` on `Map` | `str`, `dateTimeReq`, `bigInt`, `listOf`, … |
| `jsonMap({…})` | encode a literal with DateTimes |
| `JsonHttp.map` / `.list` | Dio `response.data` |
| `JsonHttp.body` / `.bodyList` | `http` / fetch response body |
| `JsonHttp.data` / `.bodyString` | request payload |
| `model.asRequestData` / `.asRequestBody` | shorthand on `JsonModel` |

---

## Performance notes

1. Encoding/decoding uses `dart:convert` — same engine as generated code.
2. `JsonModel` getters read a `Map` (tiny cost vs network I/O).
3. Avoid encoding in a 60fps paint path; decode on isolate only for huge blobs.
4. Prefer immutable `fromJson` factories when you want value types + equality.
