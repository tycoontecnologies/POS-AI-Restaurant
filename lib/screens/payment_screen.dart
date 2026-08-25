import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/routes/app_router.dart';
import 'package:pos/services/stripe_service.dart';
import 'package:pos/services/usage_billing_reconciliation_service.dart';

class PaymentScreen extends StatefulWidget {
  final String plan;
  const PaymentScreen({super.key, required this.plan});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const burgundy = Color(0xFF7A1026);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const line = Color(0xFFE2E8F0);
  bool _isProcessing = false;
  bool _reconciling = false;
  bool _reconciled = false;
  String? _errorMessage;

  Map<String, dynamic> get _planDetails {
    switch (widget.plan) {
      case 'perTransaction':
        return {'name': 'Pay per Transaction', 'price': 'Rs 1', 'period': 'per successful receipt', 'amount': 0};
      case 'monthly':
        return {'name': 'Monthly', 'price': 'PKR 7,000', 'period': 'per month', 'amount': 7000};
      case 'yearly':
        return {'name': 'Yearly', 'price': 'PKR 80,000', 'period': 'per year', 'amount': 80000};
      case 'fiveYears':
        return {'name': '5 Years', 'price': 'PKR 200,000', 'period': 'five-year package', 'amount': 200000};
      default:
        return {'name': 'Monthly', 'price': 'PKR 7,000', 'period': 'per month', 'amount': 7000};
    }
  }

  Future<void> _processStandard() async {
    setState(() { _isProcessing = true; _errorMessage = null; });
    try {
      final success = await StripeService.processPayment(
        amount: (_planDetails['amount'] as int) * 100,
        currency: 'pkr',
        planType: widget.plan,
      ).timeout(const Duration(seconds: 30));
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening secure payment…'), backgroundColor: Color(0xFF2563EB)));
      }
    } on TimeoutException {
      if (mounted) setState(() => _errorMessage = 'Payment request timed out. Please try again.');
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  DateTime _monthEnd(DateTime now) => DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  Future<void> _activateUsagePlan(String restaurantId) async {
    setState(() { _isProcessing = true; _errorMessage = null; });
    try {
      final now = DateTime.now();
      await FirebaseFirestore.instance.collection('vendors').doc(restaurantId).set({
        'subscriptionType': 'monthly',
        'billingPlanId': 'perTransaction',
        'transactionRate': 1,
        'billingStatus': 'active',
        'accessMode': 'full',
        'hasActiveSubscription': true,
        'packageActivatedAt': FieldValue.serverTimestamp(),
        'nextPaymentDueAt': Timestamp.fromDate(_monthEnd(now)),
        'paymentWindowStartDay': 25,
      }, SetOptions(merge: true));
      await UsageBillingReconciliationService().reconcile(restaurantId);
      _reconciled = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rs 1 per successful receipt package activated and receipts synchronized.'), backgroundColor: Color(0xFF059669)));
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _reconcileUsage(String restaurantId) async {
    if (_reconciling) return;
    if (mounted) setState(() => _reconciling = true);
    try {
      await UsageBillingReconciliationService().reconcile(restaurantId);
      _reconciled = true;
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Receipt sync failed: $e');
    } finally {
      if (mounted) setState(() => _reconciling = false);
    }
  }

  Future<void> _payUsage(double amount) async {
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('There is no outstanding usage balance.')));
      return;
    }
    setState(() { _isProcessing = true; _errorMessage = null; });
    try {
      final opened = await StripeService.processPayment(
        amount: (amount * 100).round(),
        currency: 'pkr',
        planType: 'perTransaction',
      ).timeout(const Duration(seconds: 30));
      if (opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opening payment for Rs ${amount.toStringAsFixed(0)} transaction usage…'), backgroundColor: const Color(0xFF2563EB)));
      }
    } on TimeoutException {
      if (mounted) setState(() => _errorMessage = 'Payment request timed out. Please try again.');
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _generateTycoonInvoice({
    required DocumentReference<Map<String, dynamic>> vendorRef,
    required String restaurantName,
    required String restaurantId,
    required int receipts,
    required double rate,
    required double due,
  }) async {
    setState(() => _isProcessing = true);
    try {
      await UsageBillingReconciliationService().reconcile(restaurantId);
      final usage = await vendorRef.collection('billingUsage').where('status', isEqualTo: 'billable').get();
      final now = DateTime.now();
      final invoiceNo = 'TYC-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${restaurantId.length > 6 ? restaurantId.substring(0, 6).toUpperCase() : restaurantId.toUpperCase()}';
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (_) => [
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('TYCOON TECHNOLOGIES (PVT.) LTD.', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('POS Usage Invoice', style: const pw.TextStyle(fontSize: 11)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('INVOICE', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.Text(invoiceNo),
                pw.Text(_date(now)),
              ]),
            ]),
            pw.SizedBox(height: 24),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Billed to', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(restaurantName.isEmpty ? restaurantId : restaurantName),
                pw.Text('Restaurant ID: $restaurantId'),
              ]),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: const ['Description', 'Receipts', 'Rate', 'Amount'],
              data: [
                ['Successful POS receipts', '$receipts', 'Rs ${rate.toStringAsFixed(0)}', 'Rs ${due.toStringAsFixed(0)}'],
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellPadding: const pw.EdgeInsets.all(8),
            ),
            pw.SizedBox(height: 18),
            pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('TOTAL DUE: Rs ${due.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 18),
            pw.Text('Payable to Tycoon Technologies (Pvt.) Ltd.'),
            pw.SizedBox(height: 8),
            pw.Text('This invoice contains one charge for each unique successful receipt. Reprints do not create additional charges.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            if (usage.docs.isNotEmpty) ...[
              pw.SizedBox(height: 24),
              pw.Text('Billable receipt ledger', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              ...usage.docs.take(100).map((d) {
                final a = d.data();
                final amount = a['amount'] ?? a['billableAmount'] ?? rate;
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Expanded(child: pw.Text((a['receiptId'] ?? a['saleId'] ?? d.id).toString(), style: const pw.TextStyle(fontSize: 8))),
                    pw.Text('Rs $amount', style: const pw.TextStyle(fontSize: 8)),
                  ]),
                );
              }),
            ],
          ],
        ),
      );
      await Printing.layoutPdf(onLayout: (_) async => pdf.save());
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Could not generate invoice: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.plan == 'perTransaction') return _buildUsagePlan(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: _panel(children: [
              _topRow(context),
              const SizedBox(height: 16),
              Text(_planDetails['name'] as String, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: ink)),
              const SizedBox(height: 8),
              Text(_planDetails['price'] as String, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: burgundy)),
              Text(_planDetails['period'] as String, style: const TextStyle(color: muted, fontSize: 12)),
              const SizedBox(height: 24),
              _infoBox(widget.plan == 'monthly'
                  ? 'The monthly payment window opens on the 25th. Payment should be completed by month-end. If payment remains overdue after the deadline, the system moves to Basic Mode until payment is recorded.'
                  : 'You will be redirected to the secure Tycoon Technologies payment flow for this package.'),
              _error(),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, height: 48, child: FilledButton(onPressed: _isProcessing ? null : _processStandard, style: _buttonStyle(), child: _buttonChild('Proceed to payment'))),
              const SizedBox(height: 10),
              Center(child: TextButton(onPressed: () => context.go(AppRouter.dashboard), child: const Text('Cancel and return to dashboard'))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildUsagePlan(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final ref = FirebaseFirestore.instance.collection('vendors').doc(user.id);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? <String, dynamic>{};
          final active = (data['billingPlanId'] ?? '').toString() == 'perTransaction' && (data['hasActiveSubscription'] ?? false) == true;
          if (active && !_reconciled && !_reconciling) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _reconcileUsage(user.id));
          }
          final lifetimeReceipts = (data['successfulReceiptCount'] is num) ? (data['successfulReceiptCount'] as num).toInt() : 0;
          final unbilled = (data['unbilledReceiptCount'] is num) ? (data['unbilledReceiptCount'] as num).toInt() : 0;
          final rate = (data['transactionRate'] is num) ? (data['transactionRate'] as num).toDouble() : 1.0;
          final rawDue = (data['transactionUsageAmount'] is num) ? (data['transactionUsageAmount'] as num).toDouble() : unbilled * rate;
          final due = rawDue < 0 ? 0.0 : rawDue;
          final paid = (data['transactionPaidTotal'] is num) ? (data['transactionPaidTotal'] as num).toDouble() : 0.0;
          final paidReceipts = (data['transactionPaidReceiptTotal'] is num) ? (data['transactionPaidReceiptTotal'] as num).toInt() : 0;
          final dueRaw = data['nextPaymentDueAt'];
          final dueDate = dueRaw is Timestamp ? dueRaw.toDate() : null;
          final status = (data['billingStatus'] ?? (active ? 'active' : 'not active')).toString();

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: _panel(children: [
                  _topRow(context),
                  const SizedBox(height: 14),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Pay per Transaction', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: ink)),
                      SizedBox(height: 5),
                      Text('Rs 1 is charged once for each unique successfully completed receipt. Reprints are not charged again.', style: TextStyle(color: muted, fontSize: 12.5, height: 1.45)),
                    ])),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), decoration: BoxDecoration(color: const Color(0xFFFBECEF), borderRadius: BorderRadius.circular(12)), child: const Text('Rs 1 / receipt', style: TextStyle(color: burgundy, fontWeight: FontWeight.w900, fontSize: 16))),
                  ]),
                  if (_reconciling) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(minHeight: 2),
                    const SizedBox(height: 5),
                    const Text('Synchronizing completed receipts with the Tycoon billing ledger…', style: TextStyle(fontSize: 10.5, color: muted)),
                  ],
                  const SizedBox(height: 22),
                  LayoutBuilder(builder: (_, c) {
                    final cols = c.maxWidth > 820 ? 4 : c.maxWidth > 560 ? 2 : 1;
                    final w = (c.maxWidth - ((cols - 1) * 12)) / cols;
                    return Wrap(spacing: 12, runSpacing: 12, children: [
                      SizedBox(width: w, child: _metric('Current billable receipts', '$unbilled', Icons.receipt_long_outlined)),
                      SizedBox(width: w, child: _metric('Current amount due', 'Rs ${due.toStringAsFixed(0)}', Icons.payments_outlined)),
                      SizedBox(width: w, child: _metric('Lifetime successful receipts', '$lifetimeReceipts', Icons.analytics_outlined)),
                      SizedBox(width: w, child: _metric('Receipts already paid', '$paidReceipts', Icons.verified_outlined)),
                    ]);
                  }),
                  const SizedBox(height: 12),
                  _infoBox(active
                      ? 'Status: ${status.toUpperCase()}  •  Rate: Rs ${rate.toStringAsFixed(rate % 1 == 0 ? 0 : 2)} per successful receipt${dueDate == null ? '' : '  •  Payment due ${_date(dueDate)}'}\nTotal usage payments recorded: Rs ${paid.toStringAsFixed(0)}. The payment reminder begins on the 25th. If an outstanding balance remains after month-end, premium features move to Basic Mode until the usage balance is settled.'
                      : 'Activate this package with no upfront subscription fee. Existing completed receipts are synchronized into a unique receipt ledger and future completed receipts are metered automatically.'),
                  _error(),
                  const SizedBox(height: 18),
                  if (active) _usageLedger(ref),
                  const SizedBox(height: 18),
                  if (active)
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isProcessing || _reconciling ? null : () => _reconcileUsage(user.id),
                          icon: const Icon(Icons.sync_rounded),
                          label: const Text('Sync Receipts'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isProcessing ? null : () => _generateTycoonInvoice(
                            vendorRef: ref,
                            restaurantName: user.restaurantName,
                            restaurantId: user.id,
                            receipts: unbilled,
                            rate: rate,
                            due: due,
                          ),
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Generate Tycoon Invoice'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                        ),
                      ),
                    ]),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _isProcessing ? null : active ? (due > 0 ? () => _payUsage(due) : null) : () => _activateUsagePlan(user.id),
                      style: _buttonStyle(),
                      child: _buttonChild(active ? (due > 0 ? 'Pay Rs ${due.toStringAsFixed(0)} usage fee' : 'No amount due') : 'Activate Rs 1 / receipt package'),
                    ),
                  ),
                  if (active && due <= 0) ...[
                    const SizedBox(height: 8),
                    const Center(child: Text('Your current transaction usage is fully settled.', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w700, fontSize: 11.5))),
                  ],
                  const SizedBox(height: 10),
                  Center(child: TextButton(onPressed: () => context.go(AppRouter.dashboard), child: const Text('Return to dashboard'))),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _usageLedger(DocumentReference<Map<String, dynamic>> vendorRef) {
    final query = vendorRef.collection('billingUsage').orderBy('completedAt', descending: true).limit(50);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.fromLTRB(16, 14, 16, 10), child: Row(children: [Icon(Icons.list_alt_rounded, size: 18, color: burgundy), SizedBox(width: 8), Text('Recent receipt billing ledger', style: TextStyle(fontWeight: FontWeight.w900, color: ink))])),
        const Divider(height: 1),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: query.snapshots(),
          builder: (_, snap) {
            final docs = snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            if (docs.isEmpty) return const Padding(padding: EdgeInsets.all(18), child: Text('No successful receipts have been metered yet. Use Sync Receipts to reconcile completed sales.', style: TextStyle(color: muted, fontSize: 11.5)));
            return Column(children: docs.map((d) {
              final a = d.data();
              final status = (a['status'] ?? 'billable').toString();
              final rawAmount = a['amount'] ?? a['billableAmount'] ?? a['rate'] ?? 1;
              final amount = rawAmount is num ? rawAmount.toDouble() : 1.0;
              final raw = a['completedAt'];
              final dt = raw is Timestamp ? raw.toDate() : null;
              final statusColor = status == 'paid' ? const Color(0xFF059669) : status == 'cancelled' ? const Color(0xFF94A3B8) : const Color(0xFFF59E0B);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
                child: Row(children: [
                  Expanded(flex: 2, child: Text('Receipt ${a['receiptId'] ?? a['saleId'] ?? d.id}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5))),
                  Expanded(child: Text(dt == null ? '-' : _dateTime(dt), style: const TextStyle(fontSize: 10.5, color: muted))),
                  SizedBox(width: 70, child: Text('Rs ${amount.toStringAsFixed(0)}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5))),
                  const SizedBox(width: 12),
                  Container(width: 78, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: statusColor.withValues(alpha: .10), borderRadius: BorderRadius.circular(16)), child: Text(status.toUpperCase(), textAlign: TextAlign.center, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: statusColor))),
                ]),
              );
            }).toList());
          },
        ),
      ]),
    );
  }

  Widget _metric(String label, String value, IconData icon) => Container(
        height: 112,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFFBECEF), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: burgundy, size: 21)),
          const SizedBox(width: 12),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: ink)), const SizedBox(height: 3), Text(label, style: const TextStyle(fontSize: 10.5, color: muted))])),
        ]),
      );

  Widget _panel({required List<Widget> children}) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: line), boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 16, offset: Offset(0, 5))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _topRow(BuildContext context) => Row(children: [
        IconButton(onPressed: () => context.go(AppRouter.pricing), icon: const Icon(Icons.arrow_back_rounded)),
        const SizedBox(width: 6),
        const Text('TYCOON POS • PACKAGES & BILLING', style: TextStyle(fontSize: 11, letterSpacing: 1, color: Color(0xFFD80000), fontWeight: FontWeight.w900)),
      ]);

  Widget _infoBox(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
        child: Text(text, style: const TextStyle(fontSize: 11.5, height: 1.5, color: Color(0xFF475569))),
      );

  Widget _error() => _errorMessage == null
      ? const SizedBox.shrink()
      : Padding(padding: const EdgeInsets.only(top: 16), child: Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFDA4AF))), child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFBE123C), fontSize: 11.5))));

  ButtonStyle _buttonStyle() => FilledButton.styleFrom(backgroundColor: burgundy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)));

  Widget _buttonChild(String label) => _isProcessing
      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
      : Text(label, style: const TextStyle(fontWeight: FontWeight.w900));

  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _dateTime(DateTime d) => '${_date(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
