import 'package:audioplayers/audioplayers.dart';

import '../models/phrase.dart';

/// Plays the cached Santali audio for a matched phrase.
///
/// Audio files are bundled directly as Flutter assets at:
///   assets/audio/<phrase.id>.aac
///
/// Only a subset of the 56 phrases have real audio recorded so far
/// (Day 2 is still in progress). For any phrase without a file yet,
/// this fails gracefully and just logs it — no crash — so the app
/// keeps working end-to-end even with partial audio coverage.
class AudioService {
  AudioService._internal();
  static final AudioService instance = AudioService._internal();

  final AudioPlayer _player = AudioPlayer();

  Future<void> playSantaliAudio(Phrase phrase) async {
    final assetPath = 'audio/${phrase.id}.aac';

    try {
      await _player.play(AssetSource(assetPath));
      // ignore: avoid_print
      print('🔊 Playing Santali audio for phrase ${phrase.id}: $assetPath');
    } catch (e) {
      // ignore: avoid_print
      print(
        '🔇 No audio available yet for phrase ${phrase.id} '
        '("${phrase.santaliPhrase}") — Day 2 hasn\'t recorded this one. '
        'Error: $e',
      );
    }
  }

  void dispose() {
    _player.dispose();
  }
}