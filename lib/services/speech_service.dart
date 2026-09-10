import 'package:flutter_whisper_ggml/flutter_whisper_ggml.dart';

class SpeechService {
  SpeechService._internal();
  static final SpeechService instance = SpeechService._internal();

  WhisperController? _controller;
  bool _isModelLoaded = false;

  bool get isModelLoaded => _isModelLoaded;

  Future<void> loadModel() async {
    if (_isModelLoaded) return;

    _controller = WhisperController();

    // Downloads (first run only) and loads the 'base' model —
    // the same one we validated on the laptop with real Hindi speech.
    await _controller!.downloadModel(WhisperModel.base);

    _isModelLoaded = true;
    print('✅ Whisper base model loaded and ready');
  }

  Future<String> transcribeFile(String audioFilePath) async {
    if (!_isModelLoaded || _controller == null) {
      throw Exception('Whisper model is not loaded yet. Call loadModel() first.');
    }

    final result = await _controller!.transcribe(
      model: WhisperModel.base,
      audioPath: audioFilePath,
      lang: 'hi', // Hindi
    );

    return result?.transcription.text.trim() ?? '';
  }
}