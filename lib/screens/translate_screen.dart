import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../models/phrase.dart';
import '../services/audio_service.dart';
import '../services/database_service.dart';
import '../services/phrase_matcher_service.dart';
import '../services/speech_service.dart';
import '../theme/app_theme.dart';

enum RecordingState { idle, recording, processing }

enum ProcessingStage { transcribing, matching }

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _chime = AudioPlayer();

  RecordingState _state = RecordingState.idle;
  ProcessingStage _stage = ProcessingStage.transcribing;

  // True while the teacher has "listening" switched on. While true, the
  // mic re-arms by itself after every phrase. Tapping pause sets it false.
  bool _sessionActive = false;

  // True once at least one attempt has finished (matched or not).
  bool _attempted = false;
  Phrase? _matchedPhrase;
  String? _errorMessage;

  StreamSubscription<Amplitude>? _amplitudeSub;
  Timer? _maxDurationTimer;
  Timer? _rearmTimer;

  bool _speechDetected = false;
  DateTime? _lastLoudTime;

  // Voice level (0..1) that drives the pulsing rings while listening.
  final ValueNotifier<double> _level = ValueNotifier<double>(0.0);
  late final AnimationController _pulse;

  // ---- Tuning knobs -------------------------------------------------
  // Speech / silence detection.
  static const double _speakingThresholdDb = -35.0;
  static const Duration _silenceToStop = Duration(milliseconds: 1200);
  static const Duration _maxRecordingDuration = Duration(seconds: 8);

  // Pause before listening again after a phrase.
  static const Duration _rearmDelay = Duration(milliseconds: 1500);

  // Extra wait after a MATCH so the mic doesn't hear the Santali audio
  // playing from the speaker. Raise it if the app hears itself.
  static const Duration _matchedExtraWait = Duration(seconds: 2);

  // Time given to the chime before recording starts (chime is ~0.6s).
  static const Duration _chimeLeadIn = Duration(milliseconds: 750);

  // Keep the .wav files for debugging? Off = they are deleted after use.
  static const bool _keepRecordingsForDebug = false;
  // -------------------------------------------------------------------

  static const Color _blueDark = Color(0xFF1B8FC4);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _sessionActive = false;
    _amplitudeSub?.cancel();
    _maxDurationTimer?.cancel();
    _rearmTimer?.cancel();
    _pulse.dispose();
    _level.dispose();
    _chime.dispose();
    _recorder.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------
  // Whisper sometimes loops on the same words ("Bad to go. Bad to go.").
  // Collapse that to a single copy before matching.
  // ---------------------------------------------------------------
  String _collapseRepeats(String input) {
    final sentences = input
        .split(RegExp(r'[.!?।]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final seen = <String>{};
    final unique = <String>[];
    for (final s in sentences) {
      if (seen.add(s.toLowerCase())) unique.add(s);
    }
    var text = unique.join('. ');

    final words =
        text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    for (int n = 1; n <= words.length ~/ 2; n++) {
      if (words.length % n != 0) continue;
      bool repeated = true;
      for (int i = n; i < words.length; i++) {
        if (words[i].toLowerCase() != words[i % n].toLowerCase()) {
          repeated = false;
          break;
        }
      }
      if (repeated) {
        text = words.sublist(0, n).join(' ');
        break;
      }
    }
    return text;
  }

  // ---------------------------------------------------------------
  // Session control: start / pause
  // ---------------------------------------------------------------

  Future<void> _handleMicTap() async {
    if (_sessionActive) {
      await _pauseSession();
    } else if (_state == RecordingState.idle) {
      await _startSession();
    }
    // Paused while still processing the last phrase: ignore taps until done.
  }

  Future<void> _startSession() async {
    _sessionActive = true;
    if (mounted) setState(() {});
    await _startRecording();
  }

  Future<void> _pauseSession() async {
    _sessionActive = false;
    _rearmTimer?.cancel();
    _rearmTimer = null;

    if (_state == RecordingState.recording) {
      await _discardRecording();
      if (!mounted) return;
      setState(() => _state = RecordingState.idle);
    } else if (mounted) {
      // If a phrase is being processed, it finishes normally (and plays),
      // but the mic will not start listening again afterwards.
      setState(() {});
    }
  }

  // Waits, plays the soft chime, then starts listening again.
  void _scheduleRearm(Duration delay) {
    _rearmTimer?.cancel();
    if (!_sessionActive) return;

    _rearmTimer = Timer(delay, () async {
      if (!mounted || !_sessionActive || _state != RecordingState.idle) return;

      await _playChime();

      if (!mounted || !_sessionActive || _state != RecordingState.idle) return;
      await _startRecording();
    });
  }

  Future<void> _playChime() async {
    try {
      await _chime.stop();
      await _chime.play(AssetSource('sounds/chime.wav'), volume: 0.6);
    } catch (e) {
      debugPrint('❌ Chime failed: $e');
    }
    // Let the chime finish so the mic doesn't record it.
    await Future<void>.delayed(_chimeLeadIn);
  }

  // ---------------------------------------------------------------
  // Recording
  // ---------------------------------------------------------------

  Future<bool> _startRecording() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required.')),
        );
      }
      _sessionActive = false;
      if (mounted) setState(() {});
      return false;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _sessionActive = false;
      if (mounted) setState(() {});
      return false;
    }

    // The teacher may have paused while we were waiting.
    if (!mounted || !_sessionActive) return false;

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

    if (!mounted || !_sessionActive) {
      await _discardRecording();
      return false;
    }

    _speechDetected = false;
    _lastLoudTime = null;

    // Listen for amplitude changes to detect when the teacher stops talking.
    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 200))
        .listen(_handleAmplitude);

    // Safety net. If someone spoke, process what we have. If nobody spoke,
    // do NOT send silence to Whisper (it invents text); just start a fresh
    // listening window.
    _maxDurationTimer = Timer(_maxRecordingDuration, () async {
      if (_state != RecordingState.recording) return;

      if (_speechDetected) {
        await _stopRecordingAndProcess();
        return;
      }

      await _discardRecording();
      if (!mounted || !_sessionActive) return;
      setState(() => _state = RecordingState.idle);
      await _startRecording();
    });

    setState(() {
      _state = RecordingState.recording;
      _errorMessage = null;
    });
    return true;
  }

  // Stops the recorder and throws the audio away (used for pause and for
  // silent windows).
  Future<void> _discardRecording() async {
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    _level.value = 0.0;

    try {
      final path = await _recorder.stop();
      if (path != null) {
        final f = File(path);
        if (await f.exists()) await f.delete();
      }
    } catch (e) {
      debugPrint('❌ Discard error: $e');
    }
  }

  void _handleAmplitude(Amplitude amp) {
    if (_state != RecordingState.recording) return;

    // Map roughly -60 dB..0 dB to 0..1 for the visual rings.
    _level.value = ((amp.current + 60) / 60).clamp(0.0, 1.0).toDouble();

    final now = DateTime.now();

    if (amp.current > _speakingThresholdDb) {
      _speechDetected = true;
      _lastLoudTime = now;
      return;
    }

    // Quiet right now: only act if we've already heard speech once.
    if (_speechDetected && _lastLoudTime != null) {
      final silenceElapsed = now.difference(_lastLoudTime!);
      if (silenceElapsed >= _silenceToStop) {
        _stopRecordingAndProcess();
      }
    }
  }

  Future<void> _stopRecordingAndProcess() async {
    if (_state != RecordingState.recording) return;
    if (!mounted) return;

    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    _level.value = 0.0;

    setState(() {
      _state = RecordingState.processing;
      _stage = ProcessingStage.transcribing;
    });

    final path = await _recorder.stop();

    if (path == null) {
      if (!mounted) return;
      setState(() {
        _state = RecordingState.idle;
        _errorMessage = 'Recording failed: no file was saved.';
      });
      _scheduleRearm(_rearmDelay);
      return;
    }

    debugPrint('✅ Recording saved to: $path');

    Duration nextDelay = _rearmDelay;

    try {
      final rawText = await SpeechService.instance.transcribeFile(path);
      final text = _collapseRepeats(rawText);
      debugPrint('🗣️ Recognized text (raw): "$rawText"');
      debugPrint('🧹 Recognized text (cleaned): "$text"');

      if (!mounted) return;
      setState(() => _stage = ProcessingStage.matching);

      final result = await PhraseMatcherService.instance.evaluateMatch(text);

      // The text still goes to the log for the Dashboard and debugging;
      // it is just never shown to the teacher on a miss.
      await DatabaseService.instance.logMatchAttempt(
        recognizedText: text,
        matchedPhraseId: result?.phrase.id,
        matchedSantali: result?.phrase.santaliPhrase,
        score: result?.score ?? 0.0,
        isMatch: result?.isMatch ?? false,
      );

      final matched = (result != null && result.isMatch) ? result.phrase : null;

      if (!mounted) return;
      setState(() {
        _attempted = true;
        _matchedPhrase = matched;
        _errorMessage = null;
        _state = RecordingState.idle;
      });

      if (matched != null) {
        debugPrint(
          '✅ Matched phrase -> Santali: "${matched.santaliPhrase}" '
          '(score: ${result!.score.toStringAsFixed(2)})',
        );
        await AudioService.instance.playSantaliAudio(matched);
        nextDelay = _rearmDelay + _matchedExtraWait;
      } else {
        debugPrint(
          '❌ No confident match for: "$text" '
          '(best score: ${result?.score.toStringAsFixed(2) ?? "n/a"})',
        );
      }
    } catch (e) {
      debugPrint('❌ Pipeline error: $e');
      if (!mounted) return;
      setState(() {
        _state = RecordingState.idle;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    } finally {
      if (!_keepRecordingsForDebug) {
        try {
          final f = File(path);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }

    // Listen again by itself (only if the teacher hasn't paused).
    if (mounted) _scheduleRearm(nextDelay);
  }

  Future<void> _replay() async {
    final phrase = _matchedPhrase;
    if (phrase == null) return;
    await AudioService.instance.playSantaliAudio(phrase);
  }

  // ---------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------

  String get _promptHindi {
    switch (_state) {
      case RecordingState.recording:
        return 'सुन रहा हूँ…';
      case RecordingState.processing:
        return 'समझ रहा हूँ…';
      case RecordingState.idle:
        if (_sessionActive) return 'फिर से सुनने की तैयारी…';
        return _attempted ? 'रुका हुआ है' : 'सुनना शुरू करने के लिए टैप करें';
    }
  }

  String get _promptEnglish {
    switch (_state) {
      case RecordingState.recording:
        return 'Listening… it stops on its own when you pause';
      case RecordingState.processing:
        final base = _stage == ProcessingStage.transcribing
            ? 'Understanding your Hindi…'
            : 'Finding the matching phrase…';
        return _sessionActive
            ? base
            : '$base (listening will pause after this)';
      case RecordingState.idle:
        if (_sessionActive) return 'Getting ready to listen again…';
        return _attempted
            ? 'Paused. Tap the mic to start listening again'
            : 'Tap the mic once, then just speak';
    }
  }

  Widget _buildPrompt() {
    return Column(
      children: [
        Text(
          _promptHindi,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _promptEnglish,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: AppColors.navy.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }

  Widget _buildRings() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulse, _level]),
      builder: (context, _) {
        final double t = _pulse.value;
        final double boost = _level.value * 40;

        Widget ring(double phase) {
          final double p = (t + phase) % 1.0;
          final double size = 160 + 100 * p + boost;
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.blue
                  .withValues(alpha: (0.30 * (1 - p)).clamp(0.0, 1.0)),
            ),
          );
        }

        return Stack(
          alignment: Alignment.center,
          children: [ring(0.0), ring(0.5)],
        );
      },
    );
  }

  Widget _buildMicHero() {
    final bool recording = _state == RecordingState.recording;
    final bool processing = _state == RecordingState.processing;

    final List<Color> gradient = recording
        ? [AppColors.blue, _blueDark]
        : [AppColors.orange, AppColors.orangeDark];
    final Color glow = recording ? AppColors.blue : AppColors.orange;

    // While listening the button shows "pause", since that's what a tap does.
    final IconData icon = recording
        ? Icons.pause_rounded
        : processing
            ? Icons.graphic_eq_rounded
            : Icons.mic_rounded;

    return SizedBox(
      width: 320,
      height: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (recording) _buildRings(),
          if (processing)
            SizedBox(
              width: 196,
              height: 196,
              child: CircularProgressIndicator(
                strokeWidth: 7,
                color: AppColors.orange,
                backgroundColor: AppColors.orange.withValues(alpha: 0.15),
              ),
            ),
          GestureDetector(
            onTap: _handleMicTap,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
                boxShadow: [
                  BoxShadow(
                    color: glow.withValues(alpha: 0.45),
                    blurRadius: 30,
                    spreadRadius: 2,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(icon, size: 76, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Clear, labelled pause control shown whenever listening is switched on.
  Widget _buildPauseControl() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _sessionActive
          ? Padding(
              key: const ValueKey('pause'),
              padding: const EdgeInsets.only(bottom: 18),
              child: OutlinedButton.icon(
                onPressed: _pauseSession,
                icon: const Icon(Icons.pause_circle_outline_rounded, size: 24),
                label: const Text(
                  'Pause listening',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.navy,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: AppColors.navy.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            )
          : const SizedBox(key: ValueKey('nopause'), height: 0),
    );
  }

  Widget _card({
    Key? key,
    required Color accent,
    required IconData icon,
    required String label,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.25), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14173A63),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 19, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppColors.navy.withValues(alpha: 0.6),
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _replayButton() {
    return GestureDetector(
      onTap: _replay,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.blue,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.volume_up_rounded, size: 20, color: Colors.white),
            SizedBox(width: 6),
            Text(
              'Replay',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultArea() {
    if (_state == RecordingState.processing) {
      return const SizedBox(key: ValueKey('processing'), height: 4);
    }

    // Error (e.g. recording failed / pipeline error).
    if (!_attempted && _errorMessage != null) {
      return _card(
        key: const ValueKey('error'),
        accent: AppColors.orangeDark,
        icon: Icons.error_outline_rounded,
        label: 'SOMETHING WENT WRONG',
        child: Text(
          _errorMessage!,
          style: const TextStyle(fontSize: 16, color: AppColors.navy),
        ),
      );
    }

    // First-use hint.
    if (!_attempted) {
      return Text(
        'Tap the mic once, then speak. It keeps listening between phrases; '
        'tap pause any time.',
        key: const ValueKey('hint'),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          color: AppColors.navy.withValues(alpha: 0.55),
        ),
      );
    }

    final Phrase? phrase = _matchedPhrase;

    // Nothing matched: friendly message only, never the wrong text.
    if (phrase == null) {
      return _card(
        key: const ValueKey('nomatch'),
        accent: AppColors.orangeDark,
        icon: Icons.hearing_disabled_rounded,
        label: "COULDN'T CATCH THAT",
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'मैं समझ नहीं पाया',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Please try again, speaking a little slower.',
              style: TextStyle(fontSize: 16, color: AppColors.navy),
            ),
          ],
        ),
      );
    }

    // Matched: show the phrase's clean Hindi, plus the Santali.
    final Widget hindiCard = _card(
      key: ValueKey('hindi-${phrase.id}'),
      accent: AppColors.navy,
      icon: Icons.hearing_rounded,
      label: 'HINDI',
      child: Text(
        phrase.hindiPhrase,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.navy,
        ),
      ),
    );

    final Widget santaliCard = _card(
      key: ValueKey('santali-${phrase.id}'),
      accent: AppColors.greenDark,
      icon: Icons.record_voice_over_rounded,
      label: 'SANTALI',
      trailing: _replayButton(),
      child: Text(
        phrase.santaliPhrase,
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: AppColors.greenDark,
        ),
      ),
    );

    return LayoutBuilder(
      key: ValueKey('match-${phrase.id}'),
      builder: (context, constraints) {
        if (constraints.maxWidth >= 700) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: hindiCard),
                const SizedBox(width: 16),
                Expanded(child: santaliCard),
              ],
            ),
          );
        }
        return Column(
          children: [hindiCard, const SizedBox(height: 14), santaliCard],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildPrompt(),
                        _buildMicHero(),
                        _buildPauseControl(),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _buildResultArea(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}