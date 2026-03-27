import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/app_setting.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'expresspass.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE app_settings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            package_name TEXT NOT NULL,
            enabled INTEGER NOT NULL DEFAULT 1,
            setting_type TEXT NOT NULL,
            label TEXT NOT NULL,
            setting_key TEXT NOT NULL,
            value_on_launch TEXT NOT NULL,
            value_on_revert TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_package_name ON app_settings(package_name)',
        );
      },
    );
  }

  Future<List<AppSetting>> getSettingsForPackage(String packageName) async {
    final db = await database;
    final maps = await db.query(
      'app_settings',
      where: 'package_name = ?',
      whereArgs: [packageName],
    );
    return maps.map(AppSetting.fromMap).toList();
  }

  Future<Map<String, int>> getSettingsCountByPackage() async {
    final db = await database;
    final results = await db.rawQuery(
      'SELECT package_name, COUNT(*) as count FROM app_settings GROUP BY package_name',
    );
    return {
      for (final row in results)
        row['package_name'] as String: row['count'] as int,
    };
  }

  Future<int> insertSetting(AppSetting setting) async {
    final db = await database;
    return db.insert('app_settings', setting.toMap()..remove('id'));
  }

  Future<int> updateSetting(AppSetting setting) async {
    final db = await database;
    return db.update(
      'app_settings',
      setting.toMap(),
      where: 'id = ?',
      whereArgs: [setting.id],
    );
  }

  Future<int> deleteSetting(int id) async {
    final db = await database;
    return db.delete('app_settings', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteSettingsForPackage(String packageName) async {
    final db = await database;
    return db.delete(
      'app_settings',
      where: 'package_name = ?',
      whereArgs: [packageName],
    );
  }
}
