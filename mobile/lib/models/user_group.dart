import 'package:equatable/equatable.dart';

class UserGroup extends Equatable {
  const UserGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.memberCount,
  });

  final String id;
  final String name;
  final String description;
  final int memberCount;

  factory UserGroup.fromJson(Map<String, dynamic> json) {
    final members = json['members'] as List<dynamic>;
    return UserGroup(
      id: json['id'].toString(),
      name: json['name'] as String,
      description: '',
      memberCount: members.length,
    );
  }

  @override
  List<Object?> get props => [id, name, description, memberCount];
}
