import 'package:flutter/foundation.dart';
import 'package:flutter_whisper_ggml/flutter_whisper.dart';

class SpeechService {
  SpeechService._internal();
  static final SpeechService instance = SpeechService._internal();

  FlutterWhisper? _whisper;
  bool _isModelLoaded = false;
  bool get isModelLoaded => _isModelLoaded;

  Future<void> loadModel() async {
    if (_isModelLoaded) return;

    _whisper = await FlutterWhisper.loadModel(
      model: WhisperModels.base,
      onDownloadProgress: (progress) {
        debugPrint('Whisper model download progress: $progress');
      },
      onModelProgress: (progress) {
        debugPrint('Whisper model loading: $progress%');
      },
    );

    _isModelLoaded = true;
    debugPrint('✅ Whisper base model loaded and ready');
  }

  Future<String> transcribeFile(String audioFilePath) async {
    if (!_isModelLoaded || _whisper == null) {
      throw Exception('Whisper model is not loaded yet. Call loadModel() first.');
    }

    final result = await _whisper!.transcribeFile(
      audioFilePath,
      config: const WhisperTranscribeConfig(language: 'hi'),
    );

    return result.text.trim();
  }
}