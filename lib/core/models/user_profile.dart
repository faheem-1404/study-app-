import 'dart:convert';

class UserProfile {
  const UserProfile({required this.name, required this.college});

  final String name;
  final String college;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'name': name,
        'college': college,
      };

  String toJson() => jsonEncode(toMap());

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      name: map['name']?.toString() ?? '',
      college: map['college']?.toString() ?? '',
    );
  }

  factory UserProfile.fromJson(String source) {
    return UserProfile.fromMap(jsonDecode(source) as Map<String, dynamic>);
  }
}