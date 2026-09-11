import 'package:string_similarity/string_similarity.dart';

import '../models/phrase.dart';
import 'database_service.dart';

/// Matches Whisper's (usually Romanized) transcription against the
/// fixed list of classroom phrases, using each phrase's manually
/// written `hindiRomanized` field for comparison.
///
/// This is NOT open-ended translation — it only ever matches against
/// the fixed list of phrases already sitting in the `phrases` table.
///
/// IMPORTANT FIX: raw fuzzy-string scores are unreliable for very
/// short phrases (e.g. "do" = "two") — a 2-letter candidate can score
/// deceptively high against almost any input just by chance overlap,
/// causing short phrases to "win" matches they have no real business
/// winning. We correct for this with a length-ratio penalty: the more
/// the matched phrase's length differs from the spoken input's length,
/// the more its score gets shrunk.
class PhraseMatcherService {
  PhraseMatcherService._internal();
  static final PhraseMatcherService instance = PhraseMatcherService._internal();

  /// Minimum similarity score (0.0–1.0) required to count as a match.
  static const double defaultThreshold = 0.45;

  Future<Phrase?> findBestMatch(
    String hindiInput, {
    double threshold = defaultThreshold,
  }) async {
    final result = await evaluateMatch(hindiInput, threshold: threshold);
    return (result != null && result.isMatch) ? result.phrase : null;
  }

  Future<MatchResult?> findBestMatchWithScore(
    String hindiInput, {
    double threshold = defaultThreshold,
  }) async {
    final result = await evaluateMatch(hindiInput, threshold: threshold);
    if (result == null || !result.isMatch) return null;
    return result;
  }

  /// Core matching logic. Always returns the best-scoring phrase and
  /// its (length-adjusted) score, even if it's below the match
  /// threshold — check `.isMatch` to see whether it actually cleared
  /// the bar. Returns null only if there's genuinely nothing to
  /// compare against (empty input or empty phrase table).
  Future<MatchResult?> evaluateMatch(
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
      if (candidate.isEmpty) continue;

      final rawScore = StringSimilarity.compareTwoStrings(cleanedInput, candidate);
      final adjustedScore = rawScore * _lengthRatio(cleanedInput, candidate);

      if (adjustedScore > bestScore) {
        bestScore = adjustedScore;
        bestPhrase = phrase;
      }
    }

    if (bestPhrase == null) return null;

    return MatchResult(
      phrase: bestPhrase,
      score: bestScore,
      isMatch: bestScore >= threshold,
    );
  }

  /// Penalizes matches between very differently-sized strings.
  /// Same length -> 1.0 (no penalty). A 2-letter word compared
  /// against a 15-letter sentence -> a small fraction, dragging its
  /// score down hard even if raw fuzzy similarity looked high.
  double _lengthRatio(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    final shorter = a.length < b.length ? a.length : b.length;
    final longer = a.length > b.length ? a.length : b.length;
    return shorter / longer;
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
  final bool isMatch;

  MatchResult({required this.phrase, required this.score, this.isMatch = true});

  @override
  String toString() =>
      'MatchResult(phrase: "${phrase.hindiPhrase}", score: ${score.toStringAsFixed(2)}, isMatch: $isMatch)';
}