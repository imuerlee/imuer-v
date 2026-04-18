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
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    final columns = await db.rawQuery('PRAGMA table_info(servers)');
    final columnNames = columns.map((c) => c['name'] as String).toList();

    final newColumns = [
      ('fingerprint', 'TEXT'),
      ('verify_hostname', 'INTEGER'),
      ('public_key', 'TEXT'),
      ('private_key', 'TEXT'),
      ('peer_public_key', 'TEXT'),
      ('preshared_key', 'TEXT'),
      ('obfs_password', 'TEXT'),
      ('speed_limit', 'INTEGER'),
      ('speed_limit_up', 'INTEGER'),
      ('speed_limit_down', 'INTEGER'),
      ('auth', 'INTEGER'),
      ('auth_username', 'TEXT'),
      ('auth_password', 'TEXT'),
      ('allow_insecure', 'INTEGER'),
      ('plugin_opts', 'TEXT'),
      ('protocol_param', 'TEXT'),
      ('obfs_param', 'TEXT'),
      ('public_key1', 'TEXT'),
      ('short_id', 'TEXT'),
      ('subscription_url', 'TEXT'),
      ('subscription_download', 'INTEGER'),
      ('subscription_upload', 'INTEGER'),
      ('subscription_total', 'INTEGER'),
      ('subscription_expire', 'TEXT'),
    ];

    for (final (colName, colType) in newColumns) {
      if (!columnNames.contains(colName)) {
        await db.execute('ALTER TABLE servers ADD COLUMN $colName $colType');
      }
    }
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
        fingerprint TEXT,
        verify_hostname INTEGER,
        public_key TEXT,
        private_key TEXT,
        peer_public_key TEXT,
        preshared_key TEXT,
        mtu INTEGER,
        reserved TEXT,
        obfs_password TEXT,
        speed_limit INTEGER,
        speed_limit_up INTEGER,
        speed_limit_down INTEGER,
        auth INTEGER,
        auth_username TEXT,
        auth_password TEXT,
        allow_insecure INTEGER,
        flow TEXT,
        method TEXT,
        plugin TEXT,
        plugin_opts TEXT,
        protocol_param TEXT,
        obfs TEXT,
        obfs_param TEXT,
        public_key1 TEXT,
        short_id TEXT,
        country TEXT,
        city TEXT,
        latitude REAL,
        longitude REAL,
        latency INTEGER,
        download_speed INTEGER,
        is_active INTEGER DEFAULT 1,
        group_id TEXT,
        subscription_url TEXT,
        subscription_upload INTEGER,
        subscription_download INTEGER,
        subscription_total INTEGER,
        subscription_expire TEXT,
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

  Future<bool> insertServer(ServerNodeModel server) async {
    final db = await database;
    
    try {
      final result = await db.insert(
        'servers',
        server.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return result > 0;
    } catch (e) {
      throw Exception('Failed to insert server: $e');
    }
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
