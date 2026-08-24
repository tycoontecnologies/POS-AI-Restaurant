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

  static const purple = Color(0xFF6C3BFF);
  static const ink = Color(0xFF0F172A);
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
    final compact = MediaQuery.sizeOf(context).width < 900;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          if (!compact)
            Expanded(
              flex: 11,
              child: Container(
                color: const Color(0xFFD80000),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/tycoon_pos_bg.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFD80000),
                        alignment: Alignment.center,
                        child: const Text(
                          'TYCOON POS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            flex: compact ? 1 : 9,
            child: ColoredBox(
              color: Colors.white,
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 28 : 72,
                    vertical: 36,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (compact) ...[
                            SizedBox(
                              height: 150,
                              width: double.infinity,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.asset(
                                  'assets/tycoon_pos_bg.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: const Color(0xFFD80000),
                                    alignment: Alignment.center,
                                    child: const Text('TYCOON POS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                          ],
                          const Text(
                            'Welcome back',
                            style: TextStyle(
                              color: ink,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.6,
                            ),
                          ),
                          const SizedBox(height: 7),
                          const Text(
                            'Sign in to your restaurant workspace.',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
                          ),
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
                          const SizedBox(height: 17),
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
                          Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: Checkbox(
                                  value: _remember,
                                  onChanged: (v) => setState(() => _remember = v ?? true),
                                  activeColor: purple,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('Remember me', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                              const Spacer(),
                              TextButton(
                                onPressed: () => showDialog(context: context, builder: (_) => const ForgotPasswordDialog()),
                                child: const Text('Forgot password?', style: TextStyle(color: purple, fontWeight: FontWeight.w700, fontSize: 11.5)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              onPressed: auth.isLoading ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: purple,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: auth.isLoading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text('SIGN IN', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .7)),
                                        SizedBox(width: 9),
                                        Icon(Icons.arrow_forward_rounded, size: 18),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: TextButton(
                              onPressed: widget.onSignUpPressed,
                              child: const Text('Need a restaurant account?  Create one', style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5)),
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

  static Widget _label(String text) => const Text('', style: TextStyle()).copyWith(data: text, style: const TextStyle(color: ink, fontSize: 11.5, fontWeight: FontWeight.w700));

  InputDecoration _inputDecoration(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 19),
        filled: true,
        fillColor: soft,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: purple, width: 1.4)),
      );
}

extension on Text {
  Text copyWith({String? data, TextStyle? style}) => Text(data ?? this.data ?? '', style: style ?? this.style);
}
