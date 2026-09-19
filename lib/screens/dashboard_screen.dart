import 'package:flutter/material.dart';

import '../services/database_service.dart';

/// Day 6 — Dashboard screen.
///
/// Pulls every logged match attempt (matched or not) from Day 5's
/// match_logs table and shows it as a plain list, most recent first —
/// per the plan, no charts needed. Includes a simple summary count at
/// the top and pull-to-refresh, since new attempts get logged every
/// time someone uses the Translate screen.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Map<String, dynamic>>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _logsFuture = DatabaseService.instance.getMatchLogs();
  }

  Future<void> _refresh() async {
    setState(() {
      _logsFuture = DatabaseService.instance.getMatchLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _logsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading logs: ${snapshot.error}'));
          }

          final logs = snapshot.data ?? [];

          if (logs.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: const [
                  SizedBox(height: 200),
                  Center(
                    child: Text(
                      'No attempts logged yet.\nTry the Translate screen, then pull down to refresh.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                ],
              ),
            );
          }

          final matchedCount = logs.where((l) => l['is_match'] == 1).length;
          final totalCount = logs.length;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length + 1, // +1 for the summary header
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      color: Colors.blue.withOpacity(0.08),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '$matchedCount / $totalCount attempts matched',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                final log = logs[index - 1];
                final isMatch = log['is_match'] == 1;
                final score = (log['score'] as num).toDouble();
                final recognizedText = log['recognized_text'] as String;
                final matchedSantali = log['matched_santali'] as String?;
                final timestamp = log['timestamp'] as String;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Icon(
                      isMatch ? Icons.check_circle : Icons.help_outline,
                      color: isMatch ? Colors.green : Colors.orange,
                    ),
                    title: Text('Heard: "$recognizedText"'),
                    subtitle: Text(
                      isMatch
                          ? 'Matched: $matchedSantali\nConfidence: ${score.toStringAsFixed(2)}'
                          : 'No confident match — best score: ${score.toStringAsFixed(2)}',
                    ),
                    isThreeLine: isMatch && matchedSantali != null,
                    trailing: Text(
                      _formatTime(timestamp),
                      style: const TextStyle(fontSize: 11, color: Colors.black45),
                    ),
                  ),
                );
              },
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