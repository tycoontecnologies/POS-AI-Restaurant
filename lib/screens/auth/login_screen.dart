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

  static const burgundy = Color(0xFF5A0D18);
  static const burgundyDeep = Color(0xFF2B0710);
  static const burgundyBright = Color(0xFF7A1324);
  static const gold = Color(0xFFD8AE63);
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
        SnackBar(content: Text(auth.error ?? 'Unable to sign in'), backgroundColor: burgundyBright),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 900;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
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
                    colors: [burgundyBright, burgundy, burgundyDeep],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(right: -140, top: -120, child: _Glow(size: 430, opacity: .08)),
                    Positioned(left: -120, bottom: -160, child: _Glow(size: 420, opacity: .05)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(72, 60, 72, 54),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            _TycoonShield(size: 54),
                            const SizedBox(width: 14),
                            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('TYCOON POS', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                              SizedBox(height: 2),
                              Text('RESTAURANT MANAGEMENT SYSTEM', style: TextStyle(color: Color(0xFFDABCC1), fontSize: 8.5, fontWeight: FontWeight.w700, letterSpacing: 1.8)),
                            ]),
                          ]),
                          const Spacer(),
                          const SizedBox(
                            width: 560,
                            child: Text(
                              'Run the floor.\nControl the business.',
                              style: TextStyle(color: Colors.white, fontSize: 48, height: 1.03, fontWeight: FontWeight.w900, letterSpacing: -.8),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const SizedBox(
                            width: 510,
                            child: Text(
                              'Tables, KOT, billing, workforce, inventory and command-center intelligence — one secure restaurant operating system.',
                              style: TextStyle(color: Color(0xFFE2CDD1), fontSize: 15, height: 1.55),
                            ),
                          ),
                          const SizedBox(height: 30),
                          const Wrap(spacing: 10, runSpacing: 10, children: [
                            _FeaturePill(icon: Icons.table_restaurant_outlined, text: 'Live Floor'),
                            _FeaturePill(icon: Icons.soup_kitchen_outlined, text: 'Kitchen Flow'),
                            _FeaturePill(icon: Icons.receipt_long_outlined, text: 'Smart Billing'),
                            _FeaturePill(icon: Icons.hub_outlined, text: 'Command Center'),
                          ]),
                          const Spacer(),
                          const Row(children: [
                            Icon(Icons.verified_user_outlined, color: gold, size: 17),
                            SizedBox(width: 8),
                            Text('TYCOON TECHNOLOGIES  •  SECURE RESTAURANT CLOUD', style: TextStyle(color: Color(0xFFC9AAB0), fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            flex: compact ? 1 : 9,
            child: Container(
              color: Colors.white,
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 28 : 72, vertical: 40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (compact) ...[
                            Center(child: _TycoonShield(size: 74, dark: true)),
                            const SizedBox(height: 18),
                            const Center(child: Text('TYCOON POS', style: TextStyle(color: burgundy, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.2))),
                            const SizedBox(height: 34),
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
                            autofillHints: const [AutofillHints.email],
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
                            autofillHints: const [AutofillHints.password],
                            decoration: _inputDecoration('Enter your password', Icons.lock_outline_rounded).copyWith(
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 19),
                              ),
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Enter your password' : null,
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 13),
                          Row(children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: _remember,
                                onChanged: (v) => setState(() => _remember = v ?? true),
                                activeColor: burgundy,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('Remember me', style: TextStyle(fontSize: 11.5, color: Color(0xFF6B7280))),
                            const Spacer(),
                            TextButton(
                              onPressed: () => showDialog(context: context, builder: (_) => const ForgotPasswordDialog()),
                              child: const Text('Forgot password?', style: TextStyle(color: burgundy, fontWeight: FontWeight.w700, fontSize: 11.5)),
                            ),
                          ]),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              onPressed: auth.isLoading ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: burgundy,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                              ),
                              child: auth.isLoading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      Text('SIGN IN', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .8)),
                                      SizedBox(width: 9),
                                      Icon(Icons.arrow_forward_rounded, size: 18),
                                    ]),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFF9F5F6), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE8D8DC))),
                            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Icon(Icons.key_rounded, size: 17, color: burgundy),
                              SizedBox(width: 9),
                              Expanded(child: Text('Demo: ali@gmail.com  •  Password: 123456', style: TextStyle(fontSize: 10.5, color: Color(0xFF6B4A52), height: 1.4))),
                            ]),
                          ),
                          const SizedBox(height: 22),
                          Center(
                            child: TextButton(
                              onPressed: widget.onSignUpPressed,
                              child: const Text('Need a restaurant account?  Create one', style: TextStyle(color: Color(0xFF6B7280), fontSize: 11.5)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Center(child: Text('Tycoon Technologies Pvt. Ltd.', style: TextStyle(color: Color(0xFFB0B4BD), fontSize: 9.5))),
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
        hintStyle: const TextStyle(color: Color(0xFFA6ABB4), fontSize: 12),
        prefixIcon: Icon(icon, size: 19, color: const Color(0xFF8B929D)),
        filled: true,
        fillColor: const Color(0xFFFAFAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: burgundy, width: 1.4)),
      );
}

class _TycoonShield extends StatelessWidget {
  final double size;
  final bool dark;
  const _TycoonShield({required this.size, this.dark = false});

  @override
  Widget build(BuildContext context) {
    final fg = dark ? _LoginScreenState.burgundy : Colors.white;
    final bg = dark ? const Color(0xFFF9F2F4) : Colors.white.withValues(alpha: .10);
    final border = dark ? _LoginScreenState.burgundy : Colors.white.withValues(alpha: .85);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * .22), border: Border.all(color: border, width: 1.5)),
      child: Stack(alignment: Alignment.center, children: [
        Icon(Icons.shield_outlined, color: fg, size: size * .72),
        Text('T', style: TextStyle(color: fg, fontSize: size * .34, fontWeight: FontWeight.w900, height: 1)),
      ]),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeaturePill({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withValues(alpha: .12))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: _LoginScreenState.gold, size: 15), const SizedBox(width: 7), Text(text, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700))]),
      );
}

class _Glow extends StatelessWidget {
  final double size;
  final double opacity;
  const _Glow({required this.size, required this.opacity});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: opacity)),
      );
}
