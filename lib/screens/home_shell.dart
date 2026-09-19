import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'translate_screen.dart';
import 'worksheet_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int _dashboardKey = 0;

  static const List<Color> _brandColors = [
    AppColors.orange,
    AppColors.green,
    AppColors.blue,
  ];

  // Nudges the logo's near-white jpeg background to pure white.
  static const ColorFilter _logoWhiteFix = ColorFilter.matrix(<double>[
    1.06, 0, 0, 0, 0,
    0, 1.06, 0, 0, 0,
    0, 0, 1.06, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  void _onTap(int i) {
    setState(() {
      _index = i;
      if (i == 2) _dashboardKey++;
    });
  }

  Widget _buildLogo() {
    return ClipRect(
      child: Align(
        alignment: Alignment.center,
        widthFactor: 1.0,
        heightFactor: 0.72,
        child: ColorFiltered(
          colorFilter: _logoWhiteFix,
          child: Image.asset(
            'assets/images/logo.jpeg',
            height: 132,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  // "Sahyog" is a pre-rendered picture (transparent margins on every side),
  // so no font or gradient effect can ever clip the y and g.
  // Make it bigger or smaller by changing the height below.
  Widget _buildSahyog() {
    return Image.asset(
      'assets/images/sahyog.png',
      height: 124,
      fit: BoxFit.contain,
    );
  }

  Widget _buildHeader() {
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: const Color(0x40173A63),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 120,
              width: double.infinity,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: _buildLogo(),
                    ),
                  ),
                  Center(child: _buildSahyog()),
                ],
              ),
            ),
            Container(
              height: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: _brandColors),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNav() {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        height: 74,
        indicatorColor: AppColors.orange.withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? AppColors.orangeDark
                : AppColors.navy.withValues(alpha: 0.6),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 26,
            color: selected
                ? AppColors.orangeDark
                : AppColors.navy.withValues(alpha: 0.6),
          );
        }),
      ),
      child: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onTap,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mic_none_rounded),
            selectedIcon: Icon(Icons.mic_rounded),
            label: 'Translate',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'Worksheet',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Dashboard',
          ),
        ],
      ),
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
          opacity: 0.28, // tune 0.2 (fainter) to 0.4 (stronger)
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [
                  const TranslateScreen(),
                  const WorksheetScreen(),
                  DashboardScreen(key: ValueKey(_dashboardKey)),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildNav(),
      ),
    );
  }
}