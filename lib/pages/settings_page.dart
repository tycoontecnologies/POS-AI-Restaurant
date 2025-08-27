import 'package:flutter/material.dart';
import '../state/settings_store.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _businessCtrl;
  late final TextEditingController _currencyCtrl;
  late final TextEditingController _taxCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;

  @override
  void initState() {
    super.initState();
    final s = SettingsStore.instance;
    _businessCtrl = TextEditingController(text: s.businessName);
    _currencyCtrl = TextEditingController(text: s.currency);
    _taxCtrl = TextEditingController(text: s.taxRate.toString());
    _phoneCtrl = TextEditingController(text: s.phone);
    _addressCtrl = TextEditingController(text: s.address);
  }

  @override
  void dispose() {
    _businessCtrl.dispose();
    _currencyCtrl.dispose();
    _taxCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            children: [
              Text('Settings', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: _businessCtrl,
                decoration: const InputDecoration(labelText: 'Business Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Support Phone'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Support email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    final tax = double.tryParse(_taxCtrl.text.trim()) ?? 0;
    SettingsStore.instance.update(
      businessName: _businessCtrl.text.trim(),
      currency: _currencyCtrl.text.trim(),
      taxRate: tax,
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Settings saved')));
  }
}
