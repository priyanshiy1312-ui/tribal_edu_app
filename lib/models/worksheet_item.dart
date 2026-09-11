class WorksheetItem {
  final String id;
  final String topic;
  final String hindiText;
  final String santaliText;

  WorksheetItem({
    required this.id,
    required this.topic,
    required this.hindiText,
    required this.santaliText,
  });

  factory WorksheetItem.fromJson(Map<String, dynamic> json) {
    return WorksheetItem(
      id: json['id'] as String,
      topic: json['topic'] as String,
      hindiText: json['hindi_text'] as String,
      santaliText: json['santali_text'] as String,
    );
  }
}