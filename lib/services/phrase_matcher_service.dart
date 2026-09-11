import 'package:string_similarity/string_similarity.dart';

import '../models/phrase.dart';
import 'database_service.dart';

/// Matches Whisper's (usually Romanized) transcription against the
/// fixed list of classroom phrases, using each phrase's manually
/// written `hindiRomanized` field for comparison.
///
/// This is NOT open-ended translation — it only ever matches against
/// the fixed list of phrases already sitting in the `phrases` table.
class PhraseMatcherService {
  PhraseMatcherService._internal();
  static final PhraseMatcherService instance = PhraseMatcherService._internal();

  /// Minimum similarity score (0.0–1.0) required to count as a match.
  static const double defaultThreshold = 0.45;

  /// Finds the best-matching [Phrase] for the given input.
  /// Returns `null` if nothing scores high enough (i.e. "no match").
  Future<Phrase?> findBestMatch(
    String hindiInput, {
    double threshold = defaultThreshold,
  }) async {
    final result = await findBestMatchWithScore(hindiInput, threshold: threshold);
    return result?.phrase;
  }

  /// Same as [findBestMatch] but also returns the similarity score,
  /// useful for debugging / tuning the threshold while testing.
  Future<MatchResult?> findBestMatchWithScore(
    String hindiInput, {
    double threshold = defaultThreshold,
  }) async {
    final cleanedInput = _normalize(hindiInput);
    if (cleanedInput.isEmpty) return null;

    final allPhrases = await DatabaseService.instance.getAllPhrases();
    if (allPhrases.isEmpty) return null;

    Phrase? bestPhrase;
    double bestScore = 0.0;

    for (final phrase in allPhrases) {
      final candidate = _normalize(phrase.hindiRomanized);
      final score = StringSimilarity.compareTwoStrings(cleanedInput, candidate);

      if (score > bestScore) {
        bestScore = score;
        bestPhrase = phrase;
      }
    }

    if (bestPhrase == null || bestScore < threshold) {
      return null;
    }

    return MatchResult(phrase: bestPhrase, score: bestScore);
  }

  /// Basic normalization so trivial differences (extra spaces, stray
  /// punctuation, casing) don't tank the score.
  String _normalize(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[।.,!?]'), '')
        .toLowerCase();
  }
}

/// Wraps a matched [Phrase] together with its similarity score.
class MatchResult {
  final Phrase phrase;
  final double score;

  MatchResult({required this.phrase, required this.score});

  @override
  String toString() =>
      'MatchResult(phrase: "${phrase.hindiPhrase}", score: ${score.toStringAsFixed(2)})';
}