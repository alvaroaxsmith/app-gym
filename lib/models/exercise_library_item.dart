/// Represents a pre-defined exercise from the library
class ExerciseLibraryItem {
  ExerciseLibraryItem({
    required this.id,
    required this.name,
    required this.muscleGroup,
    this.description,
    this.difficultyLevel,
    this.equipment,
    this.instructions,
    this.imageUrl,
    this.videoUrl,
  });

  final String id;
  final String name;
  final String muscleGroup;
  final String? description;
  final String? difficultyLevel;
  final String? equipment;
  final String? instructions;
  final String? imageUrl;
  final String? videoUrl;

  factory ExerciseLibraryItem.fromMap(Map<String, dynamic> map) {
    return ExerciseLibraryItem(
      id: map['id'] as String,
      name: map['name'] as String,
      muscleGroup: map['muscle_group'] as String,
      description: map['description'] as String?,
      difficultyLevel: map['difficulty_level'] as String?,
      equipment: map['equipment'] as String?,
      instructions: map['instructions'] as String?,
      imageUrl: map['image_url'] as String?,
      videoUrl: map['video_url'] as String?,
    );
  }

  String get difficultyLabel {
    switch (difficultyLevel) {
      case 'beginner':
        return 'Iniciante';
      case 'intermediate':
        return 'Intermediário';
      case 'advanced':
        return 'Avançado';
      default:
        return 'Não especificado';
    }
  }
}
