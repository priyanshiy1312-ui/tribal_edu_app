import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/phrase.dart';

class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'tribal_edu_app.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE phrases (
            id INTEGER PRIMARY KEY,
            hindi_phrase TEXT NOT NULL,
            santali_phrase TEXT NOT NULL,
            category TEXT,
            notes TEXT
          )
        ''');
      },
    );
  }

  Future<int> loadPhrasesFromCsv() async {
    final db = await database;

    final rawCsv = await rootBundle.loadString(
      'assets/data/phrases.csv',
      cache: false,
    );

    final rows =  CsvToListConverter(eol: '\n').convert(rawCsv);

    if (rows.isEmpty) {
      throw Exception('phrases.csv appears to be empty.');
    }

    final header = rows.first.map((e) => e.toString().trim()).toList();
    final dataRows = rows.skip(1);

    final idIdx = header.indexOf('id');
    final hindiIdx = header.indexOf('hindi_phrase');
    final santaliIdx = header.indexOf('santali_phrase');
    final categoryIdx = header.indexOf('category');
    final notesIdx = header.indexOf('notes');

    if (idIdx == -1 || hindiIdx == -1 || santaliIdx == -1) {
      throw Exception(
        'phrases.csv header is missing required columns. Found header: $header',
      );
    }

    final batch = db.batch();
    batch.delete('phrases');

    for (final row in dataRows) {
      if (row.length < 3) continue; // skip blank rows
      final idRaw = row[idIdx].toString().trim();
      if (idRaw.isEmpty) continue; // skip trailing blank rows from Excel

      final phrase = Phrase(
        id: int.parse(idRaw),
        hindiPhrase: row[hindiIdx].toString().trim(),
        santaliPhrase: row[santaliIdx].toString().trim(),
        category: categoryIdx != -1 ? row[categoryIdx].toString().trim() : '',
        notes: notesIdx != -1 ? row[notesIdx].toString().trim() : '',
      );

      batch.insert(
        'phrases',
        phrase.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);

    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM phrases'),
    );
    return count ?? 0;
  }

  Future<List<Phrase>> getAllPhrases() async {
    final db = await database;
    final maps = await db.query('phrases');
    return maps.map((m) => Phrase.fromMap(m)).toList();
  }
}