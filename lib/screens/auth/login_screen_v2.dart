import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pos/branding/tycoon_pos_brand.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/routes/app_router.dart';
import 'package:pos/widget/forgot_password_dialog.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onSignUpPressed;
  const LoginScreen({super.key, this.onSignUpPressed});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _remember = true;

  static const red = Color(0xFFD80000);
  static const burgundy = Color(0xFF7A1026);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const soft = Color(0xFFF8FAFC);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    if (ok) {
      context.go(AppRouter.dashboard);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Unable to sign in')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final compact = MediaQuery.sizeOf(context).width < 920;
    return Scaffold(
      backgroundColor: Colors.white,
      body: compact
          ? SingleChildScrollView(
              child: Column(children: [
                const SizedBox(height: 330, child: _BrandPanel(compact: true)),
                _LoginForm(
                  auth: auth,
                  formKey: _formKey,
                  emailController: _emailController,
                  passwordController: _passwordController,
                  obscure: _obscure,
                  remember: _remember,
                  onTogglePassword: () => setState(() => _obscure = !_obscure),
                  onRemember: (v) => setState(() => _remember = v),
                  onSubmit: _submit,
                  onSignUp: widget.onSignUpPressed,
                ),
              ]),
            )
          : Row(children: [
              const Expanded(flex: 10, child: _BrandPanel(compact: false)),
              Expanded(
                flex: 9,
                child: _LoginForm(
                  auth: auth,
                  formKey: _formKey,
                  emailController: _emailController,
                  passwordController: _passwordController,
                  obscure: _obscure,
                  remember: _remember,
                  onTogglePassword: () => setState(() => _obscure = !_obscure),
                  onRemember: (v) => setState(() => _remember = v),
                  onSubmit: _submit,
                  onSignUp: widget.onSignUpPressed,
                ),
              ),
            ]),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  final bool compact;
  const _BrandPanel({required this.compact});

  @override
  Widget build(BuildContext context) {
    final chips = const [
      (Icons.table_restaurant_outlined, 'Live Tables'),
      (Icons.soup_kitchen_outlined, 'Kitchen / KOT'),
      (Icons.receipt_long_outlined, 'Smart Billing'),
      (Icons.inventory_2_outlined, 'Inventory'),
      (Icons.groups_2_outlined, 'Staff & CRM'),
      (Icons.verified_user_outlined, 'PRA Ready'),
      (Icons.dashboard_customize_outlined, 'Custom Widgets'),
      (Icons.monitor_heart_outlined, 'Live Control'),
    ];
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(compact ? 22 : 58, compact ? 20 : 42, compact ? 22 : 58, compact ? 20 : 42),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 610),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                TycoonPosLogo(
                  width: compact ? 88 : 116,
                  height: compact ? 88 : 116,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(18),
                ),
                const SizedBox(width: 18),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('TYCOON POS', style: TextStyle(color: _LoginScreenState.ink, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                    SizedBox(height: 4),
                    Text('Restaurant Management System', style: TextStyle(color: _LoginScreenState.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),
              if (!compact) ...[
                const SizedBox(height: 34),
                const Text('One workspace. Every restaurant operation.', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: _LoginScreenState.ink, height: 1.12)),
                const SizedBox(height: 10),
                const Text('Tables, kitchen, billing, payments, inventory, workforce, PRA, live monitoring and management controls in one secure system.', style: TextStyle(color: _LoginScreenState.muted, fontSize: 13, height: 1.5)),
              ],
              SizedBox(height: compact ? 18 : 28),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: chips.map((e) => _FeatureChip(icon: e.$1, label: e.$2)).toList(),
              ),
              if (!compact) ...[
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFECACA))),
                  child: const Row(children: [
                    Icon(Icons.shield_outlined, color: _LoginScreenState.red, size: 18),
                    SizedBox(width: 9),
                    Expanded(child: Text('3-day trial • Flexible packages • Secure cloud access', style: TextStyle(color: _LoginScreenState.burgundy, fontWeight: FontWeight.w800, fontSize: 11.5))),
                  ]),
                ),
                const SizedBox(height: 18),
                const Text('Tycoon Technologies (Pvt.) Ltd.  •  Software for Every Business.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontWeight: FontWeight.w700)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: _LoginScreenState.burgundy, size: 15),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: _LoginScreenState.ink, fontSize: 10.8, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _LoginForm extends StatelessWidget {
  final AuthProvider auth;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscure;
  final bool remember;
  final VoidCallback onTogglePassword;
  final ValueChanged<bool> onRemember;
  final Future<void> Function() onSubmit;
  final VoidCallback? onSignUp;

  const _LoginForm({
    required this.auth,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscure,
    required this.remember,
    required this.onTogglePassword,
    required this.onRemember,
    required this.onSubmit,
    required this.onSignUp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _LoginScreenState.soft,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 36),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _LoginScreenState.border), boxShadow: const [BoxShadow(color: Color(0x0D0F172A), blurRadius: 24, offset: Offset(0, 8))]),
              child: Form(
                key: formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Welcome back', style: TextStyle(color: _LoginScreenState.ink, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -.5)),
                  const SizedBox(height: 6),
                  const Text('Sign in to your restaurant workspace.', style: TextStyle(color: _LoginScreenState.muted, fontSize: 13)),
                  const SizedBox(height: 28),
                  _label('Email address'),
                  const SizedBox(height: 7),
                  TextFormField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: _decoration('you@restaurant.com', Icons.mail_outline_rounded), validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email address' : null, onFieldSubmitted: (_) => onSubmit()),
                  const SizedBox(height: 16),
                  _label('Password'),
                  const SizedBox(height: 7),
                  TextFormField(controller: passwordController, obscureText: obscure, decoration: _decoration('Enter your password', Icons.lock_outline_rounded).copyWith(suffixIcon: IconButton(onPressed: onTogglePassword, icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 19))), validator: (v) => v == null || v.isEmpty ? 'Enter your password' : null, onFieldSubmitted: (_) => onSubmit()),
                  const SizedBox(height: 12),
                  Row(children: [
                    SizedBox(width: 20, height: 20, child: Checkbox(value: remember, onChanged: (v) => onRemember(v ?? true), activeColor: _LoginScreenState.burgundy)),
                    const SizedBox(width: 8),
                    const Text('Remember me', style: TextStyle(fontSize: 11.5, color: _LoginScreenState.muted)),
                    const Spacer(),
                    TextButton(onPressed: () => showDialog(context: context, builder: (_) => const ForgotPasswordDialog()), child: const Text('Forgot password?', style: TextStyle(color: _LoginScreenState.burgundy, fontWeight: FontWeight.w800, fontSize: 11.5))),
                  ]),
                  const SizedBox(height: 17),
                  SizedBox(width: double.infinity, height: 50, child: FilledButton(onPressed: auth.isLoading ? null : onSubmit, style: FilledButton.styleFrom(backgroundColor: _LoginScreenState.burgundy, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: auth.isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('SIGN IN', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .6)), SizedBox(width: 9), Icon(Icons.arrow_forward_rounded, size: 18)]))),
                  const SizedBox(height: 16),
                  Center(child: TextButton(onPressed: onSignUp, child: const Text('Need a restaurant account?  Create one', style: TextStyle(color: _LoginScreenState.muted, fontSize: 11.5, fontWeight: FontWeight.w600)))),
                  const Center(child: Text('Start with a 3-day trial, then choose your package.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5))),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _label(String text) => Text(text, style: const TextStyle(color: _LoginScreenState.ink, fontSize: 11.5, fontWeight: FontWeight.w800));

  static InputDecoration _decoration(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 19),
        filled: true,
        fillColor: _LoginScreenState.soft,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _LoginScreenState.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _LoginScreenState.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _LoginScreenState.burgundy, width: 1.4)),
      );
}
