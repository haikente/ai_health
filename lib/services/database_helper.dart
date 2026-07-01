import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/health_data_point.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'health_data.db');

    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE health_data_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        value REAL NOT NULL,
        systolic REAL,
        diastolic REAL,
        unit TEXT NOT NULL,
        dateFrom TEXT NOT NULL,
        dateTo TEXT NOT NULL,
        source TEXT NOT NULL,
        UNIQUE(type, dateFrom, source)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      // Xoá dữ liệu cũ có timestamp mili-giây gây trùng lặp
      await db.execute('DROP TABLE IF EXISTS health_data_points');
      await _onCreate(db, newVersion);
    }
  }

  Future<int> insertDataPoint(HealthDataPoint point) async {
    final db = await database;
    return await db.insert(
      'health_data_points',
      point.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertDataPoints(List<HealthDataPoint> points) async {
    if (points.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final point in points) {
      batch.insert(
        'health_data_points',
        point.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<HealthDataPoint>> getDataPoints({
    DateTime? start,
    DateTime? end,
  }) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (start != null && end != null) {
      whereClause = 'dateFrom BETWEEN ? AND ?';
      whereArgs = [start.toIso8601String(), end.toIso8601String()];
    } else if (start != null) {
      whereClause = 'dateFrom >= ?';
      whereArgs = [start.toIso8601String()];
    } else if (end != null) {
      whereClause = 'dateFrom <= ?';
      whereArgs = [end.toIso8601String()];
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'health_data_points',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'dateFrom ASC',
    );

    return List.generate(maps.length, (i) {
      return HealthDataPoint.fromJson(maps[i]);
    });
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('health_data_points');
  }
}
