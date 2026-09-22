import 'package:vorzela_json/vorzela_json.dart';

enum Role { admin, member }

class User extends JsonModel {
  User([super.data]);
  User.fromJson(super.json) : super.fromJson();

  Role get role => $enumAt('role', among: Role.values, or: Role.member);

  String deepName() => $strAt('photo.name');

  String nestedRead() => $strAt('a.b.x');
}

void fetchCatalog(Object data) {
  JsonHttp.models(data, User.fromJson);
}

Future<void> saveUser(dynamic dio, User user) async {
  await dio.post('/users', data: user.asRequestData);
}

void mutate(User user) {
  user.$set('name', 'Ada');
}
