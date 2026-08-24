import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos/providers/auth_provider.dart';

const _purple = Color(0xFF6C3BFF);
const _line = Color(0xFFE2E8F0);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);

class PraSettingsScreen extends StatefulWidget {
  const PraSettingsScreen({super.key});

  @override
  State<PraSettingsScreen> createState() => _PraSettingsScreenState();
}

class _PraSettingsScreenState extends State<PraSettingsScreen> {
  final _regNo = TextEditingController();
  final _posId = TextEditingController();
  final _token = TextEditingController();
  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('vendors').doc(user.id).collection('integrations').doc('pra').get();
      final data = doc.data() ?? {};
      _regNo.text = (data['registrationNo'] ?? '').toString();
      _posId.text = (data['posId'] ?? '').toString();
      _token.text = (data['token'] ?? '').toString();
      _enabled = data['enabled'] == true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    await FirebaseFirestore.instance.collection('vendors').doc(user.id).collection('integrations').doc('pra').set({
      'registrationNo': _regNo.text.trim(),
      'posId': _posId.text.trim(),
      'token': _token.text.trim(),
      'enabled': _enabled,
      'updatedAt': FieldValue.serverTimestamp(),
      'status': _enabled ? 'configuration_saved' : 'disabled',
    }, SetOptions(merge: true));
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PRA configuration saved.')));
  }

  @override
  void dispose() {
    _regNo.dispose();
    _posId.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final configured = _regNo.text.trim().isNotEmpty && _posId.text.trim().isNotEmpty && _token.text.trim().isNotEmpty;
    return ColoredBox(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('PRA Integration', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _ink)),
          const SizedBox(height: 3),
          const Text('Configure Punjab Revenue Authority e-invoicing credentials for this restaurant.', style: TextStyle(fontSize: 11.5, color: _muted)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFF3EFFF), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.verified_user_outlined, color: _purple)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(configured && _enabled ? 'Configuration ready' : 'Not connected', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
                  const SizedBox(height: 2),
                  const Text('Saving credentials does not claim a successful PRA API connection. Live transmission should only be enabled after credentials and endpoint are verified.', style: TextStyle(fontSize: 10.5, color: _muted)),
                ])),
                Switch(value: _enabled, onChanged: (v) => setState(() => _enabled = v)),
              ]),
              const SizedBox(height: 18),
              TextField(controller: _regNo, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'PRA Registration / NTN', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: _posId, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'PRA POS / Terminal ID', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: _token, onChanged: (_) => setState(() {}), obscureText: true, decoration: const InputDecoration(labelText: 'API token / credential', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'Saving...' : 'Save PRA settings'))),
            ]),
          ),
        ]),
      ),
    );
  }
}
