// lib/services/local/database_service.dart (UPDATED with Enhanced Unloading Support)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../../models/loading.dart';
import '../../models/unloading_summary.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<void> insertOrUpdateStockItem(Map<String, dynamic> stockItem) async {
    final db = await database;

    await db.insert('stock_items', {
      'id': stockItem['id'],
      'item_name': stockItem['itemName'] ?? stockItem['productName'],
      'item_code': stockItem['itemCode'] ?? stockItem['productCode'],
      'unit_price': stockItem['unitPrice'] ?? 0.0,
      'current_quantity': stockItem['currentQuantity'] ?? 0,
      'min_quantity': stockItem['minQuantity'] ?? 0,
      'category': stockItem['category'] ?? 'general',
      'owner_id': stockItem['ownerId'],
      'business_id': stockItem['businessId'],
      'is_active': stockItem['isActive'] == true ? 1 : 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
      'sync_status': 'synced',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertOrUpdateOutlet(Map<String, dynamic> outlet) async {
    final db = await database;

    await db.insert('outlets', {
      'id': outlet['id'],
      'outlet_name': outlet['outletName'],
      'address': outlet['address'] ?? '',
      'phone': outlet['phoneNumber'] ?? outlet['phone'] ?? '',
      'latitude':
          outlet['coordinates']?['latitude'] ?? outlet['latitude'] ?? 0.0,
      'longitude':
          outlet['coordinates']?['longitude'] ?? outlet['longitude'] ?? 0.0,
      'owner_name': outlet['ownerName'] ?? '',
      'outlet_type': outlet['outletType'] ?? 'general',
      'firebase_image_url': outlet['imageUrl'],
      'owner_id': outlet['ownerId'],
      'business_id': outlet['businessId'],
      'created_by': outlet['createdBy'] ?? '',
      'route_id': outlet['routeId'] ?? '',
      'route_name': outlet['routeName'] ?? '',
      'is_active': outlet['isActive'] == true ? 1 : 0,
      'created_at':
          outlet['createdAt'] is Timestamp
              ? (outlet['createdAt'] as Timestamp).millisecondsSinceEpoch
              : DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
      'sync_status': 'synced',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'lumorabiz_billing.db');

    return await openDatabase(
      path,
      version: 5, // UPDATED: Version 5 for enhanced unloading support
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

    // UPDATED: Loadings table with enhanced columns
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
        total_weight REAL DEFAULT 0.0,
        items TEXT NOT NULL,
        today_route TEXT,
        paddy_price_date TEXT,
        today_paddy_prices TEXT,
        created_at INTEGER NOT NULL,
        created_by TEXT NOT NULL,
        sync_status TEXT DEFAULT 'synced'
      )
    ''');

    // Bills table with loading cost support AND sync_status
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

    // ENHANCED: Unloading summaries table with bill numbers and detailed analytics
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
        bill_numbers_json TEXT,
        sales_analytics_json TEXT,
        inventory_analytics_json TEXT,
        product_summary_json TEXT,
        created_at INTEGER NOT NULL,
        created_by TEXT NOT NULL,
        notes TEXT,
        status TEXT DEFAULT 'pending',
        sync_status TEXT DEFAULT 'pending',
        data_version TEXT DEFAULT '2.0'
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
    // NEW: Additional indexes for enhanced unloading
    await db.execute(
      'CREATE INDEX idx_unloading_summaries_date ON unloading_summaries(unloading_date DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_bills_sync_status ON bills(owner_id, business_id, sync_status)',
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

    // Add upload support (version 4)
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

      // Create basic unloading_summaries table
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

      print('Created basic unloading_summaries table');
    }

    // NEW: Enhanced unloading support (version 5)
    if (oldVersion < 5) {
      try {
        // Add enhanced columns to unloading_summaries table
        await db.execute(
          'ALTER TABLE unloading_summaries ADD COLUMN bill_numbers_json TEXT',
        );
        await db.execute(
          'ALTER TABLE unloading_summaries ADD COLUMN sales_analytics_json TEXT',
        );
        await db.execute(
          'ALTER TABLE unloading_summaries ADD COLUMN inventory_analytics_json TEXT',
        );
        await db.execute(
          'ALTER TABLE unloading_summaries ADD COLUMN product_summary_json TEXT',
        );
        await db.execute(
          'ALTER TABLE unloading_summaries ADD COLUMN data_version TEXT DEFAULT "2.0"',
        );

        // Add enhanced columns to loadings table
        await db.execute(
          'ALTER TABLE loadings ADD COLUMN total_weight REAL DEFAULT 0.0',
        );
        await db.execute(
          'ALTER TABLE loadings ADD COLUMN paddy_price_date TEXT',
        );
        await db.execute(
          'ALTER TABLE loadings ADD COLUMN today_paddy_prices TEXT',
        );

        // Add new indexes
        await db.execute(
          'CREATE INDEX idx_unloading_summaries_date ON unloading_summaries(unloading_date DESC)',
        );
        await db.execute(
          'CREATE INDEX idx_bills_sync_status ON bills(owner_id, business_id, sync_status)',
        );

        print(
          'Enhanced unloading_summaries table with bill numbers and detailed analytics',
        );
      } catch (e) {
        print('Error upgrading to enhanced unloading support: $e');
      }
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
    print("Loading saved to local DB: ${loading.loadingId}");
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

  // ENHANCED: Updated to use productCode with enhanced tracking
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

    // Update quantities by productCode with detailed tracking
    for (int i = 0; i < itemsList.length; i++) {
      final item = itemsList[i] as Map<String, dynamic>;
      final productCode = item['productCode'] as String;

      if (itemQuantities.containsKey(productCode)) {
        final currentQuantity = (item['bagQuantity'] as num?)?.toInt() ?? 0;
        final quantitySold = itemQuantities[productCode]!;
        final newQuantity = (currentQuantity - quantitySold).clamp(
          0,
          currentQuantity,
        );

        // Enhanced tracking
        item['bagQuantity'] = newQuantity;
        item['soldQuantity'] = (item['soldQuantity'] ?? 0) + quantitySold;
        item['lastSaleUpdate'] = DateTime.now().millisecondsSinceEpoch;

        print(
          'Updated loading item ${item['itemName']}: sold $quantitySold, remaining $newQuantity',
        );
      }
    }

    // Update the loading record with enhanced metadata
    await db.update(
      'loadings',
      {
        'items': jsonEncode(itemsList),
        'sync_status': 'pending',
        'last_quantity_update': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'loading_id = ?',
      whereArgs: [loadingId],
    );

    print('Loading quantities updated for ${itemQuantities.length} products');
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

    print(
      'Bill inserted: ${billData['bill_number']} with ${billItems.length} items',
    );
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

  // Get bills for specific date
  Future<List<Map<String, dynamic>>> getBillsForDate(
    String ownerId,
    String businessId,
    DateTime date,
  ) async {
    final db = await database;

    // Start and end of the day
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return await db.query(
      'bills',
      where:
          'owner_id = ? AND business_id = ? AND created_at >= ? AND created_at < ?',
      whereArgs: [
        ownerId,
        businessId,
        startOfDay.millisecondsSinceEpoch,
        endOfDay.millisecondsSinceEpoch,
      ],
      orderBy: 'created_at DESC',
    );
  }

  // Get pending bills (not uploaded)
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

  // Mark bills as uploaded
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

    print(
      'Marked bills as uploaded for date: ${date.toLocal().toString().split(' ')[0]}',
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

  // ENHANCED: Save unloading summary with bill numbers and detailed analytics
  // Ensures one unloading document per sales rep per day
  Future<void> saveEnhancedUnloadingSummary(UnloadingSummary summary) async {
    final db = await database;

    // Check if unloading already exists for this sales rep on this date
    final existingUnloading = await getUnloadingSummaryByDate(
      summary.ownerId,
      summary.businessId,
      summary.salesRepId,
      summary.unloadingDate,
    );

    if (existingUnloading != null) {
      print(
        'Unloading already exists for ${summary.salesRepName} on ${summary.unloadingDate.toLocal().toString().split(' ')[0]}',
      );
      throw Exception(
        'Unloading document already exists for this sales rep on ${summary.unloadingDate.toLocal().toString().split(' ')[0]}. Only one unloading per day is allowed.',
      );
    }

    final data = summary.toSQLite();

    // Generate analytics data locally instead of calling private methods
    final billNumbers = summary.billNumbers;
    final salesAnalytics = _generateSalesAnalyticsData(summary);
    final inventoryAnalytics = _generateInventoryAnalyticsData(summary);
    final productSummary = _generateProductSummaryData(summary);

    // Add enhanced analytics data
    data['bill_numbers_json'] = jsonEncode(billNumbers);
    data['sales_analytics_json'] = jsonEncode(salesAnalytics);
    data['inventory_analytics_json'] = jsonEncode(inventoryAnalytics);
    data['product_summary_json'] = jsonEncode(productSummary);

    await db.insert(
      'unloading_summaries',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    print(
      'Enhanced unloading summary saved for ${summary.salesRepName} on ${summary.unloadingDate.toLocal().toString().split(' ')[0]} with ${billNumbers.length} bills',
    );
  }

  // HELPER: Generate sales analytics data locally
  Map<String, dynamic> _generateSalesAnalyticsData(UnloadingSummary summary) {
    // Extract bill counts from notes
    int cashBillCount = 0;
    int creditBillCount = 0;
    int chequeBillCount = 0;

    final billLines = summary.notes.split('\n');
    for (final line in billLines) {
      if (line.contains('Cash:') && line.contains('bills')) {
        final match = RegExp(r'(\d+)\s+bills').firstMatch(line);
        if (match != null) cashBillCount = int.tryParse(match.group(1)!) ?? 0;
      } else if (line.contains('Credit:') && line.contains('bills')) {
        final match = RegExp(r'(\d+)\s+bills').firstMatch(line);
        if (match != null) creditBillCount = int.tryParse(match.group(1)!) ?? 0;
      } else if (line.contains('Cheque:') && line.contains('bills')) {
        final match = RegExp(r'(\d+)\s+bills').firstMatch(line);
        if (match != null) chequeBillCount = int.tryParse(match.group(1)!) ?? 0;
      }
    }

    return {
      'totalBills': summary.totalBillCount,
      'cashBills': cashBillCount,
      'creditBills': creditBillCount,
      'chequeBills': chequeBillCount,
      'averageBillValue':
          summary.totalBillCount > 0
              ? summary.totalSalesValue / summary.totalBillCount
              : 0.0,
      'salesPercentage':
          summary.totalValueLoaded > 0
              ? (summary.totalSalesValue / summary.totalValueLoaded) * 100
              : 0.0,
      'paymentTypeBreakdown': {
        'cash': {
          'count': cashBillCount,
          'value': summary.totalCashSales,
          'percentage':
              summary.totalSalesValue > 0
                  ? (summary.totalCashSales / summary.totalSalesValue) * 100
                  : 0,
        },
        'credit': {
          'count': creditBillCount,
          'value': summary.totalCreditSales,
          'percentage':
              summary.totalSalesValue > 0
                  ? (summary.totalCreditSales / summary.totalSalesValue) * 100
                  : 0,
        },
        'cheque': {
          'count': chequeBillCount,
          'value': summary.totalChequeSales,
          'percentage':
              summary.totalSalesValue > 0
                  ? (summary.totalChequeSales / summary.totalSalesValue) * 100
                  : 0,
        },
      },
    };
  }

  // HELPER: Generate inventory analytics data locally
  Map<String, dynamic> _generateInventoryAnalyticsData(
    UnloadingSummary summary,
  ) {
    int totalProductsSold = 0;
    int totalProductsRemaining = 0;
    double totalSoldQuantity = 0;
    double totalRemainingQuantity = 0;

    for (final item in summary.itemsSold) {
      totalProductsSold++;
      totalSoldQuantity += (item['quantitySold'] ?? 0).toDouble();
    }

    for (final item in summary.remainingStock) {
      totalProductsRemaining++;
      totalRemainingQuantity += (item['remainingQuantity'] ?? 0).toDouble();
    }

    return {
      'totalProducts': totalProductsSold,
      'productsSold': totalProductsSold,
      'productsWithRemaining': totalProductsRemaining,
      'totalSoldQuantity': totalSoldQuantity,
      'totalRemainingQuantity': totalRemainingQuantity,
      'inventoryTurnover':
          summary.totalItemsLoaded > 0
              ? (totalSoldQuantity / summary.totalItemsLoaded) * 100
              : 0.0,
      'stockEfficiency':
          summary.totalItemsLoaded > 0
              ? ((summary.totalItemsLoaded - totalRemainingQuantity) /
                      summary.totalItemsLoaded) *
                  100
              : 0.0,
    };
  }

  // HELPER: Generate product summary data locally
  Map<String, dynamic> _generateProductSummaryData(UnloadingSummary summary) {
    final productSummary = <String, Map<String, dynamic>>{};

    // Combine sold and remaining data for each product
    for (final soldItem in summary.itemsSold) {
      final productCode = soldItem['productCode'] as String;
      productSummary[productCode] = {
        'productCode': productCode,
        'productName': soldItem['productName'],
        'quantitySold': soldItem['quantitySold'] ?? 0,
        'salesValue': soldItem['totalValue'] ?? 0.0,
        'salesCount': soldItem['salesCount'] ?? 0,
        'billNumbers': soldItem['billNumbers'] ?? [],
      };
    }

    // Add remaining stock data
    for (final stockItem in summary.remainingStock) {
      final productCode = stockItem['productCode'] as String;
      if (productSummary.containsKey(productCode)) {
        productSummary[productCode]!.addAll({
          'initialQuantity': stockItem['initialQuantity'] ?? 0,
          'remainingQuantity': stockItem['remainingQuantity'] ?? 0,
          'remainingValue': stockItem['remainingValue'] ?? 0.0,
          'salesPercentage': stockItem['salesPercentage'] ?? 0.0,
          'pricePerKg': stockItem['pricePerKg'] ?? 0.0,
          'bagSize': stockItem['bagSize'] ?? 0.0,
        });
      } else {
        // Product was loaded but not sold
        productSummary[productCode] = {
          'productCode': productCode,
          'productName': stockItem['productName'],
          'quantitySold': 0,
          'salesValue': 0.0,
          'salesCount': 0,
          'billNumbers': [],
          'initialQuantity': stockItem['initialQuantity'] ?? 0,
          'remainingQuantity': stockItem['remainingQuantity'] ?? 0,
          'remainingValue': stockItem['remainingValue'] ?? 0.0,
          'salesPercentage': 0.0,
          'pricePerKg': stockItem['pricePerKg'] ?? 0.0,
          'bagSize': stockItem['bagSize'] ?? 0.0,
        };
      }
    }

    return {
      'products': productSummary.values.toList(),
      'totalProducts': productSummary.length,
      'soldProducts':
          productSummary.values.where((p) => p['quantitySold'] > 0).length,
      'unsoldProducts':
          productSummary.values.where((p) => p['quantitySold'] == 0).length,
    };
  }

  // ENHANCED: Get unloading summaries with detailed analytics
  Future<List<UnloadingSummary>> getEnhancedUnloadingSummaries(
    String ownerId,
    String businessId,
    String salesRepId, {
    int limit = 10,
  }) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'unloading_summaries',
      where: 'owner_id = ? AND business_id = ? AND sales_rep_id = ?',
      whereArgs: [ownerId, businessId, salesRepId],
      orderBy: 'unloading_date DESC',
      limit: limit,
    );

    return maps.map((data) => UnloadingSummary.fromSQLite(data)).toList();
  }

  // NEW: Get bills with enhanced details for unloading
  Future<List<Map<String, dynamic>>> getBillsWithDetailsForDate(
    String ownerId,
    String businessId,
    DateTime date,
  ) async {
    final db = await database;

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final List<Map<String, dynamic>> bills = await db.query(
      'bills',
      where:
          'owner_id = ? AND business_id = ? AND created_at >= ? AND created_at < ?',
      whereArgs: [
        ownerId,
        businessId,
        startOfDay.millisecondsSinceEpoch,
        endOfDay.millisecondsSinceEpoch,
      ],
      orderBy: 'created_at DESC',
    );

    // Enhance each bill with item details
    for (final bill in bills) {
      final billItems = await getBillItems(bill['id']);
      bill['items'] = billItems;
      bill['item_count'] = billItems.length;
      bill['total_quantity'] = billItems.fold(
        0,
        (sum, item) => sum + (item['quantity'] as int),
      );
    }

    return bills;
  }

  // LEGACY: Save unloading summary (for compatibility)
  Future<void> saveUnloadingSummary(Map<String, dynamic> summaryData) async {
    final db = await database;

    await db.insert(
      'unloading_summaries',
      summaryData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // LEGACY: Get unloading summaries (for compatibility)
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

  // Database table verification and creation
  Future<void> ensureBillsTableExists() async {
    final db = await database;

    try {
      // First, ensure loading table has all required columns
      await _ensureLoadingTableColumns(db);

      // Check if bills table exists
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='bills'",
      );

      if (tables.isEmpty) {
        print('Bills table does not exist, creating it...');

        // Create bills table
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
          updated_at INTEGER
        )
      ''');

        // Create indexes
        await db.execute('CREATE INDEX idx_bills_outlet ON bills(outlet_id)');
        await db.execute(
          'CREATE INDEX idx_bills_created_at ON bills(created_at)',
        );
        await db.execute(
          'CREATE INDEX idx_bills_business ON bills(business_id, created_by)',
        );
        await db.execute(
          'CREATE INDEX idx_bills_sync_status ON bills(owner_id, business_id, sync_status)',
        );

        print('Bills table created successfully');
      } else {
        print('Bills table already exists');

        // Check if sync_status column exists
        final columns = await db.rawQuery('PRAGMA table_info(bills)');
        final columnNames = columns.map((col) => col['name']).toList();

        if (!columnNames.contains('sync_status')) {
          try {
            await db.execute(
              'ALTER TABLE bills ADD COLUMN sync_status TEXT DEFAULT "pending"',
            );
            print('Added sync_status column to bills table');
          } catch (e) {
            print('Error adding sync_status column: $e');
          }
        } else {
          print('sync_status column already exists');
        }
      }
    } catch (e) {
      print('Error ensuring bills table exists: $e');
    }
  }

  Future<void> _ensureLoadingTableColumns(Database db) async {
    try {
      // Get current table structure
      final columns = await db.rawQuery('PRAGMA table_info(loadings)');
      final columnNames = columns.map((col) => col['name'] as String).toSet();

      // List of required columns with their types
      final requiredColumns = {
        'total_weight': 'REAL DEFAULT 0.0',
        'paddy_price_date': 'TEXT',
        'today_paddy_prices': 'TEXT',
      };

      // Add missing columns
      for (final entry in requiredColumns.entries) {
        if (!columnNames.contains(entry.key)) {
          try {
            await db.execute(
              'ALTER TABLE loadings ADD COLUMN ${entry.key} ${entry.value}',
            );
            print('Added ${entry.key} column to loadings table');
          } catch (e) {
            print('Error adding ${entry.key} column: $e');
          }
        }
      }

      print('Loading table columns verified');
    } catch (e) {
      print('Error ensuring loading table columns: $e');
    }
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

      // ENHANCED: Clear old unloading summaries
      await txn.delete(
        'unloading_summaries',
        where: 'created_at < ? AND sync_status = ?',
        whereArgs: [cutoffTime, 'synced'],
      );
    });

    print('Cleared old data older than $daysToKeep days');
  }

  // ENHANCED: Get sales analytics for date range
  Future<Map<String, dynamic>> getSalesAnalyticsForDateRange(
    String ownerId,
    String businessId,
    String salesRepId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;

    final List<Map<String, dynamic>> summaries = await db.query(
      'unloading_summaries',
      where:
          'owner_id = ? AND business_id = ? AND sales_rep_id = ? AND unloading_date >= ? AND unloading_date <= ?',
      whereArgs: [
        ownerId,
        businessId,
        salesRepId,
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
      ],
      orderBy: 'unloading_date ASC',
    );

    double totalSales = 0.0;
    double totalCash = 0.0;
    double totalCredit = 0.0;
    double totalCheque = 0.0;
    int totalBills = 0;
    final allBillNumbers = <String>[];

    for (final summary in summaries) {
      totalSales += (summary['total_sales_value'] as double? ?? 0.0);
      totalCash += (summary['total_cash_sales'] as double? ?? 0.0);
      totalCredit += (summary['total_credit_sales'] as double? ?? 0.0);
      totalCheque += (summary['total_cheque_sales'] as double? ?? 0.0);
      totalBills += (summary['total_bill_count'] as int? ?? 0);

      // Extract bill numbers if available
      final billNumbersJson = summary['bill_numbers_json'] as String?;
      if (billNumbersJson != null) {
        try {
          final billNumbers = List<String>.from(jsonDecode(billNumbersJson));
          allBillNumbers.addAll(billNumbers);
        } catch (e) {
          print('Error parsing bill numbers: $e');
        }
      }
    }

    return {
      'period': {
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'days': summaries.length,
      },
      'totals': {
        'sales': totalSales,
        'cash': totalCash,
        'credit': totalCredit,
        'cheque': totalCheque,
        'bills': totalBills,
      },
      'averages': {
        'dailySales':
            summaries.isNotEmpty ? totalSales / summaries.length : 0.0,
        'billValue': totalBills > 0 ? totalSales / totalBills : 0.0,
        'billsPerDay':
            summaries.isNotEmpty ? totalBills / summaries.length : 0.0,
      },
      'breakdown': {
        'cashPercentage': totalSales > 0 ? (totalCash / totalSales) * 100 : 0.0,
        'creditPercentage':
            totalSales > 0 ? (totalCredit / totalSales) * 100 : 0.0,
        'chequePercentage':
            totalSales > 0 ? (totalCheque / totalSales) * 100 : 0.0,
      },
      'billNumbers': allBillNumbers,
      'summaries':
          summaries.map((s) => UnloadingSummary.fromSQLite(s)).toList(),
    };
  }

  // ENHANCED: Get unloading summary by date with bill numbers
  Future<UnloadingSummary?> getUnloadingSummaryByDate(
    String ownerId,
    String businessId,
    String salesRepId,
    DateTime date,
  ) async {
    final db = await database;

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final List<Map<String, dynamic>> maps = await db.query(
      'unloading_summaries',
      where:
          'owner_id = ? AND business_id = ? AND sales_rep_id = ? AND unloading_date >= ? AND unloading_date < ?',
      whereArgs: [
        ownerId,
        businessId,
        salesRepId,
        startOfDay.millisecondsSinceEpoch,
        endOfDay.millisecondsSinceEpoch,
      ],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return UnloadingSummary.fromSQLite(maps.first);
  }

  // ENHANCED: Database health check
  Future<Map<String, dynamic>> getDatabaseHealthStatus() async {
    final db = await database;

    try {
      // Check table existence and record counts
      final bills = await db.rawQuery('SELECT COUNT(*) as count FROM bills');
      final outlets = await db.rawQuery(
        'SELECT COUNT(*) as count FROM outlets',
      );
      final loadings = await db.rawQuery(
        'SELECT COUNT(*) as count FROM loadings',
      );
      final unloadings = await db.rawQuery(
        'SELECT COUNT(*) as count FROM unloading_summaries',
      );
      final syncQueue = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sync_queue',
      );

      // Check pending items
      final pendingBills = await db.rawQuery(
        'SELECT COUNT(*) as count FROM bills WHERE sync_status = "pending"',
      );
      final pendingUnloadings = await db.rawQuery(
        'SELECT COUNT(*) as count FROM unloading_summaries WHERE sync_status = "pending"',
      );

      return {
        'healthy': true,
        'tables': {
          'bills': bills.first['count'],
          'outlets': outlets.first['count'],
          'loadings': loadings.first['count'],
          'unloadings': unloadings.first['count'],
          'syncQueue': syncQueue.first['count'],
        },
        'pending': {
          'bills': pendingBills.first['count'],
          'unloadings': pendingUnloadings.first['count'],
        },
        'version': 5,
        'enhanced': true,
        'checkedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'healthy': false,
        'error': e.toString(),
        'checkedAt': DateTime.now().toIso8601String(),
      };
    }
  }

  // Close database
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  // ENHANCED: Debug method to check table structure
  Future<void> debugTableStructure() async {
    final db = await database;

    final tables = ['bills', 'unloading_summaries', 'loadings', 'outlets'];

    for (final tableName in tables) {
      try {
        final columns = await db.rawQuery('PRAGMA table_info($tableName)');
        print('\n=== $tableName Table Structure ===');
        for (final column in columns) {
          print(
            '${column['name']}: ${column['type']} (${column['notnull'] == 1 ? 'NOT NULL' : 'NULL'})',
          );
        }
      } catch (e) {
        print('Error checking $tableName: $e');
      }
    }
  }
}
