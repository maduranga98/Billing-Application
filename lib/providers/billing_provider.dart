// lib/providers/billing_provider.dart
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

  // Calculate total amount
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

  // Add item to bill
  void addItemToBill(LoadingItem item, int quantity) {
    final existingIndex = _selectedItems.indexWhere(
      (selectedItem) => selectedItem.productId == item.productId,
    );

    if (existingIndex != -1) {
      // Update existing item quantity
      _selectedItems[existingIndex].quantity += quantity;
    } else {
      // Add new item
      _selectedItems.add(
        SelectedBillItem(
          productId: item.productId,
          productName: item.productName,
          productCode: item.productCode,
          unitPrice: item.unitPrice,
          quantity: quantity,
          unit: item.unit,
          category: item.category,
        ),
      );
    }
    notifyListeners();
  }

  // Update item quantity
  void updateItemQuantity(String productId, int newQuantity) {
    final index = _selectedItems.indexWhere(
      (item) => item.productId == productId,
    );

    if (index != -1) {
      if (newQuantity <= 0) {
        _selectedItems.removeAt(index);
      } else {
        _selectedItems[index].quantity = newQuantity;
      }
      notifyListeners();
    }
  }

  // Remove item from bill
  void removeItemFromBill(String productId) {
    _selectedItems.removeWhere((item) => item.productId == productId);
    notifyListeners();
  }

  // Clear all selections
  void clearBill() {
    _selectedOutlet = null;
    _selectedItems.clear();
    notifyListeners();
  }

  // Get selected item by product ID
  SelectedBillItem? getSelectedItem(String productId) {
    try {
      return _selectedItems.firstWhere((item) => item.productId == productId);
    } catch (e) {
      return null;
    }
  }

  // Check if item is selected
  bool isItemSelected(String productId) {
    return _selectedItems.any((item) => item.productId == productId);
  }

  // Get selected quantity for item
  int getSelectedQuantity(String productId) {
    final selectedItem = getSelectedItem(productId);
    return selectedItem?.quantity ?? 0;
  }

  // Validate bill before creation
  Map<String, dynamic> validateBill() {
    if (_selectedOutlet == null) {
      return {'isValid': false, 'error': 'Please select an outlet'};
    }

    if (_selectedItems.isEmpty) {
      return {
        'isValid': false,
        'error': 'Please add at least one item to the bill',
      };
    }

    // Check if sufficient quantities are available
    for (final selectedItem in _selectedItems) {
      final availableItem = _availableItems.firstWhere(
        (item) => item.productId == selectedItem.productId,
        orElse: () => _createEmptyLoadingItem(),
      );

      if (availableItem.productId.isEmpty) {
        return {
          'isValid': false,
          'error': 'Item ${selectedItem.productName} is no longer available',
        };
      }

      if (availableItem.availableQuantity < selectedItem.quantity) {
        return {
          'isValid': false,
          'error':
              'Insufficient quantity for ${selectedItem.productName}. Available: ${availableItem.availableQuantity}, Required: ${selectedItem.quantity}',
        };
      }
    }

    return {'isValid': true};
  }

  // Helper method to create an empty LoadingItem with all required parameters
  LoadingItem _createEmptyLoadingItem() {
    // Create a map with all the required parameters for your LoadingItem constructor
    final emptyItemData = {
      'productId': '',
      'productName': '',
      'productCode': '',
      'unitPrice': 0.0,
      'loadedQuantity': 0,
      'soldQuantity': 0,
      'totalWeight': 0.0,
      'unit': '',
      'category': '',
      // Add any additional required parameters with default values
      'bagQuantity': 0,
      'bagSize': '',
      'bagsCount': 0,
      'bagsUsed': 0,
      'displayName': '',
      'productType': '',
      'totalValue': 0.0,
    };

    // Use the fromMap factory constructor to create the LoadingItem
    return LoadingItem.fromMap(emptyItemData);
  }
}
