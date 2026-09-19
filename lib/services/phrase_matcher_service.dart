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
/// IMPORTANT FIX #1: raw fuzzy-string scores are unreliable for very
/// short phrases (e.g. "do" = "two") — a 2-letter candidate can score
/// deceptively high against almost any input just by chance overlap,
/// causing short phrases to "win" matches they have no real business
/// winning. We correct for this with a length-ratio penalty: the more
/// the matched phrase's length differs from the spoken input's length,
/// the more its score gets shrunk.
///
/// IMPORTANT FIX #2: character-bigram similarity alone penalizes
/// natural phrasing variation too harshly — e.g. "aap khade ho" vs
/// "khade ho jao" mean the same thing ("stand up") but score low on
/// raw character similarity because of word order/extra words. We add
/// a word-level token-overlap score (order-independent) and take the
/// best of the two scoring methods, so a teacher rephrasing a known
/// instruction still matches.
class PhraseMatcherService {
  PhraseMatcherService._internal();
  static final PhraseMatcherService instance = PhraseMatcherService._internal();

  /// Minimum similarity score (0.0–1.0) required to count as a match.
  static const double defaultThreshold = 0.45;

  /// Filler/politeness words stripped before comparison. Deliberately
  /// does NOT include content words that are also standalone phrases
  /// (e.g. "ek" = "one" is phrase #30 — stripping it would break that
  /// match), only words that add politeness/filler without changing
  /// the core instruction meaning.
  static const Set<String> _stopWords = {
    'aap', 'ji', 'kripya', 'please', 'zara', 'thoda', 'plz', 'hi', 'toh',
  };

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

      final charScore = StringSimilarity.compareTwoStrings(cleanedInput, candidate);
      final tokenScore = _tokenOverlapScore(cleanedInput, candidate);
      final rawScore = charScore > tokenScore ? charScore : tokenScore;

      final adjustedScore = rawScore * _lengthRatio(cleanedInput, candidate);

      if (adjustedScore > bestScore) {
        bestScore = adjustedScore;
        bestPhrase = phrase;
      }
    }

    if (bestPhrase == null) return null;

    // TEMP DEBUG — remove once matching accuracy is confirmed fixed.
    // ignore: avoid_print
    print(
      'MATCH DEBUG | heard: "$cleanedInput" | best: "${bestPhrase.hindiRomanized}" '
      '(id ${bestPhrase.id}) | score: ${bestScore.toStringAsFixed(3)} | '
      'threshold: $threshold | matched: ${bestScore >= threshold}',
    );

    return MatchResult(
      phrase: bestPhrase,
      score: bestScore,
      isMatch: bestScore >= threshold,
    );
  }

  /// Word-level, order-independent overlap: what fraction of the
  /// candidate phrase's words are present in the input. Catches
  /// rephrasing ("aap khade ho" vs "khade ho jao") that character
  /// bigram similarity scores too low. Still gets multiplied by the
  /// same length-ratio penalty afterward, so a single shared word
  /// can't win a match against a much longer/shorter phrase.
  double _tokenOverlapScore(String input, String candidate) {
    final inputWords = input.split(' ').where((w) => w.isNotEmpty).toSet();
    final candidateWords = candidate.split(' ').where((w) => w.isNotEmpty).toSet();
    if (candidateWords.isEmpty) return 0.0;

    final overlap = inputWords.intersection(candidateWords).length;
    return overlap / candidateWords.length;
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
  /// punctuation, casing, filler/politeness words) don't tank the
  /// score.
  String _normalize(String input) {
    final cleaned = input
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[।.,!?]'), '')
        .toLowerCase();

    final words = cleaned.split(' ').where((w) => !_stopWords.contains(w));
    return words.join(' ');
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