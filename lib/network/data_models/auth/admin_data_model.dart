/// Data model for Admin/Teacher authentication response from the API
class AdminDataModel {
  final int status;
  final String? error;
  final String? authenticator;
  final String? redirectTo;
  final AdminResult? result;

  AdminDataModel({
    required this.status,
    this.error,
    this.authenticator,
    this.redirectTo,
    this.result,
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

  /// Creates AdminDataModel from JSON response
  factory AdminDataModel.fromJson(Map<String, dynamic> json) {
    return AdminDataModel(
      status: _toInt(json['status']),
      error: _toString(json['error']),
      authenticator: _toString(json['authenticator']),
      redirectTo: _toString(json['redirect_to']),
      result: json['result'] != null && json['result'] is Map
          ? AdminResult.fromJson(json['result'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Converts AdminDataModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'error': error,
      'authenticator': authenticator,
      'redirect_to': redirectTo,
      'result': result?.toJson(),
    };
  }

  /// Checks if the authentication was successful
  bool get isSuccess => status == 2 && result != null;

  /// Checks if there was an error
  bool get hasError => status != 2 || error != null;
}

/// Data model for the result object in the API response
class AdminResult {
  final int id;
  final String? employeeId;
  final int langId;
  final int currencyId;
  final String? department;
  final String? designation;
  final String? qualification;
  final String? workExp;
  final String? name;
  final String? surname;
  final String? fatherName;
  final String? motherName;
  final String? contactNo;
  final String? emergencyContactNo;
  final String? email;
  final String? dob;
  final String? maritalStatus;
  final String? dateOfJoining;
  final String? dateOfLeaving;
  final String? localAddress;
  final String? permanentAddress;
  final String? note;
  final String? image;
  final String? password;
  final String? gender;
  final String? accountTitle;
  final String? bankAccountNo;
  final String? bankName;
  final String? ifscCode;
  final String? bankBranch;
  final String? payscale;
  final String? basicSalary;
  final String? epfNo;
  final String? contractType;
  final String? shift;
  final String? location;
  final String? facebook;
  final String? twitter;
  final String? linkedin;
  final String? instagram;
  final String? resume;
  final String? joiningLetter;
  final String? resignationLetter;
  final String? otherDocumentName;
  final String? otherDocumentFile;
  final int userId;
  final int isActive;
  final String? verificationCode;
  final String? zoomApiKey;
  final String? zoomApiSecret;
  final String? disableAt;
  final String? createdAt;
  final String? updatedAt;
  final String? language;
  final String? languageId;
  final String? isRtl;
  final String? currencyName;
  final String? symbol;
  final String? basePrice;
  final String? currency;
  final Map<String, dynamic>? roles;

  AdminResult({
    required this.id,
    this.employeeId,
    required this.langId,
    required this.currencyId,
    this.department,
    this.designation,
    this.qualification,
    this.workExp,
    this.name,
    this.surname,
    this.fatherName,
    this.motherName,
    this.contactNo,
    this.emergencyContactNo,
    this.email,
    this.dob,
    this.maritalStatus,
    this.dateOfJoining,
    this.dateOfLeaving,
    this.localAddress,
    this.permanentAddress,
    this.note,
    this.image,
    this.password,
    this.gender,
    this.accountTitle,
    this.bankAccountNo,
    this.bankName,
    this.ifscCode,
    this.bankBranch,
    this.payscale,
    this.basicSalary,
    this.epfNo,
    this.contractType,
    this.shift,
    this.location,
    this.facebook,
    this.twitter,
    this.linkedin,
    this.instagram,
    this.resume,
    this.joiningLetter,
    this.resignationLetter,
    this.otherDocumentName,
    this.otherDocumentFile,
    required this.userId,
    required this.isActive,
    this.verificationCode,
    this.zoomApiKey,
    this.zoomApiSecret,
    this.disableAt,
    this.createdAt,
    this.updatedAt,
    this.language,
    this.languageId,
    this.isRtl,
    this.currencyName,
    this.symbol,
    this.basePrice,
    this.currency,
    this.roles,
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

  /// Creates AdminResult from JSON
  factory AdminResult.fromJson(Map<String, dynamic> json) {
    return AdminResult(
      id: _toInt(json['id']),
      employeeId: _toString(json['employee_id']),
      langId: _toInt(json['lang_id']),
      currencyId: _toInt(json['currency_id']),
      department: _toString(json['department']),
      designation: _toString(json['designation']),
      qualification: _toString(json['qualification']),
      workExp: _toString(json['work_exp']),
      name: _toString(json['name']),
      surname: _toString(json['surname']),
      fatherName: _toString(json['father_name']),
      motherName: _toString(json['mother_name']),
      contactNo: _toString(json['contact_no']),
      emergencyContactNo: _toString(json['emergency_contact_no']),
      email: _toString(json['email']),
      dob: _toString(json['dob']),
      maritalStatus: _toString(json['marital_status']),
      dateOfJoining: _toString(json['date_of_joining']),
      dateOfLeaving: _toString(json['date_of_leaving']),
      localAddress: _toString(json['local_address']),
      permanentAddress: _toString(json['permanent_address']),
      note: _toString(json['note']),
      image: _toString(json['image']),
      password: _toString(json['password']),
      gender: _toString(json['gender']),
      accountTitle: _toString(json['account_title']),
      bankAccountNo: _toString(json['bank_account_no']),
      bankName: _toString(json['bank_name']),
      ifscCode: _toString(json['ifsc_code']),
      bankBranch: _toString(json['bank_branch']),
      payscale: _toString(json['payscale']),
      basicSalary: _toString(json['basic_salary']),
      epfNo: _toString(json['epf_no']),
      contractType: _toString(json['contract_type']),
      shift: _toString(json['shift']),
      location: _toString(json['location']),
      facebook: _toString(json['facebook']),
      twitter: _toString(json['twitter']),
      linkedin: _toString(json['linkedin']),
      instagram: _toString(json['instagram']),
      resume: _toString(json['resume']),
      joiningLetter: _toString(json['joining_letter']),
      resignationLetter: _toString(json['resignation_letter']),
      otherDocumentName: _toString(json['other_document_name']),
      otherDocumentFile: _toString(json['other_document_file']),
      userId: _toInt(json['user_id']),
      isActive: _toInt(json['is_active']),
      verificationCode: _toString(json['verification_code']),
      zoomApiKey: _toString(json['zoom_api_key']),
      zoomApiSecret: _toString(json['zoom_api_secret']),
      disableAt: _toString(json['disable_at']),
      createdAt: _toString(json['created_at']),
      updatedAt: _toString(json['updated_at']),
      language: _toString(json['language']),
      languageId: _toString(json['language_id']),
      isRtl: _toString(json['is_rtl']),
      currencyName: _toString(json['currency_name']),
      symbol: _toString(json['symbol']),
      basePrice: _toString(json['base_price']),
      currency: _toString(json['currency']),
      roles: json['roles'] is Map ? json['roles'] as Map<String, dynamic>? : null,
    );
  }

  /// Converts AdminResult to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'lang_id': langId,
      'currency_id': currencyId,
      'department': department,
      'designation': designation,
      'qualification': qualification,
      'work_exp': workExp,
      'name': name,
      'surname': surname,
      'father_name': fatherName,
      'mother_name': motherName,
      'contact_no': contactNo,
      'emergency_contact_no': emergencyContactNo,
      'email': email,
      'dob': dob,
      'marital_status': maritalStatus,
      'date_of_joining': dateOfJoining,
      'date_of_leaving': dateOfLeaving,
      'local_address': localAddress,
      'permanent_address': permanentAddress,
      'note': note,
      'image': image,
      'password': password,
      'gender': gender,
      'account_title': accountTitle,
      'bank_account_no': bankAccountNo,
      'bank_name': bankName,
      'ifsc_code': ifscCode,
      'bank_branch': bankBranch,
      'payscale': payscale,
      'basic_salary': basicSalary,
      'epf_no': epfNo,
      'contract_type': contractType,
      'shift': shift,
      'location': location,
      'facebook': facebook,
      'twitter': twitter,
      'linkedin': linkedin,
      'instagram': instagram,
      'resume': resume,
      'joining_letter': joiningLetter,
      'resignation_letter': resignationLetter,
      'other_document_name': otherDocumentName,
      'other_document_file': otherDocumentFile,
      'user_id': userId,
      'is_active': isActive,
      'verification_code': verificationCode,
      'zoom_api_key': zoomApiKey,
      'zoom_api_secret': zoomApiSecret,
      'disable_at': disableAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'language': language,
      'language_id': languageId,
      'is_rtl': isRtl,
      'currency_name': currencyName,
      'symbol': symbol,
      'base_price': basePrice,
      'currency': currency,
      'roles': roles,
    };
  }

  /// Gets the full name from name and surname
  String get fullName {
    if (name != null && surname != null) {
      return '$name $surname'.trim();
    }
    return name ?? surname ?? '';
  }

  /// Checks if user has Teacher role
  bool get isTeacher {
    if (roles == null) return false;
    return roles!.containsKey('Teacher');
  }

  /// Checks if user has Admin role
  bool get isAdmin {
    if (roles == null) return false;
    return roles!.containsKey('Admin') || roles!.containsKey('admin');
  }

  /// Gets the primary role (Teacher or Admin)
  String? get primaryRole {
    if (roles == null) return null;
    if (roles!.containsKey('Admin') || roles!.containsKey('admin')) {
      return 'admin';
    }
    if (roles!.containsKey('Teacher')) {
      return 'teacher';
    }
    return roles!.keys.first;
  }
}
