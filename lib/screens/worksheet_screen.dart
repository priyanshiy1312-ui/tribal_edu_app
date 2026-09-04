import 'package:flutter/material.dart';

class WorksheetScreen extends StatelessWidget {
  const WorksheetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Worksheet')),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Worksheet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Text('Your worksheet content will appear here.'),
          ],
        ),
      ),
    );
  }
}
