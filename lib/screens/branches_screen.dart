import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos/providers/auth_provider.dart';

const _purple = Color(0xFF6C3BFF);
const _line = Color(0xFFE2E8F0);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);

class BranchesScreen extends StatelessWidget {
  const BranchesScreen({super.key});

  CollectionReference<Map<String, dynamic>> _ref(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser!;
    return FirebaseFirestore.instance.collection('vendors').doc(user.id).collection('branches');
  }

  Future<void> _add(BuildContext context) async {
    final name = TextEditingController();
    final address = TextEditingController();
    final code = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Add branch'),
        content: SizedBox(
          width: 430,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Branch name', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: code, decoration: const InputDecoration(labelText: 'Branch code', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: address, decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder())),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, {'name': name.text.trim(), 'code': code.text.trim(), 'address': address.text.trim()});
            },
            child: const Text('Add branch'),
          ),
        ],
      ),
    );
    name.dispose();
    code.dispose();
    address.dispose();
    if (result == null || !context.mounted) return;
    await _ref(context).add({
      ...result,
      'active': true,
      'premiumFeature': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const Center(child: CircularProgressIndicator());
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Branches', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _ink)),
              SizedBox(height: 3),
              Text('Multi-branch controls are enabled for the demo and can be premium-gated later.', style: TextStyle(fontSize: 11.5, color: _muted)),
            ])),
            FilledButton.icon(onPressed: () => _add(context), icon: const Icon(Icons.add_business_outlined), label: const Text('Add branch')),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _ref(context).orderBy('createdAt', descending: false).snapshots(),
              builder: (_, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return _MainBranchOnly(branchName: user.branchName, restaurantName: user.restaurantName);
                }
                return GridView.builder(
                  itemCount: docs.length + 1,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 360, mainAxisExtent: 170, crossAxisSpacing: 12, mainAxisSpacing: 12),
                  itemBuilder: (_, i) {
                    if (i == 0) return _BranchCard(name: user.branchName, code: 'MAIN', address: user.location, active: true, main: true);
                    final d = docs[i - 1];
                    final data = d.data();
                    return _BranchCard(
                      name: (data['name'] ?? 'Branch').toString(),
                      code: (data['code'] ?? '').toString(),
                      address: (data['address'] ?? '').toString(),
                      active: data['active'] != false,
                      onToggle: (v) => d.reference.set({'active': v}, SetOptions(merge: true)),
                      onDelete: () => d.reference.delete(),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _MainBranchOnly extends StatelessWidget {
  final String branchName;
  final String restaurantName;
  const _MainBranchOnly({required this.branchName, required this.restaurantName});
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 350, height: 170, child: _BranchCard(name: branchName, code: 'MAIN', address: restaurantName, active: true, main: true)),
      );
}

class _BranchCard extends StatelessWidget {
  final String name;
  final String code;
  final String address;
  final bool active;
  final bool main;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onDelete;
  const _BranchCard({required this.name, required this.code, required this.address, required this.active, this.main = false, this.onToggle, this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFF3EFFF), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.store_mall_directory_outlined, color: _purple)),
            const Spacer(),
            if (main) const Chip(label: Text('MAIN')) else Switch(value: active, onChanged: onToggle),
          ]),
          const Spacer(),
          Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
          const SizedBox(height: 3),
          Text([if (code.isNotEmpty) code, if (address.isNotEmpty) address].join(' • '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: _muted)),
          if (!main && onDelete != null)
            Align(alignment: Alignment.bottomRight, child: IconButton(tooltip: 'Delete branch', onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18))),
        ]),
      );
}
