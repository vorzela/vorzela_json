import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils.dart';

class AvoidMutatingDollarJson extends DartLintRule {
  const AvoidMutatingDollarJson() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_mutating_dollar_json',
    problemMessage:
        'Do not assign into \$json / \$data — use \$set on the JsonModel instead.',
    correctionMessage: 'Use \$set(\'key\', value) so nested caches stay consistent.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((unit) {
      unit.accept(_MutatingBagVisitor(reporter, code));
    });
  }
}

class _MutatingBagVisitor extends RecursiveAstVisitor<void> {
  _MutatingBagVisitor(this.reporter, this.code);

  final ErrorReporter reporter;
  final LintCode code;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final left = node.leftHandSide;
    if (left is IndexExpression &&
        dollarBagProperty(left.realTarget) != null) {
      reporter.atNode(left, code);
    }
    super.visitAssignmentExpression(node);
  }
}
