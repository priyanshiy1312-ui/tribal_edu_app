/// One piece of bilingual worksheet content — a simple, self-contained
/// unit a teacher can read or hand out. Hardcoded for Day 6; not tied
/// to the live phrase database.
class WorksheetItem {
  final String title;
  final String hindiText;
  final String hindiRomanized;
  final String santaliText;
  final String category;

  const WorksheetItem({
    required this.title,
    required this.hindiText,
    required this.hindiRomanized,
    required this.santaliText,
    required this.category,
  });
}