import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class AvoidNestedJsonModelChain extends DartLintRule {
  const AvoidNestedJsonModelChain() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_nested_json_model_chain',
    problemMessage: 'Chaining \$model on another \$model allocates nested wrappers.',
    correctionMessage:
        'Prefer \$strAt / \$at for deep reads, or one \$model at the level you mutate.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != r'$model') return;
      final target = node.target;
      if (target is! MethodInvocation) return;
      if (target.methodName.name != r'$model') return;
      reporter.atNode(node.methodName, code);
    });
  }
}
