# Changelog

## 0.2.0

### Added
- **`JsonModelList`** — lazy, index-cached list of models over a raw JSON
  array. Built for ecommerce-scale payloads (~200 items): constructing the
  list does not allocate a model per element; `list[i]` wraps on demand
  (ListView-friendly). Includes `mapAt` / `maps` for raw-map access without
  a model, and write-through to the shared JSON.
- **`JsonHttp.models` / `modelsBody`** — lazy catalog entry points (prefer
  these over `JsonHttp.list` for large arrays).
- **`$setModels`** — attach a `JsonModelList` onto a parent document by
  sharing its raw array.

### Changed
- **`$models` / `$files`** now return `JsonModelList` instead of an eagerly
  built `List`. Still implements `List`, so `for` / `.map` / `.where` keep
  working; iteration wraps each element once.
- **`str` / `strOrNull`** fast-path when the JSON value is already a
  `String` (avoids `toString()` on the hot path for catalogs).

## 0.1.0

### Fixed
- **Nested model writes were silently lost.** `$model()` / `$models()` /
  `$file()` / `$files()` used to hand back a *copy* of the sub-map, so
  `user.photo?.name = 'x'` mutated a throwaway clone and never showed up in
  `user.toJson()`. Nested models now share their parent's backing map, so
  writes propagate as expected.
- **`toJson()` copied the output map twice** (once inside `JsonCodecX.encode`,
  once more via a redundant `Map.from(...)` wrapper). Now a single copy.
- **`JsonCodecX.encode()` could mask real errors.** If a custom `toJson()`
  implementation threw, the exception was swallowed and replaced with a
  misleading "implement toJson()" error. Only the "no such method" case
  (i.e. the value genuinely has no `toJson()`) is swallowed now; real
  exceptions propagate.
- **`$models()` allocated an extra intermediate list** (`listOfMaps(...).map(...).toList()`)
  on every call. It now builds the result list directly.

### Changed (behavior)
- `JsonModel(data)` / `JsonModel.fromJson(json)` **no longer defensively
  copy** the map you pass in — they wrap it by reference. This is what makes
  the nested-write fix above possible, and avoids a full tree copy on every
  model constructed (the dominant cost when decoding many models). This is
  always safe for real JSON (`jsonDecode()` output is always a proper
  `Map<String, dynamic>`). If you need the model isolated from a map you
  keep mutating elsewhere, use the new `JsonModel.copyOf(data)` constructor,
  which clones like the old default constructor did.

### Added
- `JsonModel.copyOf(Map<String, dynamic> data)` — defensive-copy constructor
  for when you want the old copy-on-construct behavior.

## 0.0.3 and earlier

See git history.

### Fixed
- **Nested model writes were silently lost.** `$model()` / `$models()` /
  `$file()` / `$files()` used to hand back a *copy* of the sub-map, so
  `user.photo?.name = 'x'` mutated a throwaway clone and never showed up in
  `user.toJson()`. Nested models now share their parent's backing map, so
  writes propagate as expected.
- **`toJson()` copied the output map twice** (once inside `JsonCodecX.encode`,
  once more via a redundant `Map.from(...)` wrapper). Now a single copy.
- **`JsonCodecX.encode()` could mask real errors.** If a custom `toJson()`
  implementation threw, the exception was swallowed and replaced with a
  misleading "implement toJson()" error. Only the "no such method" case
  (i.e. the value genuinely has no `toJson()`) is swallowed now; real
  exceptions propagate.
- **`$models()` allocated an extra intermediate list** (`listOfMaps(...).map(...).toList()`)
  on every call. It now builds the result list directly.

### Changed (behavior)
- `JsonModel(data)` / `JsonModel.fromJson(json)` **no longer defensively
  copy** the map you pass in — they wrap it by reference. This is what makes
  the nested-write fix above possible, and avoids a full tree copy on every
  model constructed (the dominant cost when decoding many models). This is
  always safe for real JSON (`jsonDecode()` output is always a proper
  `Map<String, dynamic>`). If you need the model isolated from a map you
  keep mutating elsewhere, use the new `JsonModel.copyOf(data)` constructor,
  which clones like the old default constructor did.

### Added
- `JsonModel.copyOf(Map<String, dynamic> data)` — defensive-copy constructor
  for when you want the old copy-on-construct behavior.

## 0.0.3 and earlier

See git history.
