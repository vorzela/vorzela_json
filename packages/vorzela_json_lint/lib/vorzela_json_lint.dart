import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/rules/avoid_mutating_dollar_json.dart';
import 'src/rules/avoid_nested_json_model_chain.dart';
import 'src/rules/prefer_dollar_json_for_request.dart';
import 'src/rules/prefer_enum_values_in_enum_at.dart';
import 'src/rules/prefer_json_http_models.dart';
import 'src/rules/prefer_str_at_for_deep_field.dart';

/// Entrypoint for `custom_lint` — must stay `createPlugin` in this library.
PluginBase createPlugin() => _VorzelaJsonLint();

class _VorzelaJsonLint extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        const PreferStrAtForDeepField(),
        const AvoidNestedJsonModelChain(),
        const PreferJsonHttpModels(),
        const PreferDollarJsonForRequest(),
        const PreferEnumValuesInEnumAt(),
        const AvoidMutatingDollarJson(),
      ];
}
