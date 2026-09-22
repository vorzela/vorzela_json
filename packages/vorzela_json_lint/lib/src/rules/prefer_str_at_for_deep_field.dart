import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils.dart';

class PreferStrAtForDeepField extends DartLintRule {
  const PreferStrAtForDeepField() : super(code: _code);

  static const _code = LintCode(
    name: 'prefer_str_at_for_deep_field',
    problemMessage:
        'Reading one field via \$model(...).\$str/... allocates a nested wrapper.',
    correctionMessage:
        'Use \$strAt / \$intAt / \$at with a dot path (e.g. \$strAt(\'photo.name\')).',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      if (!shallowReadAfterModel.contains(node.methodName.name)) return;
      final target = node.target;
      if (target is! MethodInvocation) return;
      if (target.methodName.name != r'$model') return;
      reporter.atNode(node.methodName, code);
    });
  }
}
