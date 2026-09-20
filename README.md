# vorzela_json

JSON from the network → Dart models. No `build_runner`.

**License:** MIT · **Repo:** https://github.com/vorzela/vorzela_json

---

## The idea

```text
HTTP body  →  Map / List  →  Your model
  Dio/http      jsonDecode     User(...) / User.fromJson(...)
```

You write the model once. DateTime, enums, files, nested objects convert both ways.

Nested models share the parent's map (so `user.photo?.name = 'x'` sticks). Use
`JsonModel.copyOf(data)` when you need a defensive clone.

---

## Enums — why `Role.values`, not `Role.admin`

JSON has a **string**: `"role": "admin"`.

Dart needs a **case**: `Role.admin`.

| Argument | What it is |
|----------|------------|
| `Role.values` | **All** cases — the lookup table (`[Role.admin, Role.member]`) so `"admin"` can become `Role.admin` |
| `or: Role.member` | **Fallback only** if the key is missing or the string is unknown — not “the field’s value” |
| `user.role = Role.admin` | How you **set** a value when writing |

```dart
enum Role { admin, member }

class User extends JsonModel {
  User([super.data]);
  User.fromJson(super.json) : super.fromJson();

  String get name => $str('name');
  set name(String v) => $set('name', v);

  // Read: JSON "admin" → Role.admin  (searches Role.values by .name)
  Role get role => $enumAt('role', among: Role.values, or: Role.member);

  // Write: Role.admin → JSON "admin"
  set role(Role v) => $set('role', v);
}

// Incoming API JSON:
final user = User.fromJson({
  'name': 'Ada',
  'role': 'admin',   // string from server
});
print(user.role);    // Role.admin  ← matched, not the fallback

user.role = Role.member;           // you pick the case
print(user.toJson()['role']);      // "member"
```

---

## Files in JSON

APIs rarely send a dart:io `File`. They send **metadata** (and sometimes base64):

```json
{
  "avatar": {
    "name": "me.png",
    "url": "https://cdn/me.png",
    "mimeType": "image/png",
    "size": 4096
  },
  "attachments": [
    { "name": "clip.mp4", "url": "https://cdn/clip.mp4", "mimeType": "video/mp4" }
  ]
}
```

```dart
class Post extends JsonModel {
  Post([super.data]);
  Post.fromJson(super.json) : super.fromJson();

  JsonFile? get avatar => $file('avatar');
  set avatar(JsonFile? v) => $setModel('avatar', v);

  List<JsonFile> get attachments => $files('attachments');
}

final post = JsonHttp.map(res.data, Post.fromJson);
final url = post.avatar?.url;
final bytes = post.avatar?.bytes; // if API embedded base64
```

**Multipart upload** (actual file bytes) stays on Dio:

```dart
await dio.post(
  '/upload',
  data: FormData.fromMap({
    'file': await MultipartFile.fromFile(path, filename: 'clip.mp4'),
  }),
);
// Response JSON → JsonFile / your model via JsonHttp.map
```

---

## Dio

```dart
final res = await dio.get('/users/1');
final user = JsonHttp.map(res.data, User.fromJson);

final list = JsonHttp.models(
  (await dio.get('/products')).data,
  Product.fromJson,
); // lazy — good for ~200 item catalogs

await dio.post('/users', data: user.asRequestData);
```

## package:http

```dart
final res = await http.get(Uri.parse('$base/users/1'));
final user = JsonHttp.body(res.body, User.fromJson);

await http.post(
  Uri.parse('$base/users'),
  headers: {'content-type': 'application/json'},
  body: user.asRequestBody,
);
```

---

## Types

| Dart | JSON |
|------|------|
| `DateTime` | ISO-8601 UTC (also reads epoch ms/s) |
| `Duration` | milliseconds |
| `Uri` | string |
| `BigInt` | decimal string |
| `Enum` | `.name` string |
| `Uint8List` | base64 |
| `JsonFile` | `{ name, url, mimeType, size, bytes? }` |
| nested `JsonModel` | object |
| `List` / `Map` / `Set` | deep |

---

## Install

```yaml
dependencies:
  vorzela_json:
    git:
      url: https://github.com/vorzela/vorzela_json.git
```

---

## Large lists (ecommerce catalogs)

`$models` / `JsonHttp.models` return a **lazy** [JsonModelList]: constructing
the list does not wrap every element. Each model is created when that index
is read (and cached), so a `ListView` of 200 products only allocates the
visible rows.

```dart
final products = JsonHttp.models(res.data, Product.fromJson);
// or: catalog.$models('items', Product.fromJson)

Text(products[index].title);          // wrap this row only
products.mapAt(index).str('title');   // even lighter — raw map, no model
```

`JsonHttp.list` still exists for small arrays when you want every element
eagerly wrapped.

---

## vs `json_serializable`

Same practical types for REST. No codegen. Field access is a map lookup
(fine vs network). For huge offline decode loops that touch every field of
every row, codegen can still win — for typical shop catalogs (~200 items +
ListView), prefer `JsonHttp.models` / `$models`.
