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

  static const brandRed = Color(0xFF8D0200);
  static const brandRedDark = Color(0xFF670403);
  static const ink = Color(0xFF111827);

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
        SnackBar(content: Text(auth.error ?? 'Unable to sign in'), backgroundColor: brandRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 920;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          if (!compact)
            Expanded(
              flex: 11,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFA00000), brandRed, brandRedDark],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(68, 48, 68, 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ExactTycoonLogo(width: 260),
                      const Spacer(),
                      const Text(
                        'Run the floor.\nControl the business.',
                        style: TextStyle(color: Colors.white, fontSize: 48, height: 1.04, fontWeight: FontWeight.w900, letterSpacing: -.8),
                      ),
                      const SizedBox(height: 18),
                      const SizedBox(
                        width: 520,
                        child: Text(
                          'Tables, KOT, billing, workforce, inventory and command-center intelligence — one secure restaurant operating system.',
                          style: TextStyle(color: Color(0xFFF7DEDE), fontSize: 15, height: 1.55),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _FeaturePill(Icons.table_restaurant_outlined, 'Live Floor'),
                          _FeaturePill(Icons.soup_kitchen_outlined, 'Kitchen Flow'),
                          _FeaturePill(Icons.receipt_long_outlined, 'Smart Billing'),
                          _FeaturePill(Icons.hub_outlined, 'Command Center'),
                        ],
                      ),
                      const Spacer(),
                      const Text(
                        'TYCOON TECHNOLOGIES  •  SECURE RESTAURANT CLOUD',
                        style: TextStyle(color: Color(0xFFE6C7C7), fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 1.1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            flex: compact ? 1 : 9,
            child: ColoredBox(
              color: Colors.white,
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 28 : 72, vertical: 36),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (compact) ...[
                            const Center(child: _ExactTycoonLogo(width: 210)),
                            const SizedBox(height: 28),
                          ],
                          const Text('Welcome back', style: TextStyle(color: ink, fontSize: 31, fontWeight: FontWeight.w900, letterSpacing: -.5)),
                          const SizedBox(height: 8),
                          const Text('Sign in to your restaurant workspace.', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13.5)),
                          const SizedBox(height: 30),
                          _label('Email address'),
                          const SizedBox(height: 7),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _inputDecoration('you@restaurant.com', Icons.mail_outline_rounded),
                            validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email address' : null,
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 18),
                          _label('Password'),
                          const SizedBox(height: 7),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: _inputDecoration('Enter your password', Icons.lock_outline_rounded).copyWith(
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 19),
                              ),
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Enter your password' : null,
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 12),
                          Row(children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: _remember,
                                onChanged: (v) => setState(() => _remember = v ?? true),
                                activeColor: brandRed,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('Remember me', style: TextStyle(fontSize: 11.5, color: Color(0xFF6B7280))),
                            const Spacer(),
                            TextButton(
                              onPressed: () => showDialog(context: context, builder: (_) => const ForgotPasswordDialog()),
                              child: const Text('Forgot password?', style: TextStyle(color: brandRed, fontWeight: FontWeight.w700, fontSize: 11.5)),
                            ),
                          ]),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              onPressed: auth.isLoading ? null : _submit,
                              style: FilledButton.styleFrom(backgroundColor: brandRed, foregroundColor: Colors.white),
                              child: auth.isLoading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      Text('SIGN IN', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .7)),
                                      SizedBox(width: 9),
                                      Icon(Icons.arrow_forward_rounded, size: 18),
                                    ]),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: TextButton(
                              onPressed: widget.onSignUpPressed,
                              child: const Text('Need a restaurant account?  Create one', style: TextStyle(color: Color(0xFF6B7280), fontSize: 11.5)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _label(String text) => Text(text, style: const TextStyle(color: ink, fontSize: 11.5, fontWeight: FontWeight.w700));

  InputDecoration _inputDecoration(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 19),
        filled: true,
        fillColor: const Color(0xFFFAFAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: brandRed, width: 1.4)),
      );
}

class _ExactTycoonLogo extends StatelessWidget {
  final double width;
  const _ExactTycoonLogo({required this.width});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Image.asset(
          'assets/tycoon_logo.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Text(
            'TYCOON',
            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
        ),
      );
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeaturePill(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: .18)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 7),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
        ]),
      );
}
