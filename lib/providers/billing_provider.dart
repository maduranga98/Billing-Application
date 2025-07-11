// lib/providers/billing_provider.dart (Updated with Loading Cost and Duplicate Items Support)
import 'package:flutter/material.dart';
import 'package:lumorabiz_billing/services/outlet/outlet_service.dart';

import '../models/outlet.dart';
import '../models/loading_item.dart';
import '../models/selected_bill_item.dart';
import '../models/user_session.dart';

import '../services/loading/loading_service.dart';

class BillingProvider extends ChangeNotifier {
  // Selected outlet for billing
  Outlet? _selectedOutlet;
  Outlet? get selectedOutlet => _selectedOutlet;

  // Available outlets for selection
  List<Outlet> _availableOutlets = [];
  List<Outlet> get availableOutlets => _availableOutlets;

  // Available items for billing
  List<LoadingItem> _availableItems = [];
  List<LoadingItem> get availableItems => _availableItems;

  // Selected items for the current bill
  List<SelectedBillItem> _selectedItems = [];
  List<SelectedBillItem> get selectedItems => _selectedItems;

  // Loading cost for the bill
  double _loadingCost = 0.0;
  double get loadingCost => _loadingCost;

  // Loading states
  bool _isLoadingOutlets = false;
  bool _isLoadingItems = false;
  bool _isCreatingBill = false;

  bool get isLoadingOutlets => _isLoadingOutlets;
  bool get isLoadingItems => _isLoadingItems;
  bool get isCreatingBill => _isCreatingBill;

  // Calculate subtotal (items only)
  double get subtotalAmount {
    return _selectedItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  // Calculate total amount including loading cost
  double get totalAmount {
    return subtotalAmount + _loadingCost;
  }

  // Initialize billing process
  Future<void> initializeBilling(UserSession session) async {
    await loadAvailableOutlets(session);
    await loadAvailableItems(session);
  }

  // Load available outlets
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

  // Load available items from today's loading
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

  // Select outlet for billing
  void selectOutlet(Outlet outlet) {
    _selectedOutlet = outlet;
    notifyListeners();
  }

  // Set loading cost
  void setLoadingCost(double cost) {
    _loadingCost = cost >= 0 ? cost : 0.0;
    notifyListeners();
  }

  // Add item to bill with default price
  void addItemToBill(LoadingItem item, int quantity) {
    addItemToBillWithPrice(item, quantity, item.pricePerKg);
  }

  // Add item to bill with custom price - UPDATED to allow duplicates
  void addItemToBillWithPrice(
    LoadingItem item,
    int quantity,
    double customPrice,
  ) {
    // Validate price is within range
    if (customPrice < item.minPrice || customPrice > item.maxPrice) {
      throw Exception(
        'Price must be between Rs.${item.minPrice} and Rs.${item.maxPrice}',
      );
    }

    // Validate quantity
    if (quantity <= 0 || quantity > item.availableQuantity) {
      throw Exception('Invalid quantity');
    }

    // CHANGED: Always add as new item, even if same product code exists
    // Generate unique ID for the selected item
    final uniqueId =
        '${item.productId}_${DateTime.now().millisecondsSinceEpoch}';

    final selectedItem = SelectedBillItem(
      productId: uniqueId, // Use unique ID instead of item.productId
      originalProductId: item.productId, // Keep original for reference
      productName: item.productName,
      productCode: item.productCode,
      quantity: quantity,
      unitPrice: customPrice,
      bagSize: item.bagSize,
      unit: item.unit,
      category: item.category,
      totalPrice: quantity * item.bagSize * customPrice,
    );

    _selectedItems.add(selectedItem);
    notifyListeners();
  }

  // Remove item from bill using unique ID
  void removeItemFromBill(String uniqueId) {
    _selectedItems.removeWhere((item) => item.productId == uniqueId);
    notifyListeners();
  }

  // Update item quantity using unique ID
  void updateItemQuantity(String uniqueId, int newQuantity) {
    final index = _selectedItems.indexWhere(
      (item) => item.productId == uniqueId,
    );
    if (index != -1) {
      final item = _selectedItems[index];
      if (newQuantity <= 0) {
        removeItemFromBill(uniqueId);
      } else {
        _selectedItems[index] = item.copyWith(
          quantity: newQuantity,
          totalPrice: newQuantity * item.bagSize * item.unitPrice,
        );
        notifyListeners();
      }
    }
  }

  // Update item price using unique ID
  void updateItemPrice(String uniqueId, double newPrice) {
    final index = _selectedItems.indexWhere(
      (item) => item.productId == uniqueId,
    );
    if (index != -1) {
      final item = _selectedItems[index];

      // Get the LoadingItem to validate price range using originalProductId
      final loadingItem = _availableItems.firstWhere(
        (availableItem) => availableItem.productId == item.originalProductId,
      );

      // Validate price is within range
      if (newPrice < loadingItem.minPrice || newPrice > loadingItem.maxPrice) {
        throw Exception(
          'Price must be between Rs.${loadingItem.minPrice} and Rs.${loadingItem.maxPrice}',
        );
      }

      _selectedItems[index] = item.copyWith(
        unitPrice: newPrice,
        totalPrice: item.quantity * item.bagSize * newPrice,
      );
      notifyListeners();
    }
  }

  // Check if item is selected (by original product ID)
  bool isItemSelected(String originalProductId) {
    return _selectedItems.any(
      (item) => item.originalProductId == originalProductId,
    );
  }

  // Get total selected quantity for an item (sum of all instances)
  int getTotalSelectedQuantity(String originalProductId) {
    return _selectedItems
        .where((item) => item.originalProductId == originalProductId)
        .fold(0, (sum, item) => sum + item.quantity);
  }

  // Get all selected instances of an item
  List<SelectedBillItem> getSelectedInstances(String originalProductId) {
    return _selectedItems
        .where((item) => item.originalProductId == originalProductId)
        .toList();
  }

  // Get selected item by unique ID
  SelectedBillItem? getSelectedItem(String uniqueId) {
    try {
      return _selectedItems.firstWhere((item) => item.productId == uniqueId);
    } catch (e) {
      return null;
    }
  }

  // Clear all selected items
  void clearBill() {
    _selectedItems.clear();
    _loadingCost = 0.0;
    notifyListeners();
  }

  // Clear outlet selection
  void clearOutletSelection() {
    _selectedOutlet = null;
    notifyListeners();
  }

  // Reset billing process
  void resetBilling() {
    _selectedOutlet = null;
    _selectedItems.clear();
    _loadingCost = 0.0;
    notifyListeners();
  }

  // Validate if bill can be created
  Map<String, dynamic> validateBill() {
    if (_selectedOutlet == null) {
      return {'isValid': false, 'error': 'Please select an outlet'};
    }

    if (_selectedItems.isEmpty) {
      return {'isValid': false, 'error': 'Please add items to the bill'};
    }

    // Validate quantities against available stock (sum by original product ID)
    final groupedItems = <String, int>{};
    for (final selectedItem in _selectedItems) {
      final originalProductId = selectedItem.originalProductId;
      groupedItems[originalProductId] =
          (groupedItems[originalProductId] ?? 0) + selectedItem.quantity;
    }

    for (final entry in groupedItems.entries) {
      final originalProductId = entry.key;
      final totalQuantity = entry.value;

      final availableItem = _availableItems.firstWhere(
        (item) => item.productId == originalProductId,
        orElse: () => throw Exception('Item not found: $originalProductId'),
      );

      if (totalQuantity > availableItem.availableQuantity) {
        return {
          'isValid': false,
          'error':
              'Insufficient quantity for ${availableItem.productName}. Available: ${availableItem.availableQuantity}, Required: $totalQuantity',
        };
      }
    }

    // Validate prices are still within range
    for (final selectedItem in _selectedItems) {
      final availableItem = _availableItems.firstWhere(
        (item) => item.productId == selectedItem.originalProductId,
      );

      if (selectedItem.unitPrice < availableItem.minPrice ||
          selectedItem.unitPrice > availableItem.maxPrice) {
        return {
          'isValid': false,
          'error':
              'Invalid price for ${selectedItem.productName}. Price must be between Rs.${availableItem.minPrice.toStringAsFixed(2)} and Rs.${availableItem.maxPrice.toStringAsFixed(2)}',
        };
      }
    }

    return {'isValid': true};
  }

  // Get bill summary with loading cost
  Map<String, dynamic> getBillSummary() {
    return {
      'itemCount': _selectedItems.length,
      'totalQuantity': _selectedItems.fold<int>(
        0,
        (sum, item) => sum + item.quantity,
      ),
      'subtotalAmount': subtotalAmount,
      'loadingCost': _loadingCost,
      'totalAmount': totalAmount,
      'outlet': _selectedOutlet?.outletName ?? 'No outlet selected',
    };
  }

  // Get items by category for display
  Map<String, List<SelectedBillItem>> get itemsByCategory {
    final Map<String, List<SelectedBillItem>> categorizedItems = {};

    for (final item in _selectedItems) {
      final category = item.category.isEmpty ? 'Uncategorized' : item.category;
      if (!categorizedItems.containsKey(category)) {
        categorizedItems[category] = [];
      }
      categorizedItems[category]!.add(item);
    }

    return categorizedItems;
  }

  // Get items grouped by product code (for display purposes)
  Map<String, List<SelectedBillItem>> get itemsByProductCode {
    final Map<String, List<SelectedBillItem>> groupedItems = {};

    for (final item in _selectedItems) {
      final productCode = item.productCode;
      if (!groupedItems.containsKey(productCode)) {
        groupedItems[productCode] = [];
      }
      groupedItems[productCode]!.add(item);
    }

    return groupedItems;
  }

  // Helper method to create an empty SelectedBillItem for orElse cases
  SelectedBillItem _createEmptySelectedBillItem() {
    return SelectedBillItem(
      productId: '',
      originalProductId: '',
      productName: '',
      productCode: '',
      quantity: 0,
      unitPrice: 0.0,
      bagSize: 0.0,
      unit: '',
      category: '',
      totalPrice: 0.0,
    );
  }
}
