// User roles — mirrors the roles in Firestore Security Rules and Cloud Functions
enum UserRole {
  student,
  parent,
  tutor,
  academicStaff,
  superAdmin;

  static UserRole fromString(String value) => switch (value) {
    'student'        => UserRole.student,
    'parent'         => UserRole.parent,
    'tutor'          => UserRole.tutor,
    'academic_staff' => UserRole.academicStaff,
    'super_admin'    => UserRole.superAdmin,
    _                => UserRole.student,
  };

  String toFirestoreString() => switch (this) {
    UserRole.student       => 'student',
    UserRole.parent        => 'parent',
    UserRole.tutor         => 'tutor',
    UserRole.academicStaff => 'academic_staff',
    UserRole.superAdmin    => 'super_admin',
  };

  // French display labels
  String get label => switch (this) {
    UserRole.student       => 'Étudiant',
    UserRole.parent        => 'Parent',
    UserRole.tutor         => 'Tuteur',
    UserRole.academicStaff => 'Personnel académique',
    UserRole.superAdmin    => 'Super administrateur',
  };
}
