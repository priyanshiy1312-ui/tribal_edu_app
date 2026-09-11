import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

import '../services/speech_service.dart';
import '../services/phrase_matcher_service.dart';

enum RecordingState { idle, recording, processing }

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  RecordingState _state = RecordingState.idle;

  String? _recognizedText;
  String? _matchedSantali;
  String? _errorMessage;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _handleMicTap() async {
    if (_state == RecordingState.idle) {
      await _startRecording();
    } else if (_state == RecordingState.recording) {
      await _stopRecordingAndProcess();
    }
  }

  Future<void> _startRecording() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required.')),
        );
      }
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;

    final dir = await getApplicationDocumentsDirectory();
    final filePath =
        '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';

        await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: filePath,
    );
    setState(() {
      _state = RecordingState.recording;
      _recognizedText = null;
      _matchedSantali = null;
      _errorMessage = null;
    });
  }

  Future<void> _stopRecordingAndProcess() async {
    setState(() {
      _state = RecordingState.processing;
    });

    final path = await _recorder.stop();

    if (path == null) {
      setState(() {
        _state = RecordingState.idle;
        _errorMessage = 'Recording failed — no file was saved.';
      });
      return;
    }

    debugPrint('✅ Recording saved to: $path');

    try {
      // Step 1: speech -> Hindi text
      final text = await SpeechService.instance.transcribeFile(path);
      debugPrint('🗣️ Recognized text: "$text"');

      // Step 2: Hindi text -> matched phrase
      final match = await PhraseMatcherService.instance.findBestMatch(text);

      setState(() {
        _recognizedText = text;
        _matchedSantali = match?.santaliPhrase;
        _errorMessage = match == null ? 'No matching phrase found.' : null;
        _state = RecordingState.idle;
      });

      if (match != null) {
        // Day 2 audio doesn't exist yet — print instead of playing sound.
        debugPrint('✅ Matched phrase -> Santali: "${match.santaliPhrase}"');
      } else {
        debugPrint('❌ No confident match found for: "$text"');
      }
    } catch (e) {
      debugPrint('❌ Pipeline error: $e');
      setState(() {
        _state = RecordingState.idle;
        _errorMessage = 'Something went wrong: $e';
      });
    }
  }

  IconData get _micIcon {
    switch (_state) {
      case RecordingState.idle:
        return Icons.mic;
      case RecordingState.recording:
        return Icons.stop;
      case RecordingState.processing:
        return Icons.hourglass_top;
    }
  }

  String get _statusText {
    switch (_state) {
      case RecordingState.idle:
        return 'Tap to speak';
      case RecordingState.recording:
        return 'Listening... tap to stop';
      case RecordingState.processing:
        return 'Processing...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Translate')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 80,
                icon: Icon(_micIcon),
                color: _state == RecordingState.recording ? Colors.red : null,
                onPressed:
                    _state == RecordingState.processing ? null : _handleMicTap,
              ),
              const SizedBox(height: 16),
              Text(_statusText),
              if (_recognizedText != null) ...[
                const SizedBox(height: 24),
                Text(
                  'Heard (Hindi): $_recognizedText',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
              if (_matchedSantali != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Matched (Santali): $_matchedSantali',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.orange),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}