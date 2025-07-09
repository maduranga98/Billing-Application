// lib/providers/billing_provider.dart (Updated with Custom Price Support)
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

  // Loading states
  bool _isLoadingOutlets = false;
  bool _isLoadingItems = false;
  bool _isCreatingBill = false;

  bool get isLoadingOutlets => _isLoadingOutlets;
  bool get isLoadingItems => _isLoadingItems;
  bool get isCreatingBill => _isCreatingBill;

  // Calculate total amount with custom prices
  double get totalAmount {
    return _selectedItems.fold(0.0, (sum, item) => sum + item.totalPrice);
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

  // Add item to bill with default price
  void addItemToBill(LoadingItem item, int quantity) {
    addItemToBillWithPrice(item, quantity, item.pricePerKg);
  }

  // Add item to bill with custom price
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

    final existingIndex = _selectedItems.indexWhere(
      (selectedItem) => selectedItem.productId == item.productId,
    );

    if (existingIndex != -1) {
      // Update existing item with new quantity and price
      _selectedItems[existingIndex] = SelectedBillItem(
        productId: item.productId,
        productName: item.productName,
        productCode: item.productCode,
        quantity: quantity,
        unitPrice: customPrice,
        bagSize: item.bagSize,
        unit: item.unit,
        category: item.category,
        totalPrice:
            quantity *
            item.bagSize *
            customPrice, // quantity * bagSize * pricePerKg
      );
    } else {
      // Add new item
      final selectedItem = SelectedBillItem(
        productId: item.productId,
        productName: item.productName,
        productCode: item.productCode,
        quantity: quantity,
        unitPrice: customPrice,
        bagSize: item.bagSize,
        unit: item.unit,
        category: item.category,
        totalPrice:
            quantity *
            item.bagSize *
            customPrice, // quantity * bagSize * pricePerKg
      );
      _selectedItems.add(selectedItem);
    }

    notifyListeners();
  }

  // Remove item from bill
  void removeItemFromBill(String productId) {
    _selectedItems.removeWhere((item) => item.productId == productId);
    notifyListeners();
  }

  // Update item quantity
  void updateItemQuantity(String productId, int newQuantity) {
    final index = _selectedItems.indexWhere(
      (item) => item.productId == productId,
    );
    if (index != -1) {
      final item = _selectedItems[index];
      if (newQuantity <= 0) {
        removeItemFromBill(productId);
      } else {
        _selectedItems[index] = SelectedBillItem(
          productId: item.productId,
          productName: item.productName,
          productCode: item.productCode,
          quantity: newQuantity,
          unitPrice: item.unitPrice,
          bagSize: item.bagSize,
          unit: item.unit,
          category: item.category,
          totalPrice: newQuantity * item.bagSize * item.unitPrice,
        );
        notifyListeners();
      }
    }
  }

  // Update item price
  void updateItemPrice(String productId, double newPrice) {
    final index = _selectedItems.indexWhere(
      (item) => item.productId == productId,
    );
    if (index != -1) {
      final item = _selectedItems[index];

      // Get the LoadingItem to validate price range
      final loadingItem = _availableItems.firstWhere(
        (availableItem) => availableItem.productId == productId,
      );

      // Validate price is within range
      if (newPrice < loadingItem.minPrice || newPrice > loadingItem.maxPrice) {
        throw Exception(
          'Price must be between Rs.${loadingItem.minPrice} and Rs.${loadingItem.maxPrice}',
        );
      }

      _selectedItems[index] = SelectedBillItem(
        productId: item.productId,
        productName: item.productName,
        productCode: item.productCode,
        quantity: item.quantity,
        unitPrice: newPrice,
        bagSize: item.bagSize,
        unit: item.unit,
        category: item.category,
        totalPrice: item.quantity * item.bagSize * newPrice,
      );
      notifyListeners();
    }
  }

  // Check if item is selected
  bool isItemSelected(String productId) {
    return _selectedItems.any((item) => item.productId == productId);
  }

  // Get selected quantity for an item
  int getSelectedQuantity(String productId) {
    final item = _selectedItems.firstWhere(
      (item) => item.productId == productId,
      orElse:
          () => SelectedBillItem(
            productId: '',
            productName: '',
            productCode: '',
            quantity: 0,
            unitPrice: 0.0,
            bagSize: 0.0,
            unit: '',
            category: '',
            totalPrice: 0.0,
          ),
    );
    return item.quantity;
  }

  // Get selected item
  SelectedBillItem? getSelectedItem(String productId) {
    try {
      return _selectedItems.firstWhere((item) => item.productId == productId);
    } catch (e) {
      return null;
    }
  }

  // Get selected price for an item
  double getSelectedPrice(String productId) {
    final item = getSelectedItem(productId);
    return item?.unitPrice ?? 0.0;
  }

  // Clear all selected items
  void clearBill() {
    _selectedItems.clear();
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

    // Validate quantities against available stock
    for (final selectedItem in _selectedItems) {
      final availableItem = _availableItems.firstWhere(
        (item) => item.productId == selectedItem.productId,
      );

      if (selectedItem.quantity > availableItem.availableQuantity) {
        return {
          'isValid': false,
          'error':
              'Insufficient quantity for ${selectedItem.productName}. Available: ${availableItem.availableQuantity}, Required: ${selectedItem.quantity}',
        };
      }

      // Validate price is still within range
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

  // Get bill summary
  Map<String, dynamic> getBillSummary() {
    return {
      'itemCount': _selectedItems.length,
      'totalQuantity': _selectedItems.fold<int>(
        0,
        (sum, item) => sum + item.quantity,
      ),
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

  // Helper method to create an empty SelectedBillItem for orElse cases
  SelectedBillItem _createEmptySelectedBillItem() {
    return SelectedBillItem(
      productId: '',
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
