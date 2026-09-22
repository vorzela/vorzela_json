import 'package:vorzela_json/vorzela_json.dart';

enum Role { admin, member }

class User extends JsonModel {
  User([super.data]);
  User.fromJson(super.json) : super.fromJson();

  Role get role => $enumAt('role', among: Role.values, or: Role.member);

  String deepName() {
    // expect_lint: prefer_str_at_for_deep_field
    return $model('photo', JsonFile.new).$str('name');
  }

  void nestedChain() {
    // expect_lint: avoid_nested_json_model_chain
    $model('a', User.fromJson).$model('b', User.fromJson);
  }
}

void fetchCatalog(Object data) {
  // expect_lint: prefer_json_http_models
  JsonHttp.list(data, User.fromJson);
}

Future<void> saveUser(dynamic dio, User user) async {
  // expect_lint: prefer_dollar_json_for_request
  await dio.post('/users', data: user.toJson());
}

void readRole(User user) {
  // expect_lint: prefer_enum_values_in_enum_at
  user.$enumAt('role', among: [Role.admin], or: Role.member);
}

void mutateBag(User user) {
  // expect_lint: avoid_mutating_dollar_json
  user.$json['name'] = 'Ada';
}
