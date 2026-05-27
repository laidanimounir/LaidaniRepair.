import 'package:laidani_repair/features/auth/data/models/technician_permissions.dart';

class ProfileModel {
  final String id;
  final String fullName;
  final String roleName;
  final String? phoneNumber;
  final bool isActive;
  final TechnicianPermissions permissions;

  const ProfileModel({
    required this.id,
    required this.fullName,
    required this.roleName,
    this.phoneNumber,
    required this.isActive,
    this.permissions = const TechnicianPermissions(),
  });

  bool get isOwner => roleName == 'owner';

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final rolesData = json['roles'];
    final roleName = (rolesData is Map<String, dynamic>)
        ? (rolesData['role_name'] as String? ?? 'worker')
        : 'worker';

    final perms = json['permissions'] is Map
        ? Map<String, dynamic>.from(json['permissions'] as Map)
        : null;

    return ProfileModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? 'Utilisateur',
      roleName: roleName,
      phoneNumber: json['phone_number'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      permissions: TechnicianPermissions.fromJson(perms),
    );
  }

  @override
  String toString() =>
      'ProfileModel(id: $id, fullName: $fullName, role: $roleName)';
}
