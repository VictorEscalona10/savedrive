class UserModel {
  final String id;
  final String email;
  final String? fullName;
  final String? bloodType;
  final String? medicalNotes;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.email,
    this.fullName,
    this.bloodType,
    this.medicalNotes,
    this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      email: map['email'] as String? ?? '',
      fullName: map['full_name'] as String?,
      bloodType: map['blood_type'] as String?,
      medicalNotes: map['medical_notes'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'blood_type': bloodType,
      'medical_notes': medicalNotes,
    };
  }

  UserModel copyWith({
    String? fullName,
    String? bloodType,
    String? medicalNotes,
  }) {
    return UserModel(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      bloodType: bloodType ?? this.bloodType,
      medicalNotes: medicalNotes ?? this.medicalNotes,
      createdAt: createdAt,
    );
  }
}
