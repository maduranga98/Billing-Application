// lib/providers/enhanced_billing_provider.dart
import 'package:flutter/foundation.dart';
import '../models/loading_item.dart';
import '../models/selected_bill_item.dart';
import '../models/outlet.dart';
import '../models/user_session.dart';
import '../services/outlet/outlet_service.dart';
import '../services/loading/loading_service.dart';

class BillingProvider extends ChangeNotifier {
  List<LoadingItem> _availableItems = [];
  List<SelectedBillItem> _selectedItems = [];
  Outlet? _selectedOutlet;
  String _paymentType = 'cash';
  double _discountPercentage = 0.0;
  double _taxPercentage = 0.0;
  String _notes = '';
  double _loadingCost = 0.0;

  // Loading states - ADDED for compatibility
  bool _isLoadingOutlets = false;
  bool _isLoadingItems = false;
  List<Outlet> _availableOutlets = [];

  // Getters
  List<LoadingItem> get availableItems => _availableItems;
  List<SelectedBillItem> get selectedItems => _selectedItems;
  Outlet? get selectedOutlet => _selectedOutlet;
  String get paymentType => _paymentType;
  double get discountPercentage => _discountPercentage;
  double get taxPercentage => _taxPercentage;
  String get notes => _notes;
  double get loadingCost => _loadingCost;

  // ADDED: Compatibility getters for existing screens
  List<Outlet> get availableOutlets => _availableOutlets;
  bool get isLoadingOutlets => _isLoadingOutlets;
  bool get isLoadingItems => _isLoadingItems;

  // Calculated values - FIXED: Updated to include loading cost properly
  double get subtotal =>
      _selectedItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get subtotalAmount => subtotal; // Alias for compatibility
  double get discountAmount => subtotal * (_discountPercentage / 100);
  double get taxableAmount => subtotal - discountAmount;
  double get taxAmount => taxableAmount * (_taxPercentage / 100);
  double get totalAmount =>
      taxableAmount + taxAmount + _loadingCost; // FIXED: Include loading cost

  int get totalItemCount =>
      _selectedItems.fold(0, (sum, item) => sum + item.quantity);
  double get totalWeight => _selectedItems.fold(
    0.0,
    (sum, item) => sum + (item.quantity * item.bagSize),
  );

  bool get hasItems => _selectedItems.isNotEmpty;
  bool get canCreateBill => hasItems && _selectedOutlet != null;

  // ADDED: Initialize billing process (for compatibility)
  Future<void> initializeBilling(UserSession session) async {
    await loadAvailableOutlets(session);
    await loadAvailableItems(session);
  }

  // ADDED: Load available outlets
  Future<void> loadAvailableOutlets(UserSession session) async {
    _isLoadingOutlets = true;
    notifyListeners();

    try {
      _availableOutlets = await OutletService.getOutlets(session);
    } catch (e) {
      print('Error loading outlets: $e');
      _availableOutlets = [];
    } finally {
      _isLoadingOutlets = false;
      notifyListeners();
    }
  }

  // Load available items from list
  void setAvailableItems(List<LoadingItem> items) {
    _availableItems = items;
    notifyListeners();
  }

  // ADDED: Load available items from service (for compatibility)
  Future<void> loadAvailableItems(UserSession session) async {
    _isLoadingItems = true;
    notifyListeners();

    try {
      _availableItems = await LoadingService.getAvailableItems(session);
    } catch (e) {
      print('Error loading items: $e');
      _availableItems = [];
    } finally {
      _isLoadingItems = false;
      notifyListeners();
    }
  }

  // Set selected outlet
  void setSelectedOutlet(Outlet? outlet) {
    _selectedOutlet = outlet;
    notifyListeners();
  }

  // ADDED: Select outlet (alias for compatibility)
  void selectOutlet(Outlet outlet) {
    setSelectedOutlet(outlet);
  }

  // Set payment details
  void setPaymentType(String type) {
    _paymentType = type;
    notifyListeners();
  }

  void setDiscountPercentage(double percentage) {
    _discountPercentage = percentage.clamp(0.0, 100.0);
    notifyListeners();
  }

  void setTaxPercentage(double percentage) {
    _taxPercentage = percentage.clamp(0.0, 100.0);
    notifyListeners();
  }

  void setNotes(String notes) {
    _notes = notes;
    notifyListeners();
  }

  void setLoadingCost(double cost) {
    _loadingCost = cost >= 0 ? cost : 0.0;
    notifyListeners();
  }

  // ADDED: Check if item is selected (for compatibility)
  bool isItemSelected(String productId) {
    return _selectedItems.any((item) => item.originalProductId == productId);
  }

  // ADDED: Get selected item by product ID (for compatibility)
  SelectedBillItem? getSelectedItem(String productId) {
    try {
      return _selectedItems.firstWhere(
        (item) => item.originalProductId == productId,
      );
    } catch (e) {
      return null;
    }
  }

  // Add item to bill - ALLOWS MULTIPLE ENTRIES OF SAME PRODUCT
  String addItemToBill({
    required LoadingItem item,
    required int quantity,
    double? customPrice,
  }) {
    // Validate quantity
    if (quantity <= 0) {
      throw Exception('Quantity must be greater than 0');
    }

    if (quantity > item.availableQuantity) {
      throw Exception(
        'Insufficient stock. Available: ${item.availableQuantity} bags',
      );
    }

    // Use custom price or default price
    final price = customPrice ?? item.pricePerKg;

    // Validate price is within range
    if (price < item.minPrice || price > item.maxPrice) {
      throw Exception(
        'Price must be between Rs.${item.minPrice.toStringAsFixed(2)} and Rs.${item.maxPrice.toStringAsFixed(2)}',
      );
    }

    // Generate unique ID for this bill item
    final uniqueId =
        '${item.productCode}_${DateTime.now().millisecondsSinceEpoch}_${_selectedItems.length}';

    // Create new selected item
    final selectedItem = SelectedBillItem(
      productId: uniqueId,
      originalProductId: item.productCode,
      productName: item.productName,
      productCode: item.productCode,
      quantity: quantity,
      unitPrice: price,
      bagSize: item.bagSize,
      unit: item.unit,
      category: item.category,
      totalPrice: quantity * item.bagSize * price,
    );

    _selectedItems.add(selectedItem);
    notifyListeners();

    return uniqueId; // Return the unique ID for reference
  }

  // ADDED: Add item with price (for compatibility)
  void addItemToBillWithPrice(
    LoadingItem item,
    int quantity,
    double customPrice,
  ) {
    // Check if item already exists and update, or add new
    final existingIndex = _selectedItems.indexWhere(
      (selectedItem) => selectedItem.originalProductId == item.productCode,
    );

    if (existingIndex != -1) {
      // Update existing item
      final existingItem = _selectedItems[existingIndex];
      _selectedItems[existingIndex] = existingItem.copyWith(
        quantity: quantity,
        unitPrice: customPrice,
        totalPrice: quantity * item.bagSize * customPrice,
      );
    } else {
      // Add new item
      addItemToBill(item: item, quantity: quantity, customPrice: customPrice);
    }
    notifyListeners();
  }

  // Remove item from bill
  void removeItemFromBill(String uniqueId) {
    _selectedItems.removeWhere((item) => item.productId == uniqueId);
    notifyListeners();
  }

  // ADDED: Remove item by product ID (for compatibility)
  void removeItemFromBillByProductId(String productId) {
    _selectedItems.removeWhere((item) => item.originalProductId == productId);
    notifyListeners();
  }

  // Update item quantity
  void updateItemQuantity(String uniqueId, int newQuantity) {
    final index = _selectedItems.indexWhere(
      (item) => item.productId == uniqueId,
    );

    if (index == -1) return;

    if (newQuantity <= 0) {
      removeItemFromBill(uniqueId);
      return;
    }

    final item = _selectedItems[index];

    // Find the original loading item to check stock availability
    final loadingItem = _availableItems.firstWhere(
      (li) => li.productCode == item.originalProductId,
      orElse: () => throw Exception('Original product not found'),
    );

    // Calculate total quantity of this product already in bill (excluding current item)
    final otherQuantities = _selectedItems
        .where(
          (si) =>
              si.originalProductId == item.originalProductId &&
              si.productId != uniqueId,
        )
        .fold(0, (sum, si) => sum + si.quantity);

    // Check if new quantity would exceed available stock
    if (newQuantity + otherQuantities > loadingItem.availableQuantity) {
      throw Exception(
        'Insufficient stock. Available: ${loadingItem.availableQuantity}, Already selected: $otherQuantities',
      );
    }

    // Update the item
    _selectedItems[index] = item.copyWith(
      quantity: newQuantity,
      totalPrice: newQuantity * item.bagSize * item.unitPrice,
    );

    notifyListeners();
  }

  // Update item price
  void updateItemPrice(String uniqueId, double newPrice) {
    final index = _selectedItems.indexWhere(
      (item) => item.productId == uniqueId,
    );

    if (index == -1) return;

    final item = _selectedItems[index];

    // Find the original loading item to validate price range
    final loadingItem = _availableItems.firstWhere(
      (li) => li.productCode == item.originalProductId,
      orElse: () => throw Exception('Original product not found'),
    );

    // Validate price range
    if (newPrice < loadingItem.minPrice || newPrice > loadingItem.maxPrice) {
      throw Exception(
        'Price must be between Rs.${loadingItem.minPrice.toStringAsFixed(2)} and Rs.${loadingItem.maxPrice.toStringAsFixed(2)}',
      );
    }

    // Update the item
    _selectedItems[index] = item.copyWith(
      unitPrice: newPrice,
      totalPrice: item.quantity * item.bagSize * newPrice,
    );

    notifyListeners();
  }

  // Get available quantity for a specific product (considering already selected quantities)
  int getAvailableQuantityForProduct(String productCode) {
    final loadingItem = _availableItems.firstWhere(
      (item) => item.productCode == productCode,
      orElse:
          () => LoadingItem(
            bagQuantity: 0,
            bagSize: 0,
            bagsCount: 0,
            bagsUsed: [],
            displayName: '',
            itemName: '',
            maxPrice: 0,
            minPrice: 0,
            pricePerKg: 0,
            productCode: '',
            productType: '',
            totalValue: 0,
            totalWeight: 0,
          ),
    );

    // Calculate already selected quantity for this product
    final selectedQuantity = _selectedItems
        .where((item) => item.originalProductId == productCode)
        .fold(0, (sum, item) => sum + item.quantity);

    return loadingItem.availableQuantity - selectedQuantity;
  }

  // Get selected quantity for a specific product
  int getSelectedQuantityForProduct(String productCode) {
    return _selectedItems
        .where((item) => item.originalProductId == productCode)
        .fold(0, (sum, item) => sum + item.quantity);
  }

  // Get all selected items for a specific product code
  List<SelectedBillItem> getSelectedItemsForProduct(String productCode) {
    return _selectedItems
        .where((item) => item.originalProductId == productCode)
        .toList();
  }

  // Check if product can be added to bill
  bool canAddProduct(String productCode, int quantity) {
    return getAvailableQuantityForProduct(productCode) >= quantity;
  }

  // Clear all selected items
  void clearBill() {
    _selectedItems.clear();
    _selectedOutlet = null;
    _paymentType = 'cash';
    _discountPercentage = 0.0;
    _taxPercentage = 0.0;
    _notes = '';
    _loadingCost = 0.0; // FIXED: Also clear loading cost
    notifyListeners();
  }

  // Reset billing (alias for clearBill for compatibility)
  void resetBilling() {
    clearBill();
  }

  // Get bill summary
  Map<String, dynamic> getBillSummary() {
    final groupedItems = <String, List<SelectedBillItem>>{};

    // Group items by product code
    for (final item in _selectedItems) {
      if (!groupedItems.containsKey(item.originalProductId)) {
        groupedItems[item.originalProductId] = [];
      }
      groupedItems[item.originalProductId]!.add(item);
    }

    return {
      'selectedItems': _selectedItems,
      'groupedItems': groupedItems,
      'subtotal': subtotal,
      'discountAmount': discountAmount,
      'taxAmount': taxAmount,
      'loadingCost': _loadingCost, // FIXED: Include loading cost in summary
      'totalAmount': totalAmount,
      'totalItemCount': totalItemCount,
      'totalWeight': totalWeight,
      'outlet': _selectedOutlet?.toMap(),
      'paymentType': _paymentType,
      'notes': _notes,
    };
  }

  // Validate bill before creation - FIXED: Return Map instead of String
  Map<String, dynamic> validateBill() {
    if (_selectedOutlet == null) {
      return {'isValid': false, 'error': 'Please select an outlet'};
    }

    if (_selectedItems.isEmpty) {
      return {'isValid': false, 'error': 'Please add items to the bill'};
    }

    if (_paymentType.isEmpty) {
      return {'isValid': false, 'error': 'Please select payment type'};
    }

    // Check stock availability for all items
    for (final item in _selectedItems) {
      final availableQty = getAvailableQuantityForProduct(
        item.originalProductId,
      );
      final selectedQty = getSelectedQuantityForProduct(item.originalProductId);

      if (selectedQty > availableQty + item.quantity) {
        return {
          'isValid': false,
          'error': 'Insufficient stock for ${item.productName}',
        };
      }
    }

    return {'isValid': true, 'error': null}; // No validation errors
  }

  // Duplicate a selected item (useful for adding same product with different price/quantity)
  String duplicateSelectedItem(String uniqueId) {
    final originalItem = _selectedItems.firstWhere(
      (item) => item.productId == uniqueId,
      orElse: () => throw Exception('Item not found'),
    );

    // Find the loading item to validate
    final loadingItem = _availableItems.firstWhere(
      (item) => item.productCode == originalItem.originalProductId,
      orElse: () => throw Exception('Original product not found'),
    );

    return addItemToBill(
      item: loadingItem,
      quantity: originalItem.quantity,
      customPrice: originalItem.unitPrice,
    );
  }

  // Sort selected items by various criteria
  void sortSelectedItems(String criteria) {
    switch (criteria) {
      case 'name':
        _selectedItems.sort((a, b) => a.productName.compareTo(b.productName));
        break;
      case 'price':
        _selectedItems.sort((a, b) => b.totalPrice.compareTo(a.totalPrice));
        break;
      case 'quantity':
        _selectedItems.sort((a, b) => b.quantity.compareTo(a.quantity));
        break;
      case 'category':
        _selectedItems.sort((a, b) => a.category.compareTo(b.category));
        break;
      default:
        // Keep original order
        break;
    }
    notifyListeners();
  }

  // Search available items
  List<LoadingItem> searchAvailableItems(String query) {
    if (query.isEmpty) return _availableItems;

    final lowercaseQuery = query.toLowerCase();
    return _availableItems.where((item) {
      return item.productName.toLowerCase().contains(lowercaseQuery) ||
          item.productCode.toLowerCase().contains(lowercaseQuery) ||
          item.category.toLowerCase().contains(lowercaseQuery) ||
          (item.riceType?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();
  }

  // Filter available items by category
  List<LoadingItem> filterItemsByCategory(String category) {
    if (category.isEmpty || category == 'all') return _availableItems;
    return _availableItems.where((item) => item.category == category).toList();
  }

  // Get all unique categories
  List<String> getAvailableCategories() {
    final categories =
        _availableItems.map((item) => item.category).toSet().toList();
    categories.sort();
    return categories;
  }

  // Additional utility methods for better integration

  // Select outlet by ID
  void selectOutletById(String outletId, List<Outlet> availableOutlets) {
    try {
      final outlet = availableOutlets.firstWhere((o) => o.id == outletId);
      setSelectedOutlet(outlet);
    } catch (e) {
      throw Exception('Outlet not found');
    }
  }

  // Add multiple items at once
  List<String> addMultipleItemsToBill(List<Map<String, dynamic>> itemsData) {
    final addedIds = <String>[];

    for (final itemData in itemsData) {
      try {
        final item = itemData['item'] as LoadingItem;
        final quantity = itemData['quantity'] as int;
        final customPrice = itemData['customPrice'] as double?;

        final id = addItemToBill(
          item: item,
          quantity: quantity,
          customPrice: customPrice,
        );
        addedIds.add(id);
      } catch (e) {
        // Log error but continue with other items
        print('Failed to add item: $e');
      }
    }

    return addedIds;
  }

  // Get items by category from selected items
  Map<String, List<SelectedBillItem>> getSelectedItemsByCategory() {
    final categorizedItems = <String, List<SelectedBillItem>>{};

    for (final item in _selectedItems) {
      if (!categorizedItems.containsKey(item.category)) {
        categorizedItems[item.category] = [];
      }
      categorizedItems[item.category]!.add(item);
    }

    return categorizedItems;
  }

  // Calculate total for specific category
  double getTotalForCategory(String category) {
    return _selectedItems
        .where((item) => item.category == category)
        .fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  // Get bill statistics
  Map<String, dynamic> getBillStatistics() {
    final stats = <String, dynamic>{
      'itemCount': _selectedItems.length,
      'uniqueProducts':
          _selectedItems.map((item) => item.originalProductId).toSet().length,
      'totalQuantity': totalItemCount,
      'totalWeight': totalWeight,
      'averageItemPrice':
          _selectedItems.isNotEmpty ? subtotal / _selectedItems.length : 0.0,
      'heaviestItem':
          _selectedItems.isNotEmpty
              ? _selectedItems.reduce(
                (a, b) =>
                    (a.quantity * a.bagSize) > (b.quantity * b.bagSize) ? a : b,
              )
              : null,
      'mostExpensiveItem':
          _selectedItems.isNotEmpty
              ? _selectedItems.reduce(
                (a, b) => a.totalPrice > b.totalPrice ? a : b,
              )
              : null,
    };

    return stats;
  }
}
