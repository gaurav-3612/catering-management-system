import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('catering_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Table for Menus
    await db.execute('''
      CREATE TABLE cached_menus (
        id INTEGER PRIMARY KEY,
        user_id INTEGER,
        json_data TEXT
      )
    ''');

    // 2. Table for Invoices
    await db.execute('''
      CREATE TABLE cached_invoices (
        id INTEGER PRIMARY KEY,
        user_id INTEGER,
        json_data TEXT
      )
    ''');
  }

  // --- MENU CACHING ---
  Future<void> cacheMenus(int userId, List<dynamic> menus) async {
    final db = await instance.database;
    // Clear old data for this user so we don't have duplicates
    await db.delete('cached_menus', where: 'user_id = ?', whereArgs: [userId]);

    for (var menu in menus) {
      await db.insert(
          'cached_menus',
          {
            'id': menu['id'],
            'user_id': userId,
            'json_data': jsonEncode(menu),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<List<dynamic>> getCachedMenus(int userId) async {
    final db = await instance.database;
    final result = await db.query('cached_menus',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'id DESC');

    return result.map((e) => jsonDecode(e['json_data'] as String)).toList();
  }

  // --- INVOICE CACHING ---
  Future<void> cacheInvoices(int userId, List<dynamic> invoices) async {
    final db = await instance.database;
    await db
        .delete('cached_invoices', where: 'user_id = ?', whereArgs: [userId]);

    for (var inv in invoices) {
      await db.insert(
          'cached_invoices',
          {
            'id': inv['id'],
            'user_id': userId,
            'json_data': jsonEncode(inv),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<List<dynamic>> getCachedInvoices(int userId) async {
    final db = await instance.database;
    final result = await db.query('cached_invoices',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'id DESC');

    return result.map((e) => jsonDecode(e['json_data'] as String)).toList();
  }

  // Clear all data (on Logout)
  Future<void> clearAll() async {
    final db = await instance.database;
    await db.delete('cached_menus');
    await db.delete('cached_invoices');
  }
}
