import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import '../services/database_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<LogEntry> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final rows = await DatabaseService.instance.getMatchLogs();
    final logs = rows.map((r) => LogEntry.fromMap(r)).toList();
    logs.sort((a, b) => a.score.compareTo(b.score));
    setState(() {
      _logs = logs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_logs.isEmpty) {
      return const Center(child: Text('No logged attempts yet.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        return ListTile(
          title: Text(log.recognizedText),
          subtitle: Text(
            'Matched: ${log.matchedSantali ?? "-"}  |  Score: ${log.score.toStringAsFixed(2)}',
          ),
          trailing: Icon(
            log.isMatch ? Icons.check_circle : Icons.cancel,
            color: log.isMatch ? Colors.green : Colors.red,
          ),
        );
      },
    );
  }
}