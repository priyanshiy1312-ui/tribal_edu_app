import 'dart:math';

import 'package:flutter/material.dart';

import '../models/phrase.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

/// Worksheet screen — two tabs:
///  - Reference: every loaded phrase, styled like Translate's result cards.
///  - Practice: a match-the-pairs exercise built from the same real data
///    (no separate content needed — reuses the 56-phrase set).
class WorksheetScreen extends StatefulWidget {
  const WorksheetScreen({super.key});

  @override
  State<WorksheetScreen> createState() => _WorksheetScreenState();
}

class _WorksheetScreenState extends State<WorksheetScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<Phrase>> _phrasesFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _phrasesFuture = DatabaseService.instance.getAllPhrases();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'instruction':
        return AppColors.blue;
      case 'praise':
        return AppColors.greenDark;
      case 'encouragement':
        return AppColors.orange;
      case 'greeting':
        return AppColors.orangeDark;
      case 'number':
        return AppColors.navy;
      default:
        return Colors.grey;
    }
  }

  Widget _tabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.12)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.orange,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.navy.withValues(alpha: 0.6),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Reference'),
          Tab(text: 'Practice'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FutureBuilder<List<Phrase>>(
        future: _phrasesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.orange));
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No phrases loaded yet.'));
          }
          final phrases = snapshot.data!;
          return Column(
            children: [
              _tabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ReferenceTab(phrases: phrases, categoryColor: _categoryColor),
                    _PracticeTab(phrases: phrases),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// =====================================================================
// Reference tab
// =====================================================================

class _ReferenceTab extends StatelessWidget {
  final List<Phrase> phrases;
  final Color Function(String) categoryColor;

  const _ReferenceTab({required this.phrases, required this.categoryColor});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: phrases.length,
      itemBuilder: (context, index) {
        final p = phrases[index];
        final accent = categoryColor(p.category);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.25), width: 1.4),
            boxShadow: const [
              BoxShadow(color: Color(0x14173A63), blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  p.category.toUpperCase(),
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 11),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                p.hindiPhrase,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy),
              ),
              const SizedBox(height: 2),
              Text(
                '(${p.hindiRomanized})',
                style: TextStyle(fontSize: 12.5, color: AppColors.navy.withValues(alpha: 0.5), fontStyle: FontStyle.italic),
              ),
              const Divider(height: 20),
              Text(
                p.santaliPhrase,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.greenDark),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =====================================================================
// Practice tab — match the pairs
// =====================================================================

class _PracticeTab extends StatefulWidget {
  final List<Phrase> phrases;
  const _PracticeTab({required this.phrases});

  @override
  State<_PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends State<_PracticeTab> {
  static const int _roundSize = 6;

  late List<Phrase> _left;
  late List<Phrase> _right;
  final Set<int> _matched = {};
  int? _selectedLeftId;
  int? _wrongFlashId;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  void _newRound() {
    final pool = List<Phrase>.from(widget.phrases)..shuffle(Random());
    final round = pool.take(min(_roundSize, pool.length)).toList();
    _left = List<Phrase>.from(round)..shuffle(Random());
    _right = List<Phrase>.from(round)..shuffle(Random());
    _matched.clear();
    _selectedLeftId = null;
    _wrongFlashId = null;
    _attempts = 0;
    if (mounted) setState(() {});
  }

  void _tapLeft(Phrase p) {
    if (_matched.contains(p.id)) return;
    setState(() => _selectedLeftId = p.id);
  }

  void _tapRight(Phrase p) {
    if (_matched.contains(p.id) || _selectedLeftId == null) return;
    _attempts++;

    if (_selectedLeftId == p.id) {
      setState(() {
        _matched.add(p.id);
        _selectedLeftId = null;
      });
    } else {
      setState(() => _wrongFlashId = p.id);
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() {
          _wrongFlashId = null;
          _selectedLeftId = null;
        });
      });
    }
  }

  Widget _chip({
    required String text,
    required bool isMatched,
    required bool isSelected,
    required bool isWrong,
    required VoidCallback onTap,
  }) {
    Color bg = Colors.white;
    Color border = AppColors.navy.withValues(alpha: 0.15);
    Color textColor = AppColors.navy;

    if (isMatched) {
      bg = AppColors.greenDark.withValues(alpha: 0.12);
      border = AppColors.greenDark;
      textColor = AppColors.greenDark;
    } else if (isWrong) {
      bg = AppColors.orangeDark.withValues(alpha: 0.12);
      border = AppColors.orangeDark;
      textColor = AppColors.orangeDark;
    } else if (isSelected) {
      bg = AppColors.orange.withValues(alpha: 0.14);
      border = AppColors.orange;
    }

    return GestureDetector(
      onTap: isMatched ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 1.6),
        ),
        child: Row(
          children: [
            if (isMatched)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.check_circle_rounded, size: 18, color: AppColors.greenDark),
              ),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allMatched = _matched.length == _left.length && _left.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.touch_app_rounded, color: AppColors.blue, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tap a Hindi phrase, then its Santali match.',
                    style: TextStyle(color: AppColors.navy.withValues(alpha: 0.75), fontSize: 13.5),
                  ),
                ),
                Text(
                  '${_matched.length}/${_left.length}',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy),
                ),
              ],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: _left.map((p) {
                    return _chip(
                      text: p.hindiPhrase,
                      isMatched: _matched.contains(p.id),
                      isSelected: _selectedLeftId == p.id,
                      isWrong: false,
                      onTap: () => _tapLeft(p),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: _right.map((p) {
                    return _chip(
                      text: p.santaliPhrase,
                      isMatched: _matched.contains(p.id),
                      isSelected: false,
                      isWrong: _wrongFlashId == p.id,
                      onTap: () => _tapRight(p),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (allMatched)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.greenDark.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.greenDark.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.celebration_rounded, color: AppColors.greenDark),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'All matched! Great work.',
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.greenDark),
                    ),
                  ),
                  TextButton(
                    onPressed: _newRound,
                    child: const Text('New round', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _newRound,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('New round'),
                style: TextButton.styleFrom(foregroundColor: AppColors.navy.withValues(alpha: 0.6)),
              ),
            ),
        ],
      ),
    );
  }
}
