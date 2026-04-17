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
      version: 3,
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
            value_on_revert TEXT NOT NULL,
            UNIQUE(package_name, setting_key) ON CONFLICT REPLACE
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_package_name ON app_settings(package_name)',
        );
        await _createCustomTemplatesTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Deduplicate: keep the row with highest id per (package_name, setting_key)
          await db.execute('''
            DELETE FROM app_settings WHERE id NOT IN (
              SELECT MAX(id) FROM app_settings GROUP BY package_name, setting_key
            )
          ''');
          // Recreate table with UNIQUE constraint
          await db.execute('''
            CREATE TABLE app_settings_new (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              package_name TEXT NOT NULL,
              enabled INTEGER NOT NULL DEFAULT 1,
              setting_type TEXT NOT NULL,
              label TEXT NOT NULL,
              setting_key TEXT NOT NULL,
              value_on_launch TEXT NOT NULL,
              value_on_revert TEXT NOT NULL,
              UNIQUE(package_name, setting_key) ON CONFLICT REPLACE
            )
          ''');
          await db.execute('''
            INSERT INTO app_settings_new (id, package_name, enabled, setting_type, label, setting_key, value_on_launch, value_on_revert)
            SELECT id, package_name, enabled, setting_type, label, setting_key, value_on_launch, value_on_revert FROM app_settings
          ''');
          await db.execute('DROP TABLE app_settings');
          await db.execute('ALTER TABLE app_settings_new RENAME TO app_settings');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_package_name ON app_settings(package_name)',
          );
        }
        if (oldVersion < 3) {
          await _createCustomTemplatesTable(db);
        }
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
    return db.insert(
      'app_settings',
      setting.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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

  Future<List<AppSetting>> getAllSettings() async {
    final db = await database;
    final maps = await db.query('app_settings');
    return maps.map(AppSetting.fromMap).toList();
  }

  // Custom templates

  static Future<void> _createCustomTemplatesTable(Database db) async {
    await db.execute('''
      CREATE TABLE custom_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        setting_type TEXT NOT NULL,
        label TEXT NOT NULL,
        setting_key TEXT NOT NULL,
        value_on_launch TEXT NOT NULL,
        value_on_revert TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        category TEXT NOT NULL DEFAULT 'Custom'
      )
    ''');
  }

  Future<int> insertCustomTemplate(Map<String, dynamic> template) async {
    final db = await database;
    return db.insert('custom_templates', template);
  }

  Future<List<Map<String, dynamic>>> getCustomTemplates() async {
    final db = await database;
    return db.query('custom_templates');
  }

  Future<int> deleteCustomTemplate(int id) async {
    final db = await database;
    return db.delete('custom_templates', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> copySettingsToPackage(String sourcePackage, String targetPackage) async {
    final settings = await getSettingsForPackage(sourcePackage);
    var count = 0;
    for (final setting in settings) {
      final copy = AppSetting(
        packageName: targetPackage,
        enabled: setting.enabled,
        settingType: setting.settingType,
        label: setting.label,
        key: setting.key,
        valueOnLaunch: setting.valueOnLaunch,
        valueOnRevert: setting.valueOnRevert,
      );
      await insertSetting(copy);
      count++;
    }
    return count;
  }

  Future<List<String>> getConfiguredPackages() async {
    final db = await database;
    final results = await db.rawQuery(
      'SELECT DISTINCT package_name FROM app_settings',
    );
    return results.map((r) => r['package_name'] as String).toList();
  }
}
