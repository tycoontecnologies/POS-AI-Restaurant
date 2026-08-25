import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/models/billing_plan.dart';
import 'package:pos/models/user.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/routes/app_router.dart';
import 'package:pos/services/subscription_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignUpScreen extends StatefulWidget {
  final VoidCallback? onLoginPressed;
  const SignUpScreen({super.key, this.onLoginPressed});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _phone = TextEditingController();
  final _restaurant = TextEditingController();
  final _subscriptions = SubscriptionService();
  BillingPlan _selected = BillingPlan.plans.first;
  bool _obscure = true;
  bool _obscureConfirm = true;

  static const burgundy = Color(0xFF7A1026);
  static const brandRed = Color(0xFFD80000);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const soft = Color(0xFFF8FAFC);

  @override
  void dispose() {
    for (final c in [_email, _password, _confirm, _name, _location, _phone, _restaurant]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.signUp(email: _email.text.trim(), password: _password.text, name: _name.text.trim(), role: UserRole.admin, location: _location.text.trim(), phoneNo: _phone.text.trim(), restaurantName: _restaurant.text.trim());
    if (!mounted) return;
    if (!success || auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.error ?? 'Sign up failed'), backgroundColor: Colors.red));
      return;
    }
    try {
      await _subscriptions.assignPlan(vendorId: auth.currentUser!.id, plan: _selected);
      final prefs = await SharedPreferences.getInstance();
      for (final key in ['onboarding_categories', 'onboarding_products', 'onboarding_staff', 'onboarding_suppliers']) { await prefs.remove(key); }
      if (mounted) context.go(AppRouter.categories);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Account created, but package setup failed: $e'), backgroundColor: Colors.red));
    }
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 19),
        filled: true,
        fillColor: soft,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: burgundy, width: 1.4)),
      );

  Widget _field(TextEditingController c, String label, IconData icon, {TextInputType? type, String? Function(String?)? validator}) => TextFormField(controller: c, keyboardType: type, decoration: _dec(label, icon), validator: validator);

  Widget _passwordField(TextEditingController c, String label, bool obscure, VoidCallback toggle, String? Function(String?) validator) => TextFormField(controller: c, obscureText: obscure, decoration: _dec(label, Icons.lock_outline_rounded).copyWith(suffixIcon: IconButton(onPressed: toggle, icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined))), validator: validator);

  String? Function(String?) _required(String name) => (v) => v == null || v.trim().isEmpty ? 'Enter $name' : null;

  Widget _planCard(BillingPlan plan) {
    final selected = plan.id == _selected.id;
    return InkWell(
      onTap: () => setState(() => _selected = plan),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: selected ? const Color(0xFFFFF3F5) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: selected ? burgundy : border, width: selected ? 2 : 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(plan.title, style: const TextStyle(fontWeight: FontWeight.w900, color: ink))), if (selected) const Icon(Icons.check_circle, color: burgundy, size: 20)]),
          const SizedBox(height: 7),
          if (plan.regularPrice != null) Text('Rs ${plan.regularPrice}', style: const TextStyle(fontSize: 11, color: muted, decoration: TextDecoration.lineThrough)),
          Text(plan.type == BillingPlanType.perTransaction ? 'Rs ${plan.price} / receipt' : 'Rs ${plan.price}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: burgundy)),
          const SizedBox(height: 5),
          Text(plan.description, style: const TextStyle(fontSize: 10.5, color: muted, height: 1.35)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 900;
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(children: [
        if (!compact)
          Expanded(
            flex: 9,
            child: Container(
              color: brandRed,
              padding: const EdgeInsets.all(42),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 190, height: 190, padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)), child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.asset('assets/logo.jpeg', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.shield_rounded, size: 80, color: brandRed)))),
                    const SizedBox(height: 22),
                    const Text('TYCOON POS', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 1.8)),
                    const SizedBox(height: 8),
                    const Text('Create your restaurant workspace, choose a package and start your 3-day trial.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFFDECEC), fontSize: 13, height: 1.45)),
                    const SizedBox(height: 24),
                    const Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                      _MiniChip(Icons.table_restaurant_outlined, 'Tables'),
                      _MiniChip(Icons.soup_kitchen_outlined, 'KOT'),
                      _MiniChip(Icons.receipt_long_outlined, 'Billing'),
                      _MiniChip(Icons.inventory_2_outlined, 'Inventory'),
                      _MiniChip(Icons.people_alt_outlined, 'Staff'),
                      _MiniChip(Icons.verified_user_outlined, 'PRA'),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
        Expanded(
          flex: 11,
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: compact ? 20 : 42, vertical: 26),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Form(
                  key: _formKey,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (compact) ...[
                      Center(child: Container(width: 100, height: 100, padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: border)), child: ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.asset('assets/logo.jpeg', fit: BoxFit.cover)))),
                      const SizedBox(height: 16),
                    ],
                    const Text('Create your restaurant account', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: ink)),
                    const SizedBox(height: 5),
                    const Text('Enter your details, choose the package you want, and start your 3-day trial.', style: TextStyle(fontSize: 11.5, color: muted)),
                    const SizedBox(height: 20),
                    LayoutBuilder(builder: (_, c) {
                      final two = c.maxWidth > 580;
                      final fields = <Widget>[
                        _field(_restaurant, 'Restaurant Name', Icons.restaurant_outlined, validator: _required('restaurant name')),
                        _field(_name, 'Owner / Admin Name', Icons.person_outline, validator: _required('name')),
                        _field(_email, 'Email Address', Icons.mail_outline, type: TextInputType.emailAddress, validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null),
                        _field(_phone, 'Phone Number', Icons.phone_outlined, type: TextInputType.phone, validator: _required('phone number')),
                        _field(_location, 'Location', Icons.location_on_outlined, validator: _required('location')),
                        _passwordField(_password, 'Password', _obscure, () => setState(() => _obscure = !_obscure), (v) => v == null || v.length < 6 ? 'Minimum 6 characters' : null),
                        _passwordField(_confirm, 'Confirm Password', _obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm), (v) => v != _password.text ? 'Passwords do not match' : null),
                      ];
                      if (!two) return Column(children: fields.map((e) => Padding(padding: const EdgeInsets.only(bottom: 11), child: e)).toList());
                      return Wrap(spacing: 12, runSpacing: 11, children: fields.map((e) => SizedBox(width: (c.maxWidth - 12) / 2, child: e)).toList());
                    }),
                    const SizedBox(height: 14),
                    const Text('Choose your package', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ink)),
                    const SizedBox(height: 4),
                    const Text('The package is saved with this restaurant. You can upgrade later from your Tycoon account menu.', style: TextStyle(fontSize: 10.5, color: muted)),
                    const SizedBox(height: 10),
                    LayoutBuilder(builder: (_, c) {
                      final width = c.maxWidth > 620 ? (c.maxWidth - 12) / 2 : c.maxWidth;
                      return Wrap(spacing: 12, runSpacing: 12, children: BillingPlan.plans.map((p) => SizedBox(width: width, child: _planCard(p))).toList());
                    }),
                    const SizedBox(height: 18),
                    SizedBox(width: double.infinity, height: 50, child: FilledButton.icon(
                      onPressed: auth.isLoading ? null : _submit,
                      style: FilledButton.styleFrom(backgroundColor: burgundy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      icon: auth.isLoading ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.arrow_forward_rounded),
                      label: Text(auth.isLoading ? 'CREATING ACCOUNT...' : 'CONTINUE WITH ${_selected.title.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    )),
                    const SizedBox(height: 10),
                    Center(child: TextButton(onPressed: widget.onLoginPressed, child: const Text('Already have an account?  Sign in', style: TextStyle(color: burgundy, fontWeight: FontWeight.w700)))),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MiniChip(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white24)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 15, color: Colors.white), const SizedBox(width: 5), Text(text, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700))]));
}
