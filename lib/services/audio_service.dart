import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import '../models/phrase.dart';

/// Plays the cached Santali audio for a matched phrase.
///
/// Audio files are expected to live in the app's local documents
/// folder, at:
///   <documents>/santali_audio/<phrase.id>.mp3
///
/// This is a STUB until Day 2's real audio files exist. Right now it
/// checks whether the file is there; if not, it logs what *would* have
/// played instead of crashing. Once real files are dropped into that
/// folder (no rebuild needed), playback starts working automatically —
/// no code changes required here.
class AudioService {
  AudioService._internal();
  static final AudioService instance = AudioService._internal();

  final AudioPlayer _player = AudioPlayer();

  Future<void> playSantaliAudio(Phrase phrase) async {
    final path = await _audioPathFor(phrase.id);
    final file = File(path);

    if (!await file.exists()) {
      // ignore: avoid_print
      print(
        '🔇 [STUB] Would play Santali audio for phrase ${phrase.id} '
        '("${phrase.santaliPhrase}") — file not found at: $path',
      );
      return;
    }

    try {
      await _player.play(DeviceFileSource(path));
      // ignore: avoid_print
      print('🔊 Playing Santali audio for phrase ${phrase.id}: $path');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Failed to play audio for phrase ${phrase.id}: $e');
    }
  }

  Future<String> _audioPathFor(int phraseId) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/santali_audio/$phraseId.mp3';
  }

  void dispose() {
    _player.dispose();
  }
}