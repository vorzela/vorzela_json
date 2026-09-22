import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

bool isTestPath(CustomLintResolver resolver) {
  final path = resolver.source.fullName.replaceAll(r'\', '/');
  return path.contains('/test/') || path.endsWith('_test.dart');
}

final jsonModelType = TypeChecker.fromName(
  'JsonModel',
  packageName: 'vorzela_json',
);

final jsonHttpType = TypeChecker.fromName(
  'JsonHttp',
  packageName: 'vorzela_json',
);

bool isJsonModelDartType(DartType? type) {
  if (type == null) return false;
  if (jsonModelType.isAssignableFromType(type)) return true;
  final s = type.getDisplayString();
  return s.endsWith('JsonModel') || s.contains('JsonModel<');
}

bool isJsonHttpStaticCall(MethodInvocation node) {
  final target = node.target;
  if (target is SimpleIdentifier && target.name == 'JsonHttp') return true;
  if (target is PrefixedIdentifier && target.identifier.name == 'JsonHttp') {
    return true;
  }
  return false;
}

const shallowReadAfterModel = {
  r'$str',
  r'$strOrNull',
  r'$int',
  r'$intOrNull',
  r'$bool',
  r'$double',
  r'$doubleOrNull',
  r'$bytes',
  r'$uri',
  r'$dateTime',
  r'$duration',
  r'$bigInt',
  r'$list',
};

bool isEnumValuesExpression(Expression expression) {
  if (expression is PropertyAccess) {
    return expression.propertyName.name == 'values';
  }
  if (expression is PrefixedIdentifier) {
    return expression.identifier.name == 'values';
  }
  final src = expression.toSource().trim();
  return src.endsWith('.values');
}

bool isRequestPayloadNamedArg(AstNode toJsonNode) {
  final parent = toJsonNode.parent;
  if (parent is! NamedExpression) return false;
  final label = parent.name.label.name;
  if (label != 'data' && label != 'body') return false;
  final argList = parent.parent;
  if (argList is! ArgumentList) return false;
  final call = argList.parent;
  if (call is! MethodInvocation) return false;
  final method = call.methodName.name;
  return method == 'post' || method == 'put' || method == 'patch';
}

String? dollarBagProperty(Expression expression) {
  if (expression is SimpleIdentifier) {
    final name = expression.name;
    if (name == r'$json' || name == r'$data') return name;
  }
  if (expression is PrefixedIdentifier) {
    final name = expression.identifier.name;
    if (name == r'$json' || name == r'$data') return name;
  }
  if (expression is PropertyAccess) {
    final name = expression.propertyName.name;
    if (name == r'$json' || name == r'$data') return name;
  }
  return null;
}
