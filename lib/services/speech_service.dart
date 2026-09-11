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
  model: WhisperModels.tinyQ5_1,
      config: const WhisperModelConfig(useGpu: false),
      onDownloadProgress: (progress) {
        print('Whisper model download: $progress');
      },
      onModelProgress: (progress) {
        print('Whisper model loading: $progress%');
      },
    );

    _isModelLoaded = true;
    print('✅ Whisper base model loaded and ready');
  }

  Future<String> transcribeFile(String audioFilePath) async {
    if (!_isModelLoaded || _whisper == null) {
      throw Exception('Whisper model is not loaded yet. Call loadModel() first.');
    }

    final result = await _whisper!.transcribeFile(
      audioFilePath,
      config: const WhisperTranscribeConfig(
        language: 'hi',
         threads: 4,
        ),
    );

    return result.text.trim();
  }
}