import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_app/models/user_group.dart';

void main() {
  test('parses the group contract returned by the API', () {
    final group = UserGroup.fromJson(<String, dynamic>{
      'id': 7,
      'name': 'PTT responders',
      'members': <int>[12, 20, 31],
    });

    expect(group.id, '7');
    expect(group.name, 'PTT responders');
    expect(group.description, '');
    expect(group.memberCount, 3);
  });
}
