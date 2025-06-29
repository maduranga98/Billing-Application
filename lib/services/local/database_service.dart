// lib/services/local/database_service.dart (Updated with Loading support)
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../../models/loading.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'lumorabiz_billing.db');

    return await openDatabase(
      path,
      version: 2, // Increased version for new tables
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    // User session table
    await db.execute('''
      CREATE TABLE user_session (
        id INTEGER PRIMARY KEY,
        user_id TEXT NOT NULL,
        owner_id TEXT NOT NULL,
        business_id TEXT NOT NULL,
        employee_id TEXT NOT NULL,
        username TEXT NOT NULL,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        role TEXT,
        image_url TEXT,
        login_time INTEGER,
        is_active INTEGER DEFAULT 1
      )
    ''');

    // Loadings table (replaces stock table)
    await db.execute('''
      CREATE TABLE loadings (
        loading_id TEXT PRIMARY KEY,
        business_id TEXT NOT NULL,
        owner_id TEXT NOT NULL,
        route_id TEXT NOT NULL,
        sales_rep_id TEXT NOT NULL,
        sales_rep_name TEXT NOT NULL,
        sales_rep_email TEXT NOT NULL,
        sales_rep_phone TEXT NOT NULL,
        status TEXT NOT NULL,
        item_count INTEGER NOT NULL,
        total_bags REAL NOT NULL,
        total_value REAL NOT NULL,
        items TEXT NOT NULL,
        today_route TEXT,
        created_at INTEGER NOT NULL,
        created_by TEXT NOT NULL,
        sync_status TEXT DEFAULT 'synced'
      )
    ''');

    // Bills table
    await db.execute('''
      CREATE TABLE bills (
        id TEXT PRIMARY KEY,
        outlet_id TEXT NOT NULL,
        bill_number TEXT UNIQUE,
        total_amount REAL NOT NULL,
        discount_amount REAL DEFAULT 0,
        tax_amount REAL DEFAULT 0,
        payment_type TEXT NOT NULL,
        payment_status TEXT DEFAULT 'pending',
        owner_id TEXT NOT NULL,
        business_id TEXT NOT NULL,
        created_by TEXT NOT NULL,
        firebase_bill_id TEXT,
        sync_status TEXT DEFAULT 'pending',
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');

    // Bill items table
    await db.execute('''
      CREATE TABLE bill_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bill_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        total_price REAL NOT NULL,
        FOREIGN KEY (bill_id) REFERENCES bills(id)
      )
    ''');

    // Outlets table
    await db.execute('''
      CREATE TABLE outlets (
        id TEXT PRIMARY KEY,
        outlet_name TEXT NOT NULL,
        address TEXT,
        phone TEXT,
        latitude REAL,
        longitude REAL,
        owner_name TEXT,
        outlet_type TEXT,
        image_base64 TEXT,
        image_path TEXT,
        firebase_image_url TEXT,
        owner_id TEXT NOT NULL,
        business_id TEXT NOT NULL,
        created_by TEXT NOT NULL,
        sync_status TEXT DEFAULT 'pending',
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');

    // Sync queue table
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        data TEXT,
        owner_id TEXT NOT NULL,
        business_id TEXT NOT NULL,
        created_at INTEGER,
        retry_count INTEGER DEFAULT 0,
        last_retry_at INTEGER
      )
    ''');

    // Create indexes
    await db.execute(
      'CREATE INDEX idx_loadings_sales_rep ON loadings(sales_rep_id, status)',
    );
    await db.execute('CREATE INDEX idx_bills_outlet ON bills(outlet_id)');
    await db.execute('CREATE INDEX idx_bills_created_at ON bills(created_at)');
    await db.execute(
      'CREATE INDEX idx_sync_queue_status ON sync_queue(table_name, operation)',
    );
  }

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      // Migration from stock-based to loading-based structure
      await db.execute('DROP TABLE IF EXISTS stock');

      // Create new loadings table
      await db.execute('''
        CREATE TABLE loadings (
          loading_id TEXT PRIMARY KEY,
          business_id TEXT NOT NULL,
          owner_id TEXT NOT NULL,
          route_id TEXT NOT NULL,
          sales_rep_id TEXT NOT NULL,
          sales_rep_name TEXT NOT NULL,
          sales_rep_email TEXT NOT NULL,
          sales_rep_phone TEXT NOT NULL,
          status TEXT NOT NULL,
          item_count INTEGER NOT NULL,
          total_bags REAL NOT NULL,
          total_value REAL NOT NULL,
          items TEXT NOT NULL,
          today_route TEXT,
          created_at INTEGER NOT NULL,
          created_by TEXT NOT NULL,
          sync_status TEXT DEFAULT 'synced'
        )
      ''');

      await db.execute(
        'CREATE INDEX idx_loadings_sales_rep ON loadings(sales_rep_id, status)',
      );
    }
  }

  // Loading-related methods
  Future<void> syncLoading(Loading loading) async {
    final db = await database;

    await db.insert(
      'loadings',
      loading.toSQLite(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Loading?> getTodaysLoading(
    String ownerId,
    String businessId,
    String salesRepId,
  ) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'loadings',
      where:
          'owner_id = ? AND business_id = ? AND sales_rep_id = ? AND status = ?',
      whereArgs: [ownerId, businessId, salesRepId, 'prepared'],
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Loading.fromSQLite(maps.first);
  }

  Future<void> updateLoadingSoldQuantities(
    String loadingId,
    Map<String, int> itemQuantities,
  ) async {
    final db = await database;

    // Get current loading
    final List<Map<String, dynamic>> maps = await db.query(
      'loadings',
      where: 'loading_id = ?',
      whereArgs: [loadingId],
      limit: 1,
    );

    if (maps.isEmpty) return;

    final loadingData = maps.first;
    final itemsJson = loadingData['items'] as String;
    final itemsList = jsonDecode(itemsJson) as List<dynamic>;

    // Update sold quantities
    for (int i = 0; i < itemsList.length; i++) {
      final item = itemsList[i] as Map<String, dynamic>;
      final productId = item['productId'] as String;

      if (itemQuantities.containsKey(productId)) {
        final currentSold = item['soldQuantity'] ?? 0;
        final additionalSold = itemQuantities[productId]!;
        item['soldQuantity'] = currentSold + additionalSold;
      }
    }

    // Update the loading record
    await db.update(
      'loadings',
      {'items': jsonEncode(itemsList), 'sync_status': 'pending'},
      where: 'loading_id = ?',
      whereArgs: [loadingId],
    );
  }

  // Bill-related methods
  Future<void> insertBill(
    Map<String, dynamic> billData,
    List<Map<String, dynamic>> billItems,
  ) async {
    final db = await database;

    await db.transaction((txn) async {
      // Insert bill
      await txn.insert('bills', billData);

      // Insert bill items
      for (final item in billItems) {
        await txn.insert('bill_items', item);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getBills({
    required String ownerId,
    required String businessId,
    String? outletId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final db = await database;

    String whereClause = 'owner_id = ? AND business_id = ?';
    List<dynamic> whereArgs = [ownerId, businessId];

    if (outletId != null) {
      whereClause += ' AND outlet_id = ?';
      whereArgs.add(outletId);
    }

    if (fromDate != null) {
      whereClause += ' AND created_at >= ?';
      whereArgs.add(fromDate.millisecondsSinceEpoch);
    }

    if (toDate != null) {
      whereClause += ' AND created_at <= ?';
      whereArgs.add(toDate.millisecondsSinceEpoch);
    }

    return await db.query(
      'bills',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getBillItems(String billId) async {
    final db = await database;

    return await db.query(
      'bill_items',
      where: 'bill_id = ?',
      whereArgs: [billId],
    );
  }

  // Outlet-related methods
  Future<void> insertOutlet(Map<String, dynamic> outletData) async {
    final db = await database;

    await db.insert(
      'outlets',
      outletData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getOutlets(
    String ownerId,
    String businessId,
  ) async {
    final db = await database;

    return await db.query(
      'outlets',
      where: 'owner_id = ? AND business_id = ?',
      whereArgs: [ownerId, businessId],
      orderBy: 'outlet_name ASC',
    );
  }

  // Sync queue methods
  Future<void> addToSyncQueue({
    required String tableName,
    required String recordId,
    required String operation,
    required String ownerId,
    required String businessId,
    Map<String, dynamic>? data,
  }) async {
    final db = await database;

    await db.insert('sync_queue', {
      'table_name': tableName,
      'record_id': recordId,
      'operation': operation,
      'data': data != null ? jsonEncode(data) : null,
      'owner_id': ownerId,
      'business_id': businessId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'retry_count': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    final db = await database;

    return await db.query('sync_queue', orderBy: 'created_at ASC');
  }

  Future<void> removeSyncQueueItem(int id) async {
    final db = await database;

    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateSyncRetryCount(int id) async {
    final db = await database;

    await db.update(
      'sync_queue',
      {
        'retry_count': 'retry_count + 1',
        'last_retry_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // User session methods
  Future<void> saveUserSession(Map<String, dynamic> sessionData) async {
    final db = await database;

    // Clear existing sessions
    await db.delete('user_session');

    // Insert new session
    await db.insert('user_session', sessionData);
  }

  Future<Map<String, dynamic>?> getCurrentUserSession() async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'user_session',
      where: 'is_active = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<void> clearUserSession() async {
    final db = await database;

    await db.delete('user_session');
  }

  // Database maintenance
  Future<void> clearOldData({int daysToKeep = 30}) async {
    final db = await database;
    final cutoffTime =
        DateTime.now()
            .subtract(Duration(days: daysToKeep))
            .millisecondsSinceEpoch;

    await db.transaction((txn) async {
      // Clear old bills
      await txn.delete(
        'bills',
        where: 'created_at < ? AND sync_status = ?',
        whereArgs: [cutoffTime, 'synced'],
      );

      // Clear old sync queue items
      await txn.delete(
        'sync_queue',
        where: 'created_at < ? AND retry_count > ?',
        whereArgs: [cutoffTime, 5],
      );
    });
  }

  // Close database
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
