import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:learining_portal/network/data_models/auth/admin_data_model.dart';
import 'package:learining_portal/network/data_models/auth/user_data_model.dart';
import '../providers/auth_provider.dart';

class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? firstName;
  final String? lastName;
  final String? phoneNumber;
  final String? photoUrl;
  final UserType userType;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? additionalData;

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.photoUrl,
    required this.userType,
    this.createdAt,
    this.updatedAt,
    this.additionalData,
  });

  // Get full name
  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return displayName ?? email.split('@')[0];
  }

  // Convert UserModel to Firestore document
  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'uid': uid,
      'email': email,
      'userType': _userTypeToString(userType),
      if (displayName != null) 'displayName': displayName,
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (additionalData != null) ...additionalData!,
    };
    return map;
  }

  // Create UserModel from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap(data, doc.id);
  }

  // Create UserModel from Map
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String?,
      firstName: map['firstName'] as String?,
      lastName: map['lastName'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      photoUrl: map['photoUrl'] as String?,
      userType: _stringToUserType(map['userType'] as String? ?? 'student'),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      additionalData: map['additionalData'] as Map<String, dynamic>?,
    );
  }

  // Create UserModel from Firebase Auth User
  factory UserModel.fromFirebaseUser(
    firebase_auth.User firebaseUser,
    UserType userType, {
    String? firstName,
    String? lastName,
    String? phoneNumber,
    Map<String, dynamic>? additionalData,
  }) {
    return UserModel(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber ?? firebaseUser.phoneNumber,
      photoUrl: firebaseUser.photoURL,
      userType: userType,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      additionalData: additionalData,
    );
  }

  // Create UserModel from AdminDataModel (API response)
  factory UserModel.fromAdminDataModel(AdminDataModel adminData) {
    if (adminData.result == null) {
      throw ArgumentError('AdminDataModel result cannot be null');
    }

    final result = adminData.result!;

    // Determine user type from roles
    UserType userType;
    if (result.isAdmin) {
      userType = UserType.admin;
    } else if (result.isTeacher) {
      userType = UserType.teacher;
    } else {
      // Default to teacher if roles are not clear
      userType = UserType.teacher;
    }

    // Parse name into first and last name
    String? firstName;
    String? lastName;
    if (result.name != null) {
      final nameParts = result.name!.trim().split(' ');
      if (nameParts.length > 1) {
        firstName = nameParts.first;
        lastName = nameParts.sublist(1).join(' ');
      } else {
        firstName = result.name;
      }
    }
    if (result.surname != null && result.surname!.isNotEmpty) {
      lastName = result.surname;
    }

    // Build additional data from admin result
    final additionalData = <String, dynamic>{
      'employee_id': result.employeeId,
      'department': result.department,
      'designation': result.designation,
      'gender': result.gender,
      'dob': result.dob,
      'roles': result.roles,
      'is_active': result.isActive,
      'created_at': result.createdAt,
      'updated_at': result.updatedAt,
    };

    // Parse dates
    DateTime? createdAt;
    DateTime? updatedAt;
    try {
      if (result.createdAt != null && result.createdAt!.isNotEmpty) {
        createdAt = DateTime.parse(result.createdAt!);
      }
      if (result.updatedAt != null && result.updatedAt!.isNotEmpty) {
        updatedAt = DateTime.parse(result.updatedAt!);
      }
    } catch (e) {
      // If date parsing fails, use current time
      createdAt = DateTime.now();
      updatedAt = DateTime.now();
    }

    // Build image URL if available
    String? photoUrl;
    if (result.image != null && result.image!.isNotEmpty) {
      // If image is a full URL, use it; otherwise construct it
      if (result.image!.startsWith('http')) {
        photoUrl = result.image;
      } else {
        photoUrl = 'https://portal.gcsewithrosi.co.uk${result.image}';
      }
    }

    return UserModel(
      uid: result.id.toString(), // Use admin ID as UID
      email: result.email ?? '',
      displayName: result.fullName.isNotEmpty ? result.fullName : result.name,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: result.contactNo,
      photoUrl: photoUrl,
      userType: userType,
      createdAt: createdAt,
      updatedAt: updatedAt,
      additionalData: additionalData,
    );
  }

  // Create UserModel from UserDataModel (API response for Student/Guardian)
  factory UserModel.fromUserDataModel(
    UserDataModel userData,
    UserType userType,
  ) {
    if (userData.firstResult == null) {
      throw ArgumentError('UserDataModel result cannot be null');
    }

    final result = userData.firstResult!;

    // Verify user type matches
    if (userType == UserType.student && !result.isStudent) {
      throw ArgumentError(
        'User type mismatch: expected student but got ${result.role}',
      );
    }
    if (userType == UserType.guardian && !result.isGuardian) {
      throw ArgumentError(
        'User type mismatch: expected guardian but got ${result.role}',
      );
    }

    // Build additional data from user result
    final additionalData = <String, dynamic>{
      'user_id': result.userId,
      'username': result.username,
      'admission_no': result.admissionNo,
      'guardian_name': result.guardianName,
      'gender': result.gender,
      'language': result.language,
      'lang_id': result.langId,
      'currency_id': result.currencyId,
      'is_active': result.isActive,
      'created_at': result.createdAt,
      'updated_at': result.updatedAt,
      'childs': result.childs,
    };

    // Parse dates
    DateTime? createdAt;
    DateTime? updatedAt;
    try {
      if (result.createdAt != null && result.createdAt!.isNotEmpty) {
        createdAt = DateTime.parse(result.createdAt!);
      }
      if (result.updatedAt != null && result.updatedAt!.isNotEmpty) {
        updatedAt = DateTime.parse(result.updatedAt!);
      }
    } catch (e) {
      // If date parsing fails, use current time
      createdAt = DateTime.now();
      updatedAt = DateTime.now();
    }

    // Build image URL if available
    String? photoUrl;
    if (result.image != null && result.image!.isNotEmpty) {
      // If image is a full URL, use it; otherwise construct it
      if (result.image!.startsWith('http')) {
        photoUrl = result.image;
      } else {
        photoUrl = 'https://portal.gcsewithrosi.co.uk${result.image}';
      }
    }

    return UserModel(
      uid: result.id.toString(), // Use user ID as UID
      email: result.email ?? result.username ?? '',
      displayName: result.fullName.isNotEmpty
          ? result.fullName
          : result.username,
      firstName: result.firstname,
      lastName: result.lastname,
      phoneNumber: null, // Not available in student/guardian response
      photoUrl: photoUrl,
      userType: userType,
      createdAt: createdAt,
      updatedAt: updatedAt,
      additionalData: additionalData,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'userType': _userTypeToString(userType),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'additionalData': additionalData,
    };
  }

  // Create from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      photoUrl: json['photoUrl'] as String?,
      userType: _stringToUserType(json['userType'] as String? ?? 'student'),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      additionalData: json['additionalData'] as Map<String, dynamic>?,
    );
  }

  // Copy with method for updating fields
  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? photoUrl,
    UserType? userType,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? additionalData,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      userType: userType ?? this.userType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      additionalData: additionalData ?? this.additionalData,
    );
  }

  // Helper methods for UserType conversion
  static String _userTypeToString(UserType userType) {
    switch (userType) {
      case UserType.student:
        return 'student';
      case UserType.guardian:
        return 'guardian';
      case UserType.teacher:
        return 'teacher';
      case UserType.admin:
        return 'admin';
    }
  }

  static UserType _stringToUserType(String type) {
    switch (type.toLowerCase()) {
      case 'student':
        return UserType.student;
      case 'guardian':
        return UserType.guardian;
      case 'teacher':
        return UserType.teacher;
      case 'admin':
        return UserType.admin;
      default:
        return UserType.student;
    }
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, fullName: $fullName, userType: ${_userTypeToString(userType)})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;
}
