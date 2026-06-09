// lib/services/pdf_service.dart

import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:pos/models/sale.dart';
import 'package:pos/models/table.dart';
import 'package:pos/providers/cart_provider.dart';
import 'package:pos/models/user.dart' as user_model;

class PdfService {
  // ============================================
  //               BILL RECEIPT
  // ============================================
  static Future<pw.Document> createBillReceipt({
    required Sale sale,
    required user_model.UserModel? user,
  }) async {
    final pdf = pw.Document();

    // Load logo image
    Uint8List? logoBytes;
    if (user?.restaurantLogoUrl != null &&
        user!.restaurantLogoUrl!.isNotEmpty) {
      logoBytes = await _getImageData(user.restaurantLogoUrl!);
    }

    final formattedReceiptId = DateFormat('ddMMyyHHmm').format(DateTime.now());
    final formattedDateTime = DateFormat(
      'dd MMM yyyy hh:mm a',
    ).format(sale.createdAt);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // HEADER
              pw.Center(
                child: pw.Column(
                  children: [
                    if (logoBytes != null && logoBytes.isNotEmpty)
                      pw.Container(
                        width: 60,
                        height: 60,
                        child: pw.Image(pw.MemoryImage(logoBytes)),
                      ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      user?.restaurantName.isNotEmpty == true
                          ? user!.restaurantName
                          : 'My Restaurant',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (user?.location.isNotEmpty == true)
                      pw.Text(
                        user!.location,
                        style: pw.TextStyle(fontSize: 10),
                        textAlign: pw.TextAlign.center,
                      ),
                    if (user?.phoneNo.isNotEmpty == true)
                      pw.Text(
                        'Phone: ${user!.phoneNo}',
                        style: pw.TextStyle(fontSize: 10),
                      ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'CUSTOMER RECEIPT',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // RECEIPT INFO BOX
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey600),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey600,
                    width: 0.3,
                  ),
                  children: [
                    pw.TableRow(
                      children: [
                        _infoCell('Receipt:', isLabel: true),
                        _infoCell(formattedReceiptId),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _infoCell('Date:', isLabel: true),
                        _infoCell(formattedDateTime),
                      ],
                    ),
                    if (sale.tableNumber != null &&
                        sale.tableNumber!.isNotEmpty)
                      pw.TableRow(
                        children: [
                          _infoCell('Table:', isLabel: true),
                          _infoCell(sale.tableNumber!),
                        ],
                      ),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),

              // ITEMS TABLE
              pw.Text(
                'ITEMS',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey600,
                  width: 0.5,
                ),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Product',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(
                            'Amount',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  ...sale.items.map((item) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            '${item.productName} x${item.quantity}',
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text(
                              (item.price * item.quantity).toStringAsFixed(0),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),

              pw.SizedBox(height: 10),

              // TOTAL BOX
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey300,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfColors.black),
                ),
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 8,
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL:',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      sale.total.toStringAsFixed(0),
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              pw.Divider(),

              // FOOTER
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Thank you for your purchase!',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Developed by Tycoon Technologies Pvt. Ltd',
                      style: pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text('03060626699', style: pw.TextStyle(fontSize: 8)),
                    pw.Text(
                      'www.tycoon.technology',
                      style: pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  // ============================================
  //               KOT RECEIPT
  // ============================================
  static Future<pw.Document> createKOT({
    required List<CartItem> items,
    RestaurantTable? table,
    required user_model.UserModel? user,
    String? orderType,
  }) async {
    final pdf = pw.Document();

    // Load logo
    Uint8List? logoBytes;
    if (user?.restaurantLogoUrl != null &&
        user!.restaurantLogoUrl!.isNotEmpty) {
      logoBytes = await _getImageData(user.restaurantLogoUrl!);
    }

    // Group items BEFORE widget tree
    final Map<String, int> groupedItems = {};
    for (final item in items) {
      final name = item.displayName;
      groupedItems[name] = (groupedItems[name] ?? 0) + item.quantity;
    }

    final now = DateTime.now();
    final formattedKotId = DateFormat('ddMMyyHHmmss').format(now);
    final formattedTime = DateFormat('hh:mm a').format(now);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 15),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // HEADER
              pw.Center(
                child: pw.Column(
                  children: [
                    if (logoBytes != null && logoBytes.isNotEmpty)
                      pw.Container(
                        width: 50,
                        height: 50,
                        child: pw.Image(pw.MemoryImage(logoBytes)),
                      ),
                    pw.Text(
                      'KITCHEN ORDER TICKET',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      user?.restaurantName ?? 'Restaurant',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),

              // INFO TABLE
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                children: [
                  pw.TableRow(
                    children: [
                      _infoCell('KOT#', isLabel: true),
                      _infoCell(formattedKotId),
                    ],
                  ),
                  if (table != null)
                    pw.TableRow(
                      children: [
                        _infoCell('Table', isLabel: true),
                        _infoCell('Table ${table.tableNumber}'),
                      ],
                    ),
                  pw.TableRow(
                    children: [
                      _infoCell('Time', isLabel: true),
                      _infoCell(formattedTime),
                    ],
                  ),
                  if (orderType != null)
                    pw.TableRow(
                      children: [
                        _infoCell('Type', isLabel: true),
                        _infoCell(orderType),
                      ],
                    ),
                ],
              ),

              pw.SizedBox(height: 10),

              pw.Text(
                'ITEMS ORDERED:',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text(
                          'Qty',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text(
                          'Description',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  ...groupedItems.entries.map((entry) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Text(
                            '${entry.value}',
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Text(entry.key),
                        ),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 10),

              pw.Divider(),

              pw.Center(
                child: pw.Text(
                  '*** KOT ***',
                  style: pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  // Helper cell widget
  static pw.Widget _infoCell(String text, {bool isLabel = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: isLabel ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  // Load image URL
  static Future<Uint8List> _getImageData(String url) async {
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) return res.bodyBytes;
    } catch (_) {}
    return Uint8List(0);
  }
}
