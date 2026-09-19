import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../services/speech_service.dart';
import '../theme/app_theme.dart';
import 'home_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusText = 'Starting…';

  // Same fix used in HomeShell to nudge the logo's near-white jpeg
  // background to pure white.
  static const ColorFilter _logoWhiteFix = ColorFilter.matrix(<double>[
    1.06, 0, 0, 0, 0,
    0, 1.06, 0, 0, 0,
    0, 0, 1.06, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  void initState() {
    super.initState();
    _loadEverything();
  }

  Future<void> _loadEverything() async {
    setState(() => _statusText = 'Loading speech model…');
    try {
      await SpeechService.instance.loadModel();
    } catch (e) {
      debugPrint('Failed to load Whisper model: $e');
    }

    if (!mounted) return;
    setState(() => _statusText = 'Loading phrases…');
    try {
      final count = await DatabaseService.instance.loadPhrasesFromCsv();
      debugPrint('Loaded $count phrases into database');
    } catch (e) {
      debugPrint('Failed to load phrases: $e');
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFFFF3E6)],
        ),
        image: DecorationImage(
          image: AssetImage('assets/images/background.jpeg'),
          fit: BoxFit.cover,
          opacity: 0.28,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ColorFiltered(
                colorFilter: _logoWhiteFix,
                child: Image.asset(
                  'assets/images/logo.jpeg',
                  width: 180,
                ),
              ),
              const SizedBox(height: 8),
              Image.asset(
                'assets/images/sahyog.png',
                height: 110,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(color: AppColors.orange),
              const SizedBox(height: 16),
              Text(
                _statusText,
                style: TextStyle(
                  color: AppColors.navy.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
