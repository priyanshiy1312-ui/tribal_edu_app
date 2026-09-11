import 'package:flutter/material.dart';
import 'screens/translate_screen.dart';
import 'screens/worksheet_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/database_service.dart';
import 'services/speech_service.dart';
import 'services/phrase_matcher_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final count = await DatabaseService.instance.loadPhrasesFromCsv();
    debugPrint('✅ Loaded $count phrases into database');
  } catch (e) {
    debugPrint('❌ Failed to load phrases: $e');
  }
 
  runApp(const MyApp());
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tribal Edu App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    TranslateScreen(),
    WorksheetScreen(),
    DashboardScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.translate),
            label: 'Translate',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description),
            label: 'Worksheet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
        ],
      ),
    );
  }
}
