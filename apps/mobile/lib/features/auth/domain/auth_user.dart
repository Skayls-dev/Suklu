import 'user_role.dart';

// Immutable domain model for the currently authenticated user.
// Sourced from the /users/{uid} Firestore document, not Firebase Auth directly,
// so it always includes the application role.
class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.isActive,
    this.phoneNumber,
    this.photoUrl,
    this.country,
    this.isContentModerator = false,
  });

  final String   uid;
  final String   email;
  final String   displayName;
  final UserRole role;
  final bool     isActive;
  final String?  phoneNumber;
  final String?  photoUrl;
  final String?  country;
  // True when super_admin has granted this account content moderation access.
  // Independent of the main role — a tutor can also be a content moderator.
  final bool     isContentModerator;

  bool get canModeratContent => isContentModerator || role == UserRole.superAdmin;

  factory AuthUser.fromFirestore(Map<String, dynamic> data) => AuthUser(
    uid:                 data['uid']                as String,
    email:               data['email']              as String,
    displayName:         data['displayName']        as String,
    role:                UserRole.fromString(data['role'] as String),
    isActive:            (data['isActive']          as bool?)   ?? true,
    phoneNumber:         data['phoneNumber']        as String?,
    photoUrl:            data['photoUrl']           as String?,
    country:             data['country']            as String?,
    isContentModerator:  (data['isContentModerator'] as bool?)  ?? false,
  );

  AuthUser copyWith({
    String?   displayName,
    bool?     isActive,
    String?   phoneNumber,
    String?   photoUrl,
    String?   country,
    bool?     isContentModerator,
  }) => AuthUser(
    uid:                uid,
    email:              email,
    displayName:        displayName        ?? this.displayName,
    role:               role,
    isActive:           isActive           ?? this.isActive,
    phoneNumber:        phoneNumber        ?? this.phoneNumber,
    photoUrl:           photoUrl           ?? this.photoUrl,
    country:            country            ?? this.country,
    isContentModerator: isContentModerator ?? this.isContentModerator,
  );
}
