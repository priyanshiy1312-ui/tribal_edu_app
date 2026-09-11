import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

enum RecordingState { idle, recording, processing }

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  RecordingState _state = RecordingState.idle;
  String? _lastFilePath;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _handleMicTap() async {
    if (_state == RecordingState.idle) {
      await _startRecording();
    } else if (_state == RecordingState.recording) {
      await _stopRecording();
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
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: filePath,
    );

    setState(() {
      _state = RecordingState.recording;
    });
  }

  Future<void> _stopRecording() async {
    setState(() {
      _state = RecordingState.processing;
    });

    final path = await _recorder.stop();
    _lastFilePath = path;

    debugPrint('✅ Recording saved to: $path');

    setState(() {
      _state = RecordingState.idle;
    });
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
            if (_lastFilePath != null) ...[
              const SizedBox(height: 24),
              Text(
                'Last saved: ${_lastFilePath!.split('/').last}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}