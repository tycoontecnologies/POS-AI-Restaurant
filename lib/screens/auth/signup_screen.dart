import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/models/user.dart';
import 'package:pos/routes/app_router.dart';
import 'package:provider/provider.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignUpScreen extends StatefulWidget {
  final VoidCallback? onLoginPressed;
  const SignUpScreen({super.key, this.onLoginPressed});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();
  final _restaurantController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  static const purple = Color(0xFF6C3BFF);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const soft = Color(0xFFF8FAFC);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _restaurantController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      name: _nameController.text.trim(),
      role: UserRole.admin,
      location: _locationController.text.trim(),
      phoneNo: _phoneController.text.trim(),
      restaurantName: _restaurantController.text.trim(),
    );

    if (!mounted) return;
    if (success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('onboarding_categories');
      await prefs.remove('onboarding_products');
      await prefs.remove('onboarding_staff');
      await prefs.remove('onboarding_suppliers');
      if (mounted) context.go(AppRouter.categories);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Sign up failed'), backgroundColor: Colors.red),
      );
    }
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 19),
        filled: true,
        fillColor: soft,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: purple, width: 1.4)),
      );

  Widget _field(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(controller: controller, keyboardType: keyboardType, decoration: _decoration(label, icon), validator: validator);
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
            flex: 10,
            child: Container(
              color: const Color(0xFFD80000),
              child: Image.asset(
                'assets/tycoon_pos_bg.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFD80000),
                  alignment: Alignment.center,
                  child: const Text('TYCOON POS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 42, letterSpacing: 3)),
                ),
              ),
            ),
          ),
        Expanded(
          flex: compact ? 1 : 10,
          child: ColoredBox(
            color: Colors.white,
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: compact ? 24 : 52, vertical: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 650),
                  child: Form(
                    key: _formKey,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (compact) ...[
                        SizedBox(
                          height: 130,
                          width: double.infinity,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset('assets/tycoon_pos_bg.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: const Color(0xFFD80000))),
                          ),
                        ),
                        const SizedBox(height: 22),
                      ],
                      const Text('Create your restaurant account', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: ink, letterSpacing: -.5)),
                      const SizedBox(height: 5),
                      const Text('Set up the owner account. Department users can be added later from Users & Roles.', style: TextStyle(fontSize: 11.5, color: muted)),
                      const SizedBox(height: 24),
                      LayoutBuilder(builder: (_, c) {
                        final two = c.maxWidth > 560;
                        if (!two) {
                          return Column(children: _fields());
                        }
                        final left = <Widget>[
                          _field(_restaurantController, 'Restaurant Name', Icons.restaurant_outlined, validator: _required('restaurant name')),
                          const SizedBox(height: 12),
                          _field(_nameController, 'Owner / Admin Name', Icons.person_outline_rounded, validator: _required('name')),
                          const SizedBox(height: 12),
                          _field(_emailController, 'Email Address', Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress, validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null),
                          const SizedBox(height: 12),
                          _passwordField(_passwordController, 'Password', _obscurePassword, () => setState(() => _obscurePassword = !_obscurePassword), validator: (v) => v == null || v.length < 6 ? 'Minimum 6 characters' : null),
                        ];
                        final right = <Widget>[
                          _field(_phoneController, 'Phone Number', Icons.phone_outlined, keyboardType: TextInputType.phone, validator: _required('phone number')),
                          const SizedBox(height: 12),
                          _field(_locationController, 'Location', Icons.location_on_outlined, validator: _required('location')),
                          const SizedBox(height: 12),
                          _passwordField(_confirmPasswordController, 'Confirm Password', _obscureConfirmPassword, () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword), validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null),
                        ];
                        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Column(children: left)), const SizedBox(width: 14), Expanded(child: Column(children: right))]);
                      }),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: auth.isLoading ? null : _submit,
                          style: FilledButton.styleFrom(backgroundColor: purple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          icon: auth.isLoading ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.storefront_outlined, size: 18),
                          label: Text(auth.isLoading ? 'CREATING ACCOUNT...' : 'CREATE ACCOUNT', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: .5)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(child: TextButton(onPressed: widget.onLoginPressed, child: const Text('Already have an account?  Sign in', style: TextStyle(color: purple, fontSize: 11.5, fontWeight: FontWeight.w700)))),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  List<Widget> _fields() => [
        _field(_restaurantController, 'Restaurant Name', Icons.restaurant_outlined, validator: _required('restaurant name')),
        const SizedBox(height: 12),
        _field(_nameController, 'Owner / Admin Name', Icons.person_outline_rounded, validator: _required('name')),
        const SizedBox(height: 12),
        _field(_emailController, 'Email Address', Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress, validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null),
        const SizedBox(height: 12),
        _field(_phoneController, 'Phone Number', Icons.phone_outlined, keyboardType: TextInputType.phone, validator: _required('phone number')),
        const SizedBox(height: 12),
        _field(_locationController, 'Location', Icons.location_on_outlined, validator: _required('location')),
        const SizedBox(height: 12),
        _passwordField(_passwordController, 'Password', _obscurePassword, () => setState(() => _obscurePassword = !_obscurePassword), validator: (v) => v == null || v.length < 6 ? 'Minimum 6 characters' : null),
        const SizedBox(height: 12),
        _passwordField(_confirmPasswordController, 'Confirm Password', _obscureConfirmPassword, () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword), validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null),
      ];

  String? Function(String?) _required(String field) => (v) => v == null || v.trim().isEmpty ? 'Enter $field' : null;

  Widget _passwordField(TextEditingController controller, String label, bool obscure, VoidCallback toggle, {String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: _decoration(label, Icons.lock_outline_rounded).copyWith(
        suffixIcon: IconButton(onPressed: toggle, icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 19)),
      ),
      validator: validator,
    );
  }
}
