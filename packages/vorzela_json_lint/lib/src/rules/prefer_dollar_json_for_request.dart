import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils.dart';

class PreferDollarJsonForRequest extends DartLintRule {
  const PreferDollarJsonForRequest() : super(code: _code);

  static const _code = LintCode(
    name: 'prefer_dollar_json_for_request',
    problemMessage:
        'toJson() deep-copies the bag on every request when values are already JSON-safe.',
    correctionMessage:
        'Use model.asRequestData or model.\$json for dio.post(..., data: …).',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'toJson') return;
      if (!isRequestPayloadNamedArg(node)) return;
      final receiver = node.target;
      if (receiver == null) return;
      if (!isJsonModelDartType(receiver.staticType)) return;
      reporter.atNode(node.methodName, code);
    });
  }
}
