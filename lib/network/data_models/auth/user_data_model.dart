/// Data model for Student/Guardian authentication response from the API
class UserDataModel {
  final int status;
  final String? error;
  final String? authenticator;
  final String? redirectTo;
  final List<UserResult>? results;

  UserDataModel({
    required this.status,
    this.error,
    this.authenticator,
    this.redirectTo,
    this.results,
  });

  /// Helper method to safely convert value to String
  static String? _toString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.isEmpty ? null : value;
    if (value is bool) return value ? 'true' : null;
    if (value is num) return value.toString();
    return value.toString();
  }

  /// Helper method to safely convert value to int
  static int _toInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? defaultValue;
    }
    if (value is num) return value.toInt();
    return defaultValue;
  }

  /// Creates UserDataModel from JSON response
  factory UserDataModel.fromJson(Map<String, dynamic> json) {
    List<UserResult>? resultsList;
    if (json['result'] != null) {
      if (json['result'] is List) {
        resultsList = (json['result'] as List)
            .map((item) => UserResult.fromJson(item as Map<String, dynamic>))
            .toList();
      } else if (json['result'] is Map) {
        // Handle case where result might be a single object instead of array
        resultsList = [UserResult.fromJson(json['result'] as Map<String, dynamic>)];
      }
    }

    return UserDataModel(
      status: _toInt(json['status']),
      error: _toString(json['error']),
      authenticator: _toString(json['authenticator']),
      redirectTo: _toString(json['redirect_to']),
      results: resultsList,
    );
  }

  /// Converts UserDataModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'error': error,
      'authenticator': authenticator,
      'redirect_to': redirectTo,
      'result': results?.map((r) => r.toJson()).toList(),
    };
  }

  /// Checks if the authentication was successful
  bool get isSuccess => status == 2 && results != null && results!.isNotEmpty;

  /// Checks if there was an error
  bool get hasError => status != 2 || error != null;

  /// Gets the first result (primary user)
  UserResult? get firstResult => results != null && results!.isNotEmpty ? results!.first : null;
}

/// Data model for the user result object in the API response
class UserResult {
  final int id;
  final int userId;
  final String? username;
  final String? password;
  final String? childs;
  final String? role;
  final int langId;
  final int currencyId;
  final String? verificationCode;
  final String? isActive;
  final String? createdAt;
  final String? updatedAt;
  final String? language;
  final String? firstname;
  final String? middlename;
  final String? image;
  final String? lastname;
  final String? guardianName;
  final String? gender;
  final String? admissionNo;
  final String? email;
  final String? currencyName;
  final String? symbol;
  final String? basePrice;
  final String? currency;

  UserResult({
    required this.id,
    required this.userId,
    this.username,
    this.password,
    this.childs,
    this.role,
    required this.langId,
    required this.currencyId,
    this.verificationCode,
    this.isActive,
    this.createdAt,
    this.updatedAt,
    this.language,
    this.firstname,
    this.middlename,
    this.image,
    this.lastname,
    this.guardianName,
    this.gender,
    this.admissionNo,
    this.email,
    this.currencyName,
    this.symbol,
    this.basePrice,
    this.currency,
  });

  /// Helper method to safely convert value to String
  static String? _toString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.isEmpty ? null : value;
    if (value is bool) return value ? 'true' : null;
    if (value is num) return value.toString();
    return value.toString();
  }

  /// Helper method to safely convert value to int
  static int _toInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? defaultValue;
    }
    if (value is num) return value.toInt();
    return defaultValue;
  }

  /// Creates UserResult from JSON
  factory UserResult.fromJson(Map<String, dynamic> json) {
    return UserResult(
      id: _toInt(json['id']),
      userId: _toInt(json['user_id']),
      username: _toString(json['username']),
      password: _toString(json['password']),
      childs: _toString(json['childs']),
      role: _toString(json['role']),
      langId: _toInt(json['lang_id']),
      currencyId: _toInt(json['currency_id']),
      verificationCode: _toString(json['verification_code']),
      isActive: _toString(json['is_active']),
      createdAt: _toString(json['created_at']),
      updatedAt: _toString(json['updated_at']),
      language: _toString(json['language']),
      firstname: _toString(json['firstname']),
      middlename: _toString(json['middlename']),
      image: _toString(json['image']),
      lastname: _toString(json['lastname']),
      guardianName: _toString(json['guardian_name']),
      gender: _toString(json['gender']),
      admissionNo: _toString(json['admission_no']),
      email: _toString(json['email']),
      currencyName: _toString(json['currency_name']),
      symbol: _toString(json['symbol']),
      basePrice: _toString(json['base_price']),
      currency: _toString(json['currency']),
    );
  }

  /// Converts UserResult to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'username': username,
      'password': password,
      'childs': childs,
      'role': role,
      'lang_id': langId,
      'currency_id': currencyId,
      'verification_code': verificationCode,
      'is_active': isActive,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'language': language,
      'firstname': firstname,
      'middlename': middlename,
      'image': image,
      'lastname': lastname,
      'guardian_name': guardianName,
      'gender': gender,
      'admission_no': admissionNo,
      'email': email,
      'currency_name': currencyName,
      'symbol': symbol,
      'base_price': basePrice,
      'currency': currency,
    };
  }

  /// Gets the full name from firstname, middlename, and lastname
  String get fullName {
    final parts = <String>[];
    if (firstname != null && firstname!.isNotEmpty) parts.add(firstname!);
    if (middlename != null && middlename!.isNotEmpty) parts.add(middlename!);
    if (lastname != null && lastname!.isNotEmpty) parts.add(lastname!);
    return parts.isNotEmpty ? parts.join(' ') : (username ?? '');
  }

  /// Checks if user is a student
  bool get isStudent => role?.toLowerCase() == 'student';

  /// Checks if user is a guardian
  bool get isGuardian => role?.toLowerCase() == 'guardian';

  /// Checks if account is active
  bool get active => isActive?.toLowerCase() == 'yes';
}
