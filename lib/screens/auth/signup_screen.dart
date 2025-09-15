import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pos/models/user.dart';
import 'package:pos/routes/app_router.dart';
import 'package:provider/provider.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/utils/app_spacing.dart';
import 'package:pos/components/ui/custom_button.dart';
import 'package:pos/components/ui/custom_card.dart';
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
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      name: _nameController.text.trim(),
      // role: _selectedRole,
      role: UserRole.admin,
    );

    if (success && mounted) {
      // Clear any previous onboarding state
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('onboarding_categories');
      await prefs.remove('onboarding_products');
      await prefs.remove('onboarding_staff');
      await prefs.remove('onboarding_suppliers');

      GoRouter.of(context).go(AppRouter.categories);
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: Duration(seconds: 1),
          content: Text(authProvider.error ?? 'Sign up failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? AppSpacing.xs : AppSpacing.xl),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 450,
            ),
            child: CustomCard(
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.all(
                  isMobile ? AppSpacing.xs : AppSpacing.xl,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.point_of_sale,
                        size: isMobile ? 48 : 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(
                        height: isMobile ? AppSpacing.md : AppSpacing.lg,
                      ),
                      Text(
                        'Create Account',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: isMobile ? 22 : 24,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Create a new POS account',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(
                        height: isMobile ? AppSpacing.lg : AppSpacing.xl,
                      ),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      // const SizedBox(height: AppSpacing.md),
                      // DropdownButtonFormField<UserRole>(
                      //   value: _selectedRole,
                      //   decoration: const InputDecoration(
                      //     labelText: 'Role',
                      //     prefixIcon: Icon(Icons.people),
                      //   ),
                      //   items: UserRole.values.map((role) {
                      //     return DropdownMenuItem<UserRole>(
                      //       value: role,
                      //       child: Text(
                      //         role.toString().split('.').last.toUpperCase(),
                      //       ),
                      //     );
                      //   }).toList(),
                      //   onChanged: (value) {
                      //     if (value != null) {
                      //       setState(() {
                      //         _selectedRole = value;
                      //       });
                      //     }
                      //   },
                      // ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        obscureText: _obscurePassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                        ),
                        obscureText: _obscureConfirmPassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      SizedBox(
                        height: isMobile ? AppSpacing.lg : AppSpacing.xl,
                      ),
                      Consumer<AuthProvider>(
                        builder: (context, authProvider, child) {
                          return CustomButton(
                            text: 'Create Account',
                            textColor: Colors.white,
                            onPressed: authProvider.isLoading ? null : _submit,
                            isLoading: authProvider.isLoading,
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Already have an account?'),
                          TextButton(
                            onPressed: widget.onLoginPressed,
                            child: const Text('Sign In'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
