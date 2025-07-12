// // lib/widgets/printing/bill_receipt_widget.dart
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import '../../models/print_bill.dart';
// import '../../services/printing/bill_printer_service.dart';

// class BillReceiptWidget extends StatefulWidget {
//   final PrintBill bill;
//   final VoidCallback? onPrintReady;

//   const BillReceiptWidget({super.key, required this.bill, this.onPrintReady});

//   @override
//   State<BillReceiptWidget> createState() => _BillReceiptWidgetState();
// }

// class _BillReceiptWidgetState extends State<BillReceiptWidget> {
//   @override
//   void initState() {
//     super.initState();
//     // Initialize the print service
//     BillPrinterService.initialize();
//     // Notify parent that printing is ready
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       widget.onPrintReady?.call();
//     });
//   }

//   Widget _buildTableRow({
//     required String col1,
//     required String col2,
//     required String col3,
//     required String col4,
//     required String col5,
//     bool isHeader = false,
//     bool isBold = false,
//   }) {
//     final textStyle = TextStyle(
//       fontSize: isHeader ? 16 : 14,
//       fontWeight: isBold || isHeader ? FontWeight.bold : FontWeight.normal,
//     );

//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 2),
//       child: Row(
//         children: [
//           // # (Item Number)
//           SizedBox(
//             width: 40,
//             child: Text(col1, style: textStyle, textAlign: TextAlign.center),
//           ),
//           // Item Name (takes most space)
//           Expanded(
//             flex: 4,
//             child: Text(
//               col2,
//               style: textStyle,
//               maxLines: isHeader ? 1 : 2,
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//           // Qty
//           SizedBox(
//             width: 50,
//             child: Text(col3, style: textStyle, textAlign: TextAlign.center),
//           ),
//           // Unit Price
//           SizedBox(
//             width: 70,
//             child: Text(col4, style: textStyle, textAlign: TextAlign.right),
//           ),
//           // Total
//           SizedBox(
//             width: 80,
//             child: Text(col5, style: textStyle, textAlign: TextAlign.right),
//           ),
//         ],
//       ),
//     );
//   }

//   // Helper method to build info row with proper spacing
//   Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 1),
//       child: Row(
//         children: [
//           SizedBox(
//             width: 80,
//             child: Text(
//               label,
//               style: TextStyle(
//                 fontSize: 14,
//                 fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
//               ),
//             ),
//           ),
//           Expanded(
//             child: Text(
//               value,
//               style: TextStyle(
//                 fontSize: 14,
//                 fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // Helper method to build customer and sales rep side by side
//   Widget _buildTwoColumnInfo(
//     String leftTitle,
//     String leftContent,
//     String rightTitle,
//     String rightContent,
//   ) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         // Left Column (Customer)
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 leftTitle,
//                 style: const TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 4),
//               Text(
//                 leftContent,
//                 style: const TextStyle(fontSize: 12),
//                 maxLines: 4,
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(width: 16),
//         // Right Column (Sales Rep)
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 rightTitle,
//                 style: const TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 4),
//               Text(
//                 rightContent,
//                 style: const TextStyle(fontSize: 12),
//                 maxLines: 4,
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   // Helper method to build signature section
//   Widget _buildSignatureSection() {
//     return Row(
//       children: [
//         Expanded(
//           child: Column(
//             children: [
//               const SizedBox(height: 20),
//               Container(height: 1, color: Colors.black),
//               const SizedBox(height: 4),
//               const Text('Customer Signature', style: TextStyle(fontSize: 10)),
//             ],
//           ),
//         ),
//         const SizedBox(width: 20),
//         Expanded(
//           child: Column(
//             children: [
//               const SizedBox(height: 20),
//               Container(height: 1, color: Colors.black),
//               const SizedBox(height: 4),
//               const Text('Sales Rep Signature', style: TextStyle(fontSize: 10)),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   // Helper method for summary rows
//   Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 1),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             label,
//             style: TextStyle(
//               fontSize: isBold ? 16 : 14,
//               fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
//             ),
//           ),
//           Text(
//             value,
//             style: TextStyle(
//               fontSize: isBold ? 16 : 14,
//               fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // Method to print this bill
//   Future<bool> printBill() async {
//     try {
//       return await BillPrinterService.printBill(widget.bill);
//     } catch (e) {
//       print('Error printing bill from widget: $e');
//       return false;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       constraints: const BoxConstraints(
//         maxWidth: 400,
//       ), // Receipt width constraint
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.grey.shade300),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withValues(alpha:0.1),
//             spreadRadius: 1,
//             blurRadius: 3,
//             offset: const Offset(0, 1),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           // Company Header
//           Center(
//             child: Column(
//               children: [
//                 Text(
//                   'Sajith Rice Mill',
//                   style: const TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   'Sajith Rice Mill,Nadalagamuwa,Wadumunnegedara',
//                   style: const TextStyle(fontSize: 12),
//                   textAlign: TextAlign.center,
//                 ),
//                 const SizedBox(height: 2),
//                 Text(
//                   'Tel: (077) 92-58293',
//                   style: const TextStyle(fontSize: 12),
//                 ),
//               ],
//             ),
//           ),

//           const SizedBox(height: 12),
//           const Divider(thickness: 1),

//           // Invoice Header
//           const SizedBox(height: 8),
//           const Center(
//             child: Text(
//               'INVOICE',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//           ),

//           const SizedBox(height: 12),

//           // Bill Details
//           _buildInfoRow('Bill No:', widget.bill.billNumber, isBold: true),
//           _buildInfoRow(
//             'Date:',
//             DateFormat('dd/MM/yyyy HH:mm').format(widget.bill.billDate),
//           ),
//           _buildInfoRow('Payment:', widget.bill.paymentType.toUpperCase()),

//           const SizedBox(height: 12),
//           const Divider(thickness: 1),
//           const SizedBox(height: 12),

//           // Customer and Sales Rep Details (Side by Side)
//           _buildTwoColumnInfo(
//             'CUSTOMER:',
//             '${widget.bill.customerName}\n${widget.bill.outletName}\n${widget.bill.outletAddress}${widget.bill.outletPhone.isNotEmpty ? '\nPhone: ${widget.bill.outletPhone}' : ''}',
//             'SALES REP:',
//             '${widget.bill.salesRepName}\nPhone: ${widget.bill.salesRepPhone}',
//           ),

//           const SizedBox(height: 15),
//           const Divider(thickness: 1),
//           const SizedBox(height: 10),

//           // Items Table Header
//           _buildTableRow(
//             col1: '#',
//             col2: 'ITEM',
//             col3: 'QTY',
//             col4: 'PRICE',
//             col5: 'TOTAL',
//             isHeader: true,
//           ),

//           const SizedBox(height: 6),
//           const Divider(thickness: 2),
//           const SizedBox(height: 6),

//           // Items List
//           ...widget.bill.items.map((item) {
//             return _buildTableRow(
//               col1: '${item.itemNumber}',
//               col2: item.itemName,
//               col3: '${item.quantity}',
//               col4: BillPrinterService.currency.format(item.unitPrice),
//               col5: BillPrinterService.currency.format(item.totalPrice),
//             );
//           }).toList(),

//           const SizedBox(height: 10),
//           const Divider(thickness: 1),
//           const SizedBox(height: 10),

//           // Summary Section
//           _buildSummaryRow(
//             'Subtotal:',
//             BillPrinterService.currency.format(widget.bill.totalAmount),
//           ),

//           if (widget.bill.discountAmount > 0)
//             _buildSummaryRow(
//               'Discount:',
//               '-${BillPrinterService.currency.format(widget.bill.discountAmount)}',
//             ),

//           if (widget.bill.taxAmount > 0)
//             _buildSummaryRow(
//               'Tax:',
//               BillPrinterService.currency.format(widget.bill.taxAmount),
//             ),

//           const SizedBox(height: 10),
//           const Divider(thickness: 2),
//           const SizedBox(height: 10),

//           // Total
//           _buildSummaryRow(
//             'TOTAL:',
//             BillPrinterService.currency.format(widget.bill.finalAmount),
//             isBold: true,
//           ),

//           const SizedBox(height: 12),
//           const Divider(thickness: 1),
//           const SizedBox(height: 15),

//           // Signature Section
//           _buildSignatureSection(),

//           const SizedBox(height: 20),

//           // Footer
//           const Center(
//             child: Text(
//               'Thank you for your business!',
//               style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
//             ),
//           ),
//           const SizedBox(height: 6),
//           const Center(
//             child: Text('Visit us again soon', style: TextStyle(fontSize: 12)),
//           ),

//           const SizedBox(height: 15),

//           // Company Footer
//           const Center(
//             child: Text('Solutions by', style: TextStyle(fontSize: 10)),
//           ),
//           const SizedBox(height: 4),
//           const Center(
//             child: Text(
//               'Lumora Ventures Pvt Ltd',
//               style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
//             ),
//           ),
//           const SizedBox(height: 4),
//           const Center(
//             child: Text(
//               'info@lumoraventures.com',
//               style: TextStyle(fontSize: 10),
//             ),
//           ),

//           const SizedBox(height: 15),

//           // Print Actions (if printer is connected)
//           if (BillPrinterService.isConnected) ...[
//             const Divider(),
//             const SizedBox(height: 12),
//             Row(
//               children: [
//                 Expanded(
//                   child: ElevatedButton(
//                     onPressed: () async {
//                       try {
//                         final success = await BillPrinterService.testPrint();
//                         if (context.mounted) {
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             SnackBar(
//                               content: Text(
//                                 success
//                                     ? 'Test print successful!'
//                                     : 'Test print failed',
//                               ),
//                               backgroundColor:
//                                   success ? Colors.green : Colors.red,
//                             ),
//                           );
//                         }
//                       } catch (e) {
//                         if (context.mounted) {
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             SnackBar(
//                               content: Text('Test print error: $e'),
//                               backgroundColor: Colors.red,
//                             ),
//                           );
//                         }
//                       }
//                     },
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.blue.shade600,
//                       foregroundColor: Colors.white,
//                       padding: const EdgeInsets.symmetric(vertical: 8),
//                     ),
//                     child: const Text(
//                       'Test Print',
//                       style: TextStyle(fontSize: 12),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: ElevatedButton(
//                     onPressed: () async {
//                       try {
//                         final success = await printBill();
//                         if (context.mounted) {
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             SnackBar(
//                               content: Text(
//                                 success
//                                     ? 'Bill printed successfully!'
//                                     : 'Failed to print bill',
//                               ),
//                               backgroundColor:
//                                   success ? Colors.green : Colors.red,
//                             ),
//                           );
//                         }
//                       } catch (e) {
//                         if (context.mounted) {
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             SnackBar(
//                               content: Text('Print error: $e'),
//                               backgroundColor: Colors.red,
//                             ),
//                           );
//                         }
//                       }
//                     },
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.green.shade600,
//                       foregroundColor: Colors.white,
//                       padding: const EdgeInsets.symmetric(vertical: 8),
//                     ),
//                     child: const Text(
//                       'Print Bill',
//                       style: TextStyle(fontSize: 12),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ] else ...[
//             const Divider(),
//             const SizedBox(height: 12),
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: Colors.orange.shade50,
//                 borderRadius: BorderRadius.circular(6),
//                 border: Border.all(color: Colors.orange.shade200),
//               ),
//               child: Row(
//                 children: [
//                   Icon(Icons.info, color: Colors.orange.shade600, size: 16),
//                   const SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       'Connect a Bluetooth printer to enable printing',
//                       style: TextStyle(
//                         fontSize: 10,
//                         color: Colors.orange.shade700,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }
// }
