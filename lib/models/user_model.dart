class AppUser {
  final String uid;
  final String email;
  final String name;
  final String role; // 'student', 'faculty', or 'admin'
  final DateTime? createdAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, String id) {
    return AppUser(
      uid: id,
      email: map['email'] as String? ?? '',
      name: map['name'] as String? ?? map['email']?.toString().split('@')[0] ?? 'Unknown',
      role: map['role'] as String? ?? 'student',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as dynamic).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
    };
  }

  bool get isAdmin => role == 'admin' || role == 'official';
  bool get isFaculty => role == 'faculty';
  bool get isStudent => role == 'student';
}
