class EmergencyContactModel {
  final String? id;
  final String userId;
  final String contactName;
  final String phoneNumber;
  final String? relationship;
  final bool isPrimary;

  const EmergencyContactModel({
    this.id,
    required this.userId,
    required this.contactName,
    required this.phoneNumber,
    this.relationship = 'Familiar',
    this.isPrimary = false,
  });

  factory EmergencyContactModel.fromMap(Map<String, dynamic> map) {
    return EmergencyContactModel(
      id: map['id'] as String?,
      userId: map['user_id'] as String,
      contactName: map['contact_name'] as String? ?? '',
      phoneNumber: map['phone_number'] as String? ?? '',
      relationship: map['relationship'] as String? ?? 'Familiar',
      isPrimary: map['is_primary'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'user_id': userId,
      'contact_name': contactName,
      'phone_number': phoneNumber,
      'relationship': relationship,
      'is_primary': isPrimary,
    };
    if (id != null) {
      data['id'] = id;
    }
    return data;
  }

  EmergencyContactModel copyWith({
    String? id,
    String? contactName,
    String? phoneNumber,
    String? relationship,
    bool? isPrimary,
  }) {
    return EmergencyContactModel(
      id: id ?? this.id,
      userId: userId,
      contactName: contactName ?? this.contactName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      relationship: relationship ?? this.relationship,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}
