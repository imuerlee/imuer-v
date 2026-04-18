import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../core/constants/app_constants.dart';
import '../models/server_node_model.dart';

class LocalDatabase {
  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), AppConstants.dbName);
    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE servers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        address TEXT NOT NULL,
        port INTEGER NOT NULL,
        protocol TEXT NOT NULL,
        username TEXT,
        password TEXT,
        uuid TEXT,
        alter_id INTEGER,
        security TEXT,
        network TEXT,
        tls TEXT,
        host TEXT,
        path TEXT,
        sni TEXT,
        alpn TEXT,
        country TEXT,
        city TEXT,
        latitude REAL,
        longitude REAL,
        latency INTEGER,
        download_speed INTEGER,
        is_active INTEGER DEFAULT 1,
        group_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE traffic_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        upload_bytes INTEGER DEFAULT 0,
        download_bytes INTEGER DEFAULT 0
      )
    ''');
  }

  Future<List<ServerNodeModel>> getServers() async {
    final db = await database;
    final maps = await db.query('servers', orderBy: 'name ASC');
    return maps.map((map) => ServerNodeModel.fromJson(map)).toList();
  }

  Future<ServerNodeModel?> getServerById(String id) async {
    final db = await database;
    final maps = await db.query('servers', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return ServerNodeModel.fromJson(maps.first);
  }

  Future<void> insertServer(ServerNodeModel server) async {
    final db = await database;
    await db.insert(
      'servers',
      server.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateServer(ServerNodeModel server) async {
    final db = await database;
    await db.update(
      'servers',
      server.toJson(),
      where: 'id = ?',
      whereArgs: [server.id],
    );
  }

  Future<void> deleteServer(String id) async {
    final db = await database;
    await db.delete('servers', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateServerLatency(String id, int latency) async {
    final db = await database;
    await db.update(
      'servers',
      {'latency': latency},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateServerSpeed(String id, int downloadSpeed) async {
    final db = await database;
    await db.update(
      'servers',
      {'download_speed': downloadSpeed},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getTrafficLogs({int days = 7}) async {
    final db = await database;
    final startDate = DateTime.now().subtract(Duration(days: days));
    return db.query(
      'traffic_logs',
      where: 'date >= ?',
      whereArgs: [startDate.toIso8601String().split('T')[0]],
      orderBy: 'date ASC',
    );
  }

  Future<void> updateTrafficLog(String date, int uploadBytes, int downloadBytes) async {
    final db = await database;
    await db.insert(
      'traffic_logs',
      {
        'date': date,
        'upload_bytes': uploadBytes,
        'download_bytes': downloadBytes,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
