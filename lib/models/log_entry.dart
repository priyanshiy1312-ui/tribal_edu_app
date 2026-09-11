class LogEntry {
  final int id;
  final String recognizedText;
  final int? matchedPhraseId;
  final String? matchedSantali;
  final double score;
  final bool isMatch;
  final String timestamp;

  LogEntry({
    required this.id,
    required this.recognizedText,
    this.matchedPhraseId,
    this.matchedSantali,
    required this.score,
    required this.isMatch,
    required this.timestamp,
  });

  factory LogEntry.fromMap(Map<String, dynamic> map) {
    return LogEntry(
      id: map['id'] as int,
      recognizedText: map['recognized_text'] as String,
      matchedPhraseId: map['matched_phrase_id'] as int?,
      matchedSantali: map['matched_santali'] as String?,
      score: (map['score'] as num).toDouble(),
      isMatch: map['is_match'] == 1,
      timestamp: map['timestamp'] as String,
    );
  }
}