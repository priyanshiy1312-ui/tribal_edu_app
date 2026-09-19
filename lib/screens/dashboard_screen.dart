import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../theme/app_theme.dart';

/// Dashboard screen — restyled to match Translate's branded card
/// language (rounded corners, colored accent borders, icon circles),
/// plus a phrase/audio coverage summary alongside match-attempt stats.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashboardData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<void> _refresh() async {
    setState(() {
      _dataFuture = _loadData();
    });
  }

  Future<_DashboardData> _loadData() async {
    final logs = await DatabaseService.instance.getMatchLogs();
    final phrases = await DatabaseService.instance.getAllPhrases();
    return _DashboardData(logs: logs, phraseCount: phrases.length);
  }

  Widget _card({
    required Color accent,
    required IconData icon,
    required String label,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.25), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14173A63),
            blurRadius: 16,
            offset: Offset(0, 5),
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppColors.navy.withValues(alpha: 0.6),
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _summaryRow(_DashboardData data) {
    final total = data.logs.length;
    final matched = data.logs.where((l) => l['is_match'] == 1).length;
    final rate = total == 0 ? 0.0 : (matched / total * 100);

    return Row(
      children: [
        Expanded(
          child: _card(
            accent: AppColors.orange,
            icon: Icons.record_voice_over_rounded,
            label: 'ATTEMPTS',
            child: Text(
              '$total',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _card(
            accent: AppColors.greenDark,
            icon: Icons.check_circle_rounded,
            label: 'SUCCESS RATE',
            child: Text(
              total == 0 ? '—' : '${rate.toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _card(
            accent: AppColors.blue,
            icon: Icons.library_books_rounded,
            label: 'PHRASES LOADED',
            child: Text(
              '${data.phraseCount}/56',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _logCard(Map<String, dynamic> log) {
    final isMatch = log['is_match'] == 1;
    final score = (log['score'] as num).toDouble();
    final recognizedText = log['recognized_text'] as String;
    final matchedSantali = log['matched_santali'] as String?;
    final timestamp = log['timestamp'] as String;
    final accent = isMatch ? AppColors.greenDark : AppColors.orangeDark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.2), width: 1.3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isMatch ? Icons.check_rounded : Icons.help_outline_rounded,
              size: 17,
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Heard: "$recognizedText"',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isMatch
                      ? 'Matched: $matchedSantali · score ${score.toStringAsFixed(2)}'
                      : 'No confident match · best score ${score.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.navy.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatTime(timestamp),
            style: TextStyle(
              fontSize: 11,
              color: AppColors.navy.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FutureBuilder<_DashboardData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.orange));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading logs: ${snapshot.error}'));
          }

          final data = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.orange,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _summaryRow(data),
                const SizedBox(height: 18),
                if (data.logs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(
                      child: Text(
                        'No attempts logged yet.\nTry the Translate screen, then pull down to refresh.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.navy.withValues(alpha: 0.5)),
                      ),
                    ),
                  )
                else ...[
                  Text(
                    'RECENT ACTIVITY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: AppColors.navy.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...data.logs.map(_logCard),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }
}

class _DashboardData {
  final List<Map<String, dynamic>> logs;
  final int phraseCount;
  _DashboardData({required this.logs, required this.phraseCount});
}
