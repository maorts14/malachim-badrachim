import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_app/models/alert_message.dart';
import 'package:rescue_app/models/message.dart';
import 'package:rescue_app/models/user_group.dart';

void main() {
  final corpus = jsonDecode(
    File('../contracts/alert-group-message.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('parses the shared Alert, Group, and Message API contract examples', () {
    final alert = AlertMessage.fromJson(corpus['alert'] as Map<String, dynamic>);
    final group = UserGroup.fromJson(corpus['group'] as Map<String, dynamic>);
    final message = Message.fromJson(corpus['message'] as Map<String, dynamic>);

    expect(alert.status, 'DISPATCHED');
    expect(alert.priority, 'HIGH');
    expect(group.memberCount, 2);
    expect(message.alertId, 42);
    expect(message.groupId, isNull);
    expect(message.latitude, isNull);
  });
}
