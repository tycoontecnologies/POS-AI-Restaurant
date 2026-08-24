import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos/providers/auth_provider.dart';

const _purple = Color(0xFF6C3BFF);
const _line = Color(0xFFE2E8F0);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  CollectionReference<Map<String, dynamic>> _ref(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser!;
    return FirebaseFirestore.instance.collection('vendors').doc(user.id).collection('expenses');
  }

  Future<void> _addExpense(BuildContext context) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    String category = 'General';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Add expense'),
          content: SizedBox(
            width: 430,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: const ['General', 'Salaries', 'Rent', 'Electricity', 'Gas', 'Maintenance', 'Transport', 'Marketing', 'Purchases', 'Other']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => category = v ?? 'General'),
              ),
              const SizedBox(height: 12),
              TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (Rs)', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: note, decoration: const InputDecoration(labelText: 'Note / reference', border: OutlineInputBorder())),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(amount.text.trim());
                if (value == null || value <= 0) return;
                Navigator.pop(dialogContext, {'category': category, 'amount': value, 'note': note.text.trim()});
              },
              child: const Text('Save expense'),
            ),
          ],
        ),
      ),
    );
    amount.dispose();
    note.dispose();
    if (result == null || !context.mounted) return;
    final user = context.read<AuthProvider>().currentUser!;
    await _ref(context).add({
      ...result,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': user.name,
      'createdById': user.authUid ?? user.id,
      'branchId': user.branchId,
      'branchName': user.branchName,
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const Center(child: CircularProgressIndicator());
    final ref = _ref(context);
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Expenses', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _ink)),
              SizedBox(height: 3),
              Text('Record operating expenses for accurate profitability.', style: TextStyle(fontSize: 11.5, color: _muted)),
            ])),
            FilledButton.icon(onPressed: () => _addExpense(context), icon: const Icon(Icons.add_rounded), label: const Text('Add expense')),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ref.orderBy('createdAt', descending: true).snapshots(),
              builder: (_, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                final total = docs.fold<double>(0, (sum, d) => sum + ((d.data()['amount'] as num?)?.toDouble() ?? 0));
                return Column(children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _line), borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFFFF2F2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.payments_outlined, color: Color(0xFFEF4444))),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Rs ${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _ink)),
                        const Text('Recorded expenses', style: TextStyle(fontSize: 10.5, color: _muted)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: docs.isEmpty
                        ? const Center(child: Text('No expenses recorded yet.', style: TextStyle(color: _muted)))
                        : ListView.separated(
                            itemCount: docs.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final d = docs[i];
                              final data = d.data();
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                leading: const CircleAvatar(backgroundColor: Color(0xFFF3EFFF), child: Icon(Icons.receipt_long_outlined, color: _purple, size: 19)),
                                title: Text((data['category'] ?? 'General').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                                subtitle: Text((data['note'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text('Rs ${((data['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, color: _ink)),
                                  const SizedBox(width: 6),
                                  IconButton(tooltip: 'Delete', onPressed: () => d.reference.delete(), icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 19)),
                                ]),
                              );
                            },
                          ),
                  ),
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }
}
