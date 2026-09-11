import 'package:string_similarity/string_similarity.dart';

// Minimal standalone version of the matching logic —
// same idea as PhraseMatcherService, but using a hardcoded
// list instead of the real database, so it can run instantly
// with plain `dart run` — no Flutter, no emulator, no database needed.

class TestPhrase {
  final String hindi;
  final String santali;
  TestPhrase(this.hindi, this.santali);
}

final testPhrases = [
  TestPhrase("खड़े हो जाओ", "santali_stand_up"),
  TestPhrase("बैठ जाओ", "santali_sit_down"),
  TestPhrase("बहुत बढ़िया", "santali_well_done"),
  TestPhrase("एक", "santali_one"),
  TestPhrase("दो", "santali_two"),
  TestPhrase("नमस्ते", "santali_hello"),
];

String normalize(String input) {
  return input
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[।.,!?]'), '')
      .toLowerCase();
}

TestPhrase? findBestMatch(String input, {double threshold = 0.45}) {
  final cleanedInput = normalize(input);
  TestPhrase? best;
  double bestScore = 0.0;

  for (final phrase in testPhrases) {
    final score = StringSimilarity.compareTwoStrings(
      cleanedInput,
      normalize(phrase.hindi),
    );
    if (score > bestScore) {
      bestScore = score;
      best = phrase;
    }
  }

  if (best == null || bestScore < threshold) return null;
  print('Matched "$input" -> "${best.hindi}" (score: ${bestScore.toStringAsFixed(2)})');
  return best;
}

void main() {
  print('--- Testing exact matches ---');
  findBestMatch("खड़े हो जाओ");
  findBestMatch("बैठ जाओ");
  findBestMatch("नमस्ते");

  print('\n--- Testing near-miss (slightly different wording) ---');
  findBestMatch("खड़े हो जाओ।"); // with punctuation
  findBestMatch("  बैठ जाओ  "); // extra spaces

  print('\n--- Testing something that should NOT match ---');
  final result = findBestMatch("आज मौसम कैसा है"); // unrelated sentence
  if (result == null) {
    print('Correctly returned no match.');
  }
}
