import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
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
  bool _obscurePassword = true;
  bool _remember = true;

  static const brandRed = Color(0xFFD80000);
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
    final ok = await auth.signIn(email: _emailController.text.trim(), password: _passwordController.text);
    if (!mounted) return;
    if (ok) {
      context.go(AppRouter.dashboard);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.error ?? 'Unable to sign in')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 900;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: compact
          ? SingleChildScrollView(
              child: Column(children: [
                SizedBox(height: 250, width: double.infinity, child: _BrandPanel(compact: true)),
                _LoginForm(auth: auth, formKey: _formKey, emailController: _emailController, passwordController: _passwordController, obscurePassword: _obscurePassword, remember: _remember, onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword), onRemember: (v) => setState(() => _remember = v), onSubmit: _submit, onSignUp: widget.onSignUpPressed),
              ]),
            )
          : Row(children: [
              const Expanded(flex: 10, child: _BrandPanel(compact: false)),
              Expanded(flex: 9, child: _LoginForm(auth: auth, formKey: _formKey, emailController: _emailController, passwordController: _passwordController, obscurePassword: _obscurePassword, remember: _remember, onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword), onRemember: (v) => setState(() => _remember = v), onSubmit: _submit, onSignUp: widget.onSignUpPressed)),
            ]),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  final bool compact;
  const _BrandPanel({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _LoginScreenState.brandRed,
      padding: EdgeInsets.symmetric(horizontal: compact ? 24 : 58, vertical: compact ? 20 : 42),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: compact ? 118 : 190,
                height: compact ? 118 : 190,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 8))]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/logo.jpeg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.shield_rounded, color: _LoginScreenState.brandRed, size: 74)),
                  ),
                ),
              ),
              SizedBox(height: compact ? 12 : 22),
              Text('TYCOON POS', style: TextStyle(color: Colors.white, fontSize: compact ? 24 : 34, fontWeight: FontWeight.w900, letterSpacing: 1.8)),
              if (!compact) ...[
                const SizedBox(height: 8),
                const Text('Restaurant operations, billing and control — in one system.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFFDECEC), fontSize: 13.5, height: 1.4)),
                const SizedBox(height: 28),
                const Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    _FeatureChip(Icons.table_restaurant_outlined, 'Live Tables'),
                    _FeatureChip(Icons.soup_kitchen_outlined, 'KOT / Kitchen'),
                    _FeatureChip(Icons.receipt_long_outlined, 'Smart Billing'),
                    _FeatureChip(Icons.inventory_2_outlined, 'Inventory'),
                    _FeatureChip(Icons.people_alt_outlined, 'Staff & CRM'),
                    _FeatureChip(Icons.verified_user_outlined, 'PRA Ready'),
                  ],
                ),
                const SizedBox(height: 28),
                const Text('Tycoon Technologies (Pvt.) Ltd.  •  Secure Restaurant Cloud', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFEFC7C7), fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: .5)),
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
  const _FeatureChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: .24))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white, size: 16), const SizedBox(width: 6), Text(label, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700))]),
      );
}

class _LoginForm extends StatelessWidget {
  final AuthProvider auth;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool remember;
  final VoidCallback onTogglePassword;
  final ValueChanged<bool> onRemember;
  final Future<void> Function() onSubmit;
  final VoidCallback? onSignUp;
  const _LoginForm({required this.auth, required this.formKey, required this.emailController, required this.passwordController, required this.obscurePassword, required this.remember, required this.onTogglePassword, required this.onRemember, required this.onSubmit, required this.onSignUp});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 54, vertical: 36),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Form(
              key: formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Welcome back', style: TextStyle(color: _LoginScreenState.ink, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -.6)),
                const SizedBox(height: 7),
                const Text('Sign in to your restaurant workspace.', style: TextStyle(color: _LoginScreenState.muted, fontSize: 13.5)),
                const SizedBox(height: 30),
                _label('Email address'),
                const SizedBox(height: 7),
                TextFormField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: _decoration('you@restaurant.com', Icons.mail_outline_rounded), validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email address' : null, onFieldSubmitted: (_) => onSubmit()),
                const SizedBox(height: 17),
                _label('Password'),
                const SizedBox(height: 7),
                TextFormField(controller: passwordController, obscureText: obscurePassword, decoration: _decoration('Enter your password', Icons.lock_outline_rounded).copyWith(suffixIcon: IconButton(onPressed: onTogglePassword, icon: Icon(obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 19))), validator: (v) => v == null || v.isEmpty ? 'Enter your password' : null, onFieldSubmitted: (_) => onSubmit()),
                const SizedBox(height: 12),
                Row(children: [
                  SizedBox(width: 20, height: 20, child: Checkbox(value: remember, onChanged: (v) => onRemember(v ?? true), activeColor: _LoginScreenState.burgundy)),
                  const SizedBox(width: 8),
                  const Text('Remember me', style: TextStyle(fontSize: 11.5, color: _LoginScreenState.muted)),
                  const Spacer(),
                  TextButton(onPressed: () => showDialog(context: context, builder: (_) => const ForgotPasswordDialog()), child: const Text('Forgot password?', style: TextStyle(color: _LoginScreenState.burgundy, fontWeight: FontWeight.w800, fontSize: 11.5))),
                ]),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: auth.isLoading ? null : onSubmit,
                    style: FilledButton.styleFrom(backgroundColor: _LoginScreenState.burgundy, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: auth.isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('SIGN IN', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .7)), SizedBox(width: 9), Icon(Icons.arrow_forward_rounded, size: 18)]),
                  ),
                ),
                const SizedBox(height: 18),
                Center(child: TextButton(onPressed: onSignUp, child: const Text('Need a restaurant account?  Create one', style: TextStyle(color: _LoginScreenState.muted, fontSize: 11.5, fontWeight: FontWeight.w600)))),
                const SizedBox(height: 6),
                const Center(child: Text('3-day trial • Choose your package after sign-up', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5))),
              ]),
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
