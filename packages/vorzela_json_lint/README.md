# vorzela_json_lint

[`custom_lint`](https://pub.dev/packages/custom_lint) rules for
[vorzela_json](https://github.com/vorzela/vorzela_json) best practices.

## Install

In your app `pubspec.yaml`:

```yaml
dev_dependencies:
  custom_lint: ^0.8.1
  vorzela_json_lint:
    git:
      url: https://github.com/vorzela/vorzela_json.git
      path: packages/vorzela_json_lint
```

In `analysis_options.yaml`:

```yaml
analyzer:
  plugins:
    - custom_lint

custom_lint:
  rules:
    - prefer_str_at_for_deep_field
    - avoid_nested_json_model_chain
    - prefer_json_http_models
    - prefer_dollar_json_for_request
    - prefer_enum_values_in_enum_at
    - avoid_mutating_dollar_json
```

Run:

```bash
dart run custom_lint
```

## Rules

| Rule | What it catches |
|------|-----------------|
| `prefer_str_at_for_deep_field` | `$model(...).$str/...` instead of `$strAt` |
| `avoid_nested_json_model_chain` | `$model` called on another `$model` |
| `prefer_json_http_models` | `JsonHttp.list` / `bodyList` (prefer `models` / `modelsBody`) |
| `prefer_dollar_json_for_request` | `toJson()` in `post`/`put`/`patch` `data:` / `body:` |
| `prefer_enum_values_in_enum_at` | `$enumAt` / `$enum` without `among: Enum.values` |
| `avoid_mutating_dollar_json` | Assignments into `$json[...]` or `$data[...]` |

Disable a rule:

```yaml
custom_lint:
  rules:
    - prefer_json_http_models: false
```

## License

MIT
