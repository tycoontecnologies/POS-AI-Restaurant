import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:pos/models/sale.dart';
import 'package:pos/models/table.dart';
import 'package:pos/providers/cart_provider.dart';
import 'package:pos/models/user.dart' as user_model;
import 'package:pos/services/document_print_service.dart';

class PdfService {
  static Future<pw.Document> createBillReceipt({
    required Sale sale,
    required user_model.UserModel? user,
    int? printNumber,
    String documentTitle = 'CUSTOMER RECEIPT',
    String documentType = 'RECEIPT',
    bool showPayment = true,
  }) async {
    final pdf = pw.Document();
    final actualPrintNumber = printNumber ?? await DocumentPrintService.nextPrintNumber(
      restaurantId: user?.id ?? sale.vendorId,
      documentType: documentType,
      documentId: sale.id,
      userId: user?.authUid ?? user?.id ?? sale.vendorId,
      branchId: user?.branchId,
    );

    Uint8List? logoBytes;
    if (user?.restaurantLogoUrl != null && user!.restaurantLogoUrl!.isNotEmpty) {
      logoBytes = await _getImageData(user.restaurantLogoUrl!);
    }

    final receiptId = DateFormat('ddMMyyHHmmss').format(sale.createdAt);
    final dateTime = DateFormat('dd MMM yyyy hh:mm a').format(sale.createdAt);
    final copyText = '${_ordinal(actualPrintNumber).toUpperCase()} PRINT';
    final numberLabel = documentType.toUpperCase() == 'BILL' ? 'Bill No:' : 'Receipt No:';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(child: pw.Column(children: [
              if (logoBytes != null && logoBytes.isNotEmpty)
                pw.Container(width: 56, height: 56, child: pw.Image(pw.MemoryImage(logoBytes))),
              pw.SizedBox(height: 4),
              pw.Text(user?.restaurantName.isNotEmpty == true ? user!.restaurantName : 'Restaurant', style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold)),
              if (user?.location.isNotEmpty == true) pw.Text(user!.location, style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center),
              if (user?.phoneNo.isNotEmpty == true) pw.Text('Phone: ${user!.phoneNo}', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 7),
              pw.Text(documentTitle, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            ])),
            pw.SizedBox(height: 9),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey600, width: .35),
              children: [
                pw.TableRow(children: [_infoCell(numberLabel, label: true), _infoCell(receiptId)]),
                pw.TableRow(children: [_infoCell('Date:', label: true), _infoCell(dateTime)]),
                if (sale.tableNumber != null && sale.tableNumber!.isNotEmpty)
                  pw.TableRow(children: [_infoCell('Table:', label: true), _infoCell(sale.tableNumber!)]),
                if (sale.waiterName != null && sale.waiterName!.trim().isNotEmpty)
                  pw.TableRow(children: [_infoCell('Waiter:', label: true), _infoCell(sale.waiterName!)]),
                if (showPayment)
                  pw.TableRow(children: [_infoCell('Paid via:', label: true), _infoCell(sale.paymentMethod.isEmpty ? 'Unknown' : sale.paymentMethod)]),
                if (showPayment && sale.paymentReference != null && sale.paymentReference!.trim().isNotEmpty)
                  pw.TableRow(children: [_infoCell('Reference:', label: true), _infoCell(sale.paymentReference!)]),
                if (sale.praInvoiceNo != null && sale.praInvoiceNo!.trim().isNotEmpty)
                  pw.TableRow(children: [_infoCell('PRA Invoice:', label: true), _infoCell(sale.praInvoiceNo!)]),
                if (sale.praInvoiceId != null && sale.praInvoiceId!.trim().isNotEmpty)
                  pw.TableRow(children: [_infoCell('PRA ID:', label: true), _infoCell(sale.praInvoiceId!)]),
              ],
            ),
            pw.SizedBox(height: 9),
            pw.Text('ITEMS', style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey600, width: .45),
              children: [
                pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey300), children: [
                  _tableCell('Product', bold: true),
                  _tableCell('Amount', bold: true, right: true),
                ]),
                ...sale.items.map((item) => pw.TableRow(children: [
                  _tableCell('${item.productName} x${item.quantity}'),
                  _tableCell((item.price * item.quantity).toStringAsFixed(0), right: true),
                ])),
              ],
            ),
            pw.SizedBox(height: 8),
            if (sale.tipAmount > 0)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Tip:', style: const pw.TextStyle(fontSize: 9.5)), pw.Text(sale.tipAmount.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 9.5))]),
              ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: pw.BoxDecoration(color: PdfColors.grey300, border: pw.Border.all(color: PdfColors.black), borderRadius: pw.BorderRadius.circular(3)),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text(sale.total.toStringAsFixed(0), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ]),
            ),
            pw.SizedBox(height: 10),
            pw.Divider(),
            pw.Center(child: pw.Column(children: [
              pw.Text(showPayment ? 'Thank you for your purchase!' : 'Please present this bill at payment.', style: const pw.TextStyle(fontSize: 9.5)),
              pw.SizedBox(height: 3),
              pw.Text(copyText, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Text('Powered by Tycoon POS', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              pw.Text('Tycoon Technologies Pvt. Ltd | www.tycoon.technology', style: const pw.TextStyle(fontSize: 7.5)),
            ])),
          ],
        ),
      ),
    );
    return pdf;
  }

  static Future<pw.Document> createKOT({
    required List<CartItem> items,
    RestaurantTable? table,
    required user_model.UserModel? user,
    String? orderType,
    int? printNumber,
    String? kotNumber,
  }) async {
    final pdf = pw.Document();
    final documentId = kotNumber ?? table?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final actualPrintNumber = printNumber ?? await DocumentPrintService.nextPrintNumber(
      restaurantId: user?.id ?? 'unknown',
      documentType: 'KOT',
      documentId: documentId,
      userId: user?.authUid ?? user?.id ?? 'unknown',
      branchId: user?.branchId,
    );
    final copyText = '${_ordinal(actualPrintNumber).toUpperCase()} PRINT';

    Uint8List? logoBytes;
    if (user?.restaurantLogoUrl != null && user!.restaurantLogoUrl!.isNotEmpty) {
      logoBytes = await _getImageData(user.restaurantLogoUrl!);
    }

    final grouped = <String, int>{};
    for (final item in items) {
      grouped[item.displayName] = (grouped[item.displayName] ?? 0) + item.quantity;
    }
    final now = DateTime.now();
    final kotId = kotNumber ?? DateFormat('ddMMyyHHmmss').format(now);
    final time = DateFormat('hh:mm a').format(now);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Center(child: pw.Column(children: [
            if (logoBytes != null && logoBytes.isNotEmpty) pw.Container(width: 46, height: 46, child: pw.Image(pw.MemoryImage(logoBytes))),
            pw.Text('KITCHEN ORDER TICKET', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
            pw.Text(user?.restaurantName ?? 'Restaurant', style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
          ])),
          pw.SizedBox(height: 8),
          pw.Table(border: pw.TableBorder.all(width: .45), children: [
            pw.TableRow(children: [_infoCell('KOT No:', label: true), _infoCell(kotId)]),
            if (table != null) pw.TableRow(children: [_infoCell('Table:', label: true), _infoCell('Table ${table.tableNumber}')]),
            pw.TableRow(children: [_infoCell('Time:', label: true), _infoCell(time)]),
            if (orderType != null) pw.TableRow(children: [_infoCell('Type:', label: true), _infoCell(orderType)]),
          ]),
          pw.SizedBox(height: 8),
          pw.Text('ITEMS ORDERED:', style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold)),
          pw.Table(border: pw.TableBorder.all(width: .45), children: [
            pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey300), children: [_tableCell('Qty', bold: true), _tableCell('Description', bold: true)]),
            ...grouped.entries.map((entry) => pw.TableRow(children: [_tableCell('${entry.value}'), _tableCell(entry.key)])),
          ]),
          pw.SizedBox(height: 9),
          pw.Divider(),
          pw.Center(child: pw.Text(copyText, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold))),
        ]),
      ),
    );
    return pdf;
  }

  static pw.Widget _infoCell(String text, {bool label = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(text, style: pw.TextStyle(fontSize: 9.5, fontWeight: label ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  static pw.Widget _tableCell(String text, {bool bold = false, bool right = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Align(
          alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
          child: pw.Text(text, style: pw.TextStyle(fontSize: 9.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ),
      );

  static String _ordinal(int n) {
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  static Future<Uint8List> _getImageData(String url) async {
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) return res.bodyBytes;
    } catch (_) {}
    return Uint8List(0);
  }
}
