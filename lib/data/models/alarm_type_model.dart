class AlarmTypeModel {
  final int id;
  final String name;
  final String? filePath;
  final String? description;

  const AlarmTypeModel({
    required this.id,
    required this.name,
    this.filePath,
    this.description,
  });

  factory AlarmTypeModel.fromMap(Map<String, dynamic> map) {
    return AlarmTypeModel(
      id: (map['id'] as num).toInt(),
      name: map['name'] as String? ?? 'Alarma Estándar',
      filePath: map['file_path'] as String?,
      description: map['description'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'file_path': filePath,
      'description': description,
    };
  }
}
