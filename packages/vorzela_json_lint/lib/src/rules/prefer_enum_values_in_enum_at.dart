import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils.dart';

class PreferEnumValuesInEnumAt extends DartLintRule {
  const PreferEnumValuesInEnumAt() : super(code: _code);

  static const _code = LintCode(
    name: 'prefer_enum_values_in_enum_at',
    problemMessage:
        'Pass the enum\'s .values list to \$enumAt / \$enum (among: Role.values).',
    correctionMessage: 'Use among: YourEnum.values (not a hand-built list).',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      final method = node.methodName.name;
      if (method != r'$enumAt' && method != r'$enum') return;

      Expression? among;
      if (method == r'$enumAt') {
        for (final arg in node.argumentList.arguments) {
          if (arg is NamedExpression && arg.name.label.name == 'among') {
            among = arg.expression;
            break;
          }
        }
      } else {
        final args = node.argumentList.arguments;
        if (args.length >= 2) {
          among = args[1];
        }
      }

      if (among == null) return;
      if (isEnumValuesExpression(among)) return;
      reporter.atNode(among, code);
    });
  }
}
