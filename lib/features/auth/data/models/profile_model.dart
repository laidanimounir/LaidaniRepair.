/// Dart model for the `profiles` table joined with `roles`.
class ProfileModel {
  final String id;
  final String fullName;
  final String roleName; // 'owner' | 'worker'
  final String? phoneNumber;
  final bool isActive;

  const ProfileModel({
    required this.id,
    required this.fullName,
    required this.roleName,
    this.phoneNumber,
    required this.isActive,
  });

  /// True when the user is an owner (has access to all screens).
  bool get isOwner => roleName == 'owner';

  /// Parses the result of:
  ///   supabase.from('profiles').select('*, roles(role_name)').single()
  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    // roles column is returned as a nested Map by Supabase
    final rolesData = json['roles'];
    final roleName = (rolesData is Map<String, dynamic>)
        ? (rolesData['role_name'] as String? ?? 'worker')
        : 'worker';

    return ProfileModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? 'Utilisateur',
      roleName: roleName,
      phoneNumber: json['phone_number'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  @override
  String toString() =>
      'ProfileModel(id: $id, fullName: $fullName, role: $roleName)';
}
