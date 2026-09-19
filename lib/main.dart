import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'services/database_service.dart';
import 'services/speech_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SpeechService.instance.loadModel();
  } catch (e) {
    debugPrint('Failed to load Whisper model: $e');
  }

  try {
    final count = await DatabaseService.instance.loadPhrasesFromCsv();
    debugPrint('Loaded $count phrases into database');
  } catch (e) {
    debugPrint('Failed to load phrases: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BhashaMitra',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const HomeShell(),
    );
  }
}