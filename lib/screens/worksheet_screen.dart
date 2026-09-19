import 'package:flutter/material.dart';

import '../models/worksheet_item.dart';

/// Day 6 — Worksheet screen.
///
/// A simple bilingual (Hindi + Santali) classroom reference sheet,
/// built from real phrases in our set. Hardcoded for now, as planned —
/// no database dependency, so this can't break independently of
/// anything else in the app.
class WorksheetScreen extends StatelessWidget {
  const WorksheetScreen({super.key});

  static const List<WorksheetItem> _items = [
    WorksheetItem(
      title: 'Basic Instructions',
      hindiText: 'खड़े हो जाओ',
      hindiRomanized: 'khade ho jao',
      santaliText: 'ᱛᱤᱸᱜᱩ ᱯᱮ',
      category: 'instruction',
    ),
    WorksheetItem(
      title: 'Basic Instructions',
      hindiText: 'बैठ जाओ',
      hindiRomanized: 'baith jao',
      santaliText: 'ᱫᱩᱵᱩᱱ ᱯᱮ',
      category: 'instruction',
    ),
    WorksheetItem(
      title: 'Basic Instructions',
      hindiText: 'अपनी नोटबुक खोलो',
      hindiRomanized: 'apni notebook kholo',
      santaliText: 'ᱟᱢᱟᱜ ᱱᱳᱴᱵᱩᱠ ᱠᱚ ᱮᱛᱦᱚᱵ ᱢᱮ',
      category: 'instruction',
    ),
    WorksheetItem(
      title: 'Encouragement & Praise',
      hindiText: 'बहुत बढ़िया! आपने बहुत अच्छा प्रयास किया।',
      hindiRomanized: 'bahut badhiya aapne bahut accha prayas kiya',
      santaliText: 'ᱟᱹᱰᱤ ᱱᱟᱯᱟᱭ! ᱟᱢ ᱟᱹᱰᱤ ᱱᱟᱯᱟᱭ ᱠᱩᱨᱩᱢᱩᱴᱩ ᱠᱮᱫᱟ ᱾',
      category: 'praise',
    ),
  ];

  Color _categoryColor(String category) {
    switch (category) {
      case 'instruction':
        return Colors.blue;
      case 'praise':
        return Colors.green;
      case 'encouragement':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Worksheet')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _categoryColor(item.category).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.category,
                          style: TextStyle(
                            color: _categoryColor(item.category),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.hindiText,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '(${item.hindiRomanized})',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const Divider(height: 20),
                  Text(
                    item.santaliText,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}