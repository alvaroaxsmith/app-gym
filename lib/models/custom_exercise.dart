class CustomExercise {
  CustomExercise({
    required this.id,
    required this.userId,
    required this.name,
    required this.muscleGroup,
    this.description,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String muscleGroup;
  final String? description;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CustomExercise.fromMap(Map<String, dynamic> map) {
    return CustomExercise(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      muscleGroup: map['muscle_group'] as String,
      description: map['description'] as String?,
      imageUrl: map['image_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'muscle_group': muscleGroup,
      'description': description,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Converte para formato de insert (sem id, createdAt, updatedAt)
  Map<String, dynamic> toInsertMap() {
    return {
      'user_id': userId,
      'name': name,
      'muscle_group': muscleGroup,
      if (description != null) 'description': description,
      if (imageUrl != null) 'image_url': imageUrl,
    };
  }

  /// Converte para formato de update (sem id, userId, createdAt)
  Map<String, dynamic> toUpdateMap() {
    return {
      'name': name,
      'muscle_group': muscleGroup,
      'description': description,
      'image_url': imageUrl,
    };
  }

  CustomExercise copyWith({
    String? id,
    String? userId,
    String? name,
    String? muscleGroup,
    String? description,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomExercise(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
