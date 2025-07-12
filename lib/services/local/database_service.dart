// lib/services/local/database_service.dart (CORRECTED VERSION)
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
      version: 4, // FIXED: Updated to version 4 for upload support
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

    // Bills table (UPDATED with loading cost support AND sync_status)
    await db.execute('''
      CREATE TABLE bills (
        id TEXT PRIMARY KEY,
        outlet_id TEXT NOT NULL,
        bill_number TEXT UNIQUE,
        subtotal_amount REAL NOT NULL DEFAULT 0.0,
        loading_cost REAL NOT NULL DEFAULT 0.0,
        total_amount REAL NOT NULL,
        discount_amount REAL DEFAULT 0,
        tax_amount REAL DEFAULT 0,
        payment_type TEXT NOT NULL,
        payment_status TEXT DEFAULT 'pending',
        outlet_name TEXT NOT NULL,
        outlet_address TEXT,
        outlet_phone TEXT,
        owner_id TEXT NOT NULL,
        business_id TEXT NOT NULL,
        created_by TEXT NOT NULL,
        sales_rep_name TEXT NOT NULL,
        sales_rep_phone TEXT,
        firebase_bill_id TEXT,
        sync_status TEXT DEFAULT 'pending',
        created_at INTEGER,
        updated_at INTEGER,
        FOREIGN KEY (outlet_id) REFERENCES outlets(id)
      )
    ''');

    // Bill items table
    await db.execute('''
      CREATE TABLE bill_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bill_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        product_code TEXT NOT NULL,
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
        route_id TEXT,
        route_name TEXT,
        is_active INTEGER DEFAULT 1,
        sync_status TEXT DEFAULT 'pending',
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');

    // ADDED: Unloading summaries table
    await db.execute('''
      CREATE TABLE unloading_summaries (
        id TEXT PRIMARY KEY,
        loading_id TEXT NOT NULL,
        business_id TEXT NOT NULL,
        owner_id TEXT NOT NULL,
        sales_rep_id TEXT NOT NULL,
        sales_rep_name TEXT NOT NULL,
        route_id TEXT,
        route_name TEXT,
        unloading_date INTEGER NOT NULL,
        total_bill_count INTEGER DEFAULT 0,
        total_sales_value REAL DEFAULT 0.0,
        total_cash_sales REAL DEFAULT 0.0,
        total_credit_sales REAL DEFAULT 0.0,
        total_cheque_sales REAL DEFAULT 0.0,
        total_items_loaded INTEGER DEFAULT 0,
        total_value_loaded REAL DEFAULT 0.0,
        items_sold_json TEXT,
        remaining_stock_json TEXT,
        created_at INTEGER NOT NULL,
        created_by TEXT NOT NULL,
        notes TEXT,
        status TEXT DEFAULT 'pending',
        sync_status TEXT DEFAULT 'pending'
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
      'CREATE INDEX idx_user_session_active ON user_session(is_active)',
    );
    await db.execute(
      'CREATE INDEX idx_loadings_sales_rep ON loadings(sales_rep_id, status)',
    );
    await db.execute('CREATE INDEX idx_bills_outlet ON bills(outlet_id)');
    await db.execute('CREATE INDEX idx_bills_created_at ON bills(created_at)');
    await db.execute(
      'CREATE INDEX idx_bills_business ON bills(business_id, created_by)',
    );
    await db.execute('CREATE INDEX idx_bill_items_bill ON bill_items(bill_id)');
    await db.execute(
      'CREATE INDEX idx_outlets_business ON outlets(business_id, is_active)',
    );
    await db.execute(
      'CREATE INDEX idx_sync_queue_status ON sync_queue(table_name, operation)',
    );
    await db.execute(
      'CREATE INDEX idx_unloading_summaries_rep ON unloading_summaries(sales_rep_id, unloading_date)',
    );
  }

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    print('Upgrading database from version $oldVersion to $newVersion');

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

    // Add loading cost support to bills table (version 3)
    if (oldVersion < 3) {
      try {
        // Add new columns to bills table
        await db.execute(
          'ALTER TABLE bills ADD COLUMN subtotal_amount REAL DEFAULT 0.0',
        );
        await db.execute(
          'ALTER TABLE bills ADD COLUMN loading_cost REAL DEFAULT 0.0',
        );

        print('Added subtotal_amount and loading_cost columns to bills table');

        // Update existing bills: set subtotal_amount = total_amount and loading_cost = 0
        await db.execute('''
          UPDATE bills 
          SET subtotal_amount = total_amount, 
              loading_cost = 0.0 
          WHERE subtotal_amount IS NULL OR subtotal_amount = 0.0
        ''');

        print('Updated existing bills with backward compatibility');
      } catch (e) {
        print(
          'Error adding loading cost columns (they might already exist): $e',
        );
      }
    }

    // FIXED: Add upload support (version 4)
    if (oldVersion < 4) {
      try {
        // Add sync_status column to bills table if not exists
        await db.execute(
          'ALTER TABLE bills ADD COLUMN sync_status TEXT DEFAULT "pending"',
        );
        print('Added sync_status column to bills table');
      } catch (e) {
        print('sync_status column might already exist: $e');
      }

      // Create unloading_summaries table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS unloading_summaries (
          id TEXT PRIMARY KEY,
          loading_id TEXT NOT NULL,
          business_id TEXT NOT NULL,
          owner_id TEXT NOT NULL,
          sales_rep_id TEXT NOT NULL,
          sales_rep_name TEXT NOT NULL,
          route_id TEXT,
          route_name TEXT,
          unloading_date INTEGER NOT NULL,
          total_bill_count INTEGER DEFAULT 0,
          total_sales_value REAL DEFAULT 0.0,
          total_cash_sales REAL DEFAULT 0.0,
          total_credit_sales REAL DEFAULT 0.0,
          total_cheque_sales REAL DEFAULT 0.0,
          total_items_loaded INTEGER DEFAULT 0,
          total_value_loaded REAL DEFAULT 0.0,
          items_sold_json TEXT,
          remaining_stock_json TEXT,
          created_at INTEGER NOT NULL,
          created_by TEXT NOT NULL,
          notes TEXT,
          status TEXT DEFAULT 'pending',
          sync_status TEXT DEFAULT 'pending'
        )
      ''');

      await db.execute(
        'CREATE INDEX idx_unloading_summaries_rep ON unloading_summaries(sales_rep_id, unloading_date)',
      );

      print('Created unloading_summaries table');
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

  // FIXED: Updated to use productCode instead of productId
  Future<void> updateLoadingSoldQuantities(
    String loadingId,
    Map<String, int> itemQuantities, // productCode -> quantity sold
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

    // Update quantities by productCode
    for (int i = 0; i < itemsList.length; i++) {
      final item = itemsList[i] as Map<String, dynamic>;
      final productCode = item['productCode'] as String; // Use productCode

      if (itemQuantities.containsKey(productCode)) {
        final currentQuantity = (item['bagQuantity'] as num?)?.toInt() ?? 0;
        final quantitySold = itemQuantities[productCode]!;
        // Reduce available quantity
        final newQuantity = (currentQuantity - quantitySold).clamp(
          0,
          currentQuantity,
        );
        item['bagQuantity'] = newQuantity;
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

  // NEW: Get bills for specific date
  Future<List<Map<String, dynamic>>> getBillsForDate(
    String ownerId,
    String businessId,
    DateTime date,
  ) async {
    final db = await database;

    // Calculate date range (start and end of day)
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final List<Map<String, dynamic>> maps = await db.query(
      'bills',
      where:
          'owner_id = ? AND business_id = ? AND created_at >= ? AND created_at <= ?',
      whereArgs: [
        ownerId,
        businessId,
        startOfDay.millisecondsSinceEpoch,
        endOfDay.millisecondsSinceEpoch,
      ],
      orderBy: 'created_at DESC',
    );

    return maps;
  }

  // NEW: Get pending bills (not uploaded)
  Future<List<Map<String, dynamic>>> getPendingBills(
    String ownerId,
    String businessId,
  ) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'bills',
      where:
          'owner_id = ? AND business_id = ? AND (sync_status = ? OR sync_status IS NULL)',
      whereArgs: [ownerId, businessId, 'pending'],
      orderBy: 'created_at DESC',
    );

    return maps;
  }

  // NEW: Mark bills as uploaded
  Future<void> markBillsAsUploaded(
    String ownerId,
    String businessId,
    DateTime date,
  ) async {
    final db = await database;

    // Calculate date range
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    await db.update(
      'bills',
      {'sync_status': 'uploaded'},
      where:
          'owner_id = ? AND business_id = ? AND created_at >= ? AND created_at <= ?',
      whereArgs: [
        ownerId,
        businessId,
        startOfDay.millisecondsSinceEpoch,
        endOfDay.millisecondsSinceEpoch,
      ],
    );
  }

  // Get bill items by bill ID
  Future<List<Map<String, dynamic>>> getBillItems(String billId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'bill_items',
      where: 'bill_id = ?',
      whereArgs: [billId],
      orderBy: 'id ASC',
    );

    return maps;
  }

  // NEW: Save unloading summary
  Future<void> saveUnloadingSummary(Map<String, dynamic> summaryData) async {
    final db = await database;

    await db.insert(
      'unloading_summaries',
      summaryData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // NEW: Get unloading summaries
  Future<List<Map<String, dynamic>>> getUnloadingSummaries(
    String ownerId,
    String businessId,
    String salesRepId,
  ) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'unloading_summaries',
      where: 'owner_id = ? AND business_id = ? AND sales_rep_id = ?',
      whereArgs: [ownerId, businessId, salesRepId],
      orderBy: 'unloading_date DESC',
      limit: 10,
    );

    return maps;
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
