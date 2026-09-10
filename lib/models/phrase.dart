class Phrase {
  final int id;
  final String hindiPhrase;
  final String santaliPhrase;
  final String category;
  final String notes;

  Phrase({
    required this.id,
    required this.hindiPhrase,
    required this.santaliPhrase,
    required this.category,
    required this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hindi_phrase': hindiPhrase,
      'santali_phrase': santaliPhrase,
      'category': category,
      'notes': notes,
    };
  }

  factory Phrase.fromMap(Map<String, dynamic> map) {
    return Phrase(
      id: map['id'] as int,
      hindiPhrase: map['hindi_phrase'] as String,
      santaliPhrase: map['santali_phrase'] as String,
      category: map['category'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
    );
  }

  @override
  String toString() {
    return 'Phrase(id: $id, hindi: $hindiPhrase, santali: $santaliPhrase, category: $category)';
  }
}
class Phrase {
  final int id;
  final String hindiPhrase;
  final String santaliPhrase;
  final String category;
  final String notes;

  Phrase({
    required this.id,
    required this.hindiPhrase,
    required this.santaliPhrase,
    required this.category,
    required this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hindi_phrase': hindiPhrase,
      'santali_phrase': santaliPhrase,
      'category': category,
      'notes': notes,
    };
  }

  factory Phrase.fromMap(Map<String, dynamic> map) {
    return Phrase(
      id: map['id'] as int,
      hindiPhrase: map['hindi_phrase'] as String,
      santaliPhrase: map['santali_phrase'] as String,
      category: map['category'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
    );
  }

  @override
  String toString() {
    return 'Phrase(id: $id, hindi: $hindiPhrase, santali: $santaliPhrase, category: $category)';
  }
}
