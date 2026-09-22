import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils.dart';

class PreferJsonHttpModels extends DartLintRule {
  const PreferJsonHttpModels() : super(code: _code);

  static const _code = LintCode(
    name: 'prefer_json_http_models',
    problemMessage:
        'JsonHttp.list / bodyList eagerly wrap every element — slow for large arrays.',
    correctionMessage: 'Use JsonHttp.models / modelsBody for lazy JsonModelList.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    if (isTestPath(resolver)) return;
    context.registry.addMethodInvocation((node) {
      if (!isJsonHttpStaticCall(node)) return;
      final name = node.methodName.name;
      if (name != 'list' && name != 'bodyList') return;
      reporter.atNode(node.methodName, code);
    });
  }
}
