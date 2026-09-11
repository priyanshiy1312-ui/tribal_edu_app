import 'package:string_similarity/string_similarity.dart';

import '../models/phrase.dart';
import 'database_service.dart';

/// Person D — Phrase matching logic.
///
/// Takes whatever Hindi text the Whisper transcription produces and
/// figures out which of the pre-set classroom phrases (loaded by
/// Person A/B into the local database) it is closest to.
///
/// This is NOT open-ended translation — it only ever matches against
/// the fixed list of phrases already sitting in the `phrases` table.
///
/// IMPORTANT: Whisper's tiny/quantized model frequently returns Hindi
/// speech transcribed in ROMANIZED form (e.g. "khade hojao") instead of
/// Devanagari script ("खड़े हो जाओ"), especially under imperfect audio.
/// Since our phrase database stores Devanagari, we compare the input
/// against BOTH the original Devanagari phrase AND a Romanized version
/// of it, and take whichever score is higher.
class PhraseMatcherService {
  PhraseMatcherService._internal();
  static final PhraseMatcherService instance = PhraseMatcherService._internal();

  /// Minimum similarity score (0.0–1.0) required to count as a match.
  static const double defaultThreshold = 0.45;

  Future<Phrase?> findBestMatch(
    String hindiInput, {
    double threshold = defaultThreshold,
  }) async {
    final result = await findBestMatchWithScore(hindiInput, threshold: threshold);
    return result?.phrase;
  }

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
      // Compare against the original Devanagari text (works if Whisper
      // ever does return proper Devanagari).
      final devanagariCandidate = _normalize(phrase.hindiPhrase);
      final devanagariScore =
          StringSimilarity.compareTwoStrings(cleanedInput, devanagariCandidate);

      // Compare against a Romanized version (works for the common case
      // where Whisper returns "khade hojao"-style Romanized Hindi).
      final romanCandidate = _normalize(_devanagariToRoman(phrase.hindiPhrase));
      final romanScore =
          StringSimilarity.compareTwoStrings(cleanedInput, romanCandidate);

      final score = devanagariScore > romanScore ? devanagariScore : romanScore;

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

  // --- Devanagari -> Roman conversion ---
  //
  // This is a simple, rule-based approximation, not a linguistically
  // precise transliteration. It's designed to get Devanagari text into
  // roughly the same shape Whisper's Romanized output takes, so fuzzy
  // string matching can bridge the rest of the gap. Good enough for
  // matching a fixed set of ~56 known classroom phrases.

  static const Map<String, String> _consonants = {
    'क': 'k', 'ख': 'kh', 'ग': 'g', 'घ': 'gh', 'ङ': 'ng',
    'च': 'ch', 'छ': 'chh', 'ज': 'j', 'झ': 'jh', 'ञ': 'ny',
    'ट': 't', 'ठ': 'th', 'ड': 'd', 'ढ': 'dh', 'ण': 'n',
    'त': 't', 'थ': 'th', 'द': 'd', 'ध': 'dh', 'न': 'n',
    'प': 'p', 'फ': 'ph', 'ब': 'b', 'भ': 'bh', 'म': 'm',
    'य': 'y', 'र': 'r', 'ल': 'l', 'व': 'v', 'ळ': 'l',
    'श': 'sh', 'ष': 'sh', 'स': 's', 'ह': 'h',
    'ड़': 'r', 'ढ़': 'rh', 'फ़': 'f', 'ज़': 'z', 'क़': 'q', 'ग़': 'gh',
  };

  static const Map<String, String> _independentVowels = {
    'अ': 'a', 'आ': 'aa', 'इ': 'i', 'ई': 'ee', 'उ': 'u', 'ऊ': 'oo',
    'ऋ': 'ri', 'ए': 'e', 'ऐ': 'ai', 'ओ': 'o', 'औ': 'au',
  };

  static const Map<String, String> _matras = {
    'ा': 'aa', 'ि': 'i', 'ी': 'ee', 'ु': 'u', 'ू': 'oo',
    'ृ': 'ri', 'े': 'e', 'ै': 'ai', 'ो': 'o', 'ौ': 'au',
    'ं': 'n', 'ः': 'h', 'ँ': '',
  };

  static const String _virama = '्';

  String _devanagariToRoman(String input) {
    final buffer = StringBuffer();
    final chars = input.split('');

    for (int i = 0; i < chars.length; i++) {
      final ch = chars[i];

      if (_independentVowels.containsKey(ch)) {
        buffer.write(_independentVowels[ch]);
        continue;
      }

      if (_consonants.containsKey(ch)) {
        buffer.write(_consonants[ch]);

        final next = (i + 1 < chars.length) ? chars[i + 1] : null;

        if (next != null && _matras.containsKey(next)) {
          buffer.write(_matras[next]);
          i++; // consume the matra
        } else if (next == _virama) {
          i++; // consume the virama, no vowel added
        } else {
          buffer.write('a'); // default inherent vowel
        }
        continue;
      }

      // Spaces, digits, punctuation, or anything unrecognized —
      // pass through as-is.
      buffer.write(ch);
    }

    return buffer.toString();
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