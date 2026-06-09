import 'dart:io';
import 'dart:typed_data';

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
import 'package:pos/services/image_upload_service.dart';

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
  
  // New variables for logo upload
  dynamic _restaurantLogo;
  String? _restaurantLogoUrl;
  bool _isUploadingLogo = false;
  final ImageUploadService _imageUploadService = ImageUploadService();

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

  // New method to pick and upload restaurant logo
  Future<void> _pickRestaurantLogo() async {
    try {
      final pickedImage = await _imageUploadService.pickImage(fromGallery: true);
      if (pickedImage != null) {
        // Validate image
        final validationError = _imageUploadService.validateImage(pickedImage);
        if (validationError != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(validationError),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        setState(() {
          _isUploadingLogo = true;
          _restaurantLogo = pickedImage;
        });

        // For web, we'll upload during signup process
        // For mobile, we can preview the file
        if (!_isWeb()) {
          // Preview logic for mobile
        }

        setState(() {
          _isUploadingLogo = false;
        });
      }
    } catch (e) {
      setState(() {
        _isUploadingLogo = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper method to check if web
  bool _isWeb() {
    return identical(0, 0.0);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Show loading for logo upload if applicable
    if (_restaurantLogo != null) {
      setState(() {
        _isUploadingLogo = true;
      });
    }

    final success = await authProvider.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      name: _nameController.text.trim(),
      role: UserRole.admin,
      location: _locationController.text.trim(),
      phoneNo: _phoneController.text.trim(),
      restaurantName: _restaurantController.text.trim(),
      restaurantLogo: _restaurantLogo, 
    );

    if (success && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('onboarding_categories');
      await prefs.remove('onboarding_products');
      await prefs.remove('onboarding_staff');
      await prefs.remove('onboarding_suppliers');

      GoRouter.of(context).go(AppRouter.categories);
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(authProvider.error ?? 'Sign up failed'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    setState(() {
      _isUploadingLogo = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.grey.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Row(
              children: [
                // Left Side - Form
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(
                      screenWidth > 900 ? AppSpacing.xxl : AppSpacing.xl,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: CustomCard(
                        color: Colors.white,
                        elevation: 16,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(48),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header
                                Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.asset(
                                        'assets/logo.jpeg',
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      'Create Account',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 28,
                                            color: Colors.black87,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Restaurant Logo Upload
                                _buildLogoUploadSection(),
                                const SizedBox(height: AppSpacing.lg),

                                // Rest of the form fields remain the same...
                                // Two Column Layout for Form Fields
                                if (screenWidth > 700) ...[
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          children: [
                                            _buildFormField(
                                              controller: _restaurantController,
                                              label: 'Restaurant Name',
                                              icon: Icons.restaurant_outlined,
                                              validator: (value) {
                                                if (value == null || value.isEmpty) {
                                                  return 'Please enter restaurant name';
                                                }
                                                return null;
                                              },
                                            ),
                                            const SizedBox(height: AppSpacing.md),
                                            _buildFormField(
                                              controller: _nameController,
                                              label: 'Full Name',
                                              icon: Icons.person_outline,
                                              validator: (value) {
                                                if (value == null || value.isEmpty) {
                                                  return 'Please enter your name';
                                                }
                                                return null;
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.lg),
                                      Expanded(
                                        child: Column(
                                          children: [
                                            _buildFormField(
                                              controller: _phoneController,
                                              label: 'Phone Number',
                                              icon: Icons.phone_outlined,
                                              keyboardType: TextInputType.phone,
                                              validator: (value) {
                                                if (value == null || value.isEmpty) {
                                                  return 'Please enter your phone number';
                                                }
                                                return null;
                                              },
                                            ),
                                            const SizedBox(height: AppSpacing.md),
                                            _buildFormField(
                                              controller: _locationController,
                                              label: 'Location',
                                              icon: Icons.location_on_outlined,
                                              validator: (value) {
                                                if (value == null || value.isEmpty) {
                                                  return 'Please enter your location';
                                                }
                                                return null;
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  // Single Column for smaller screens
                                  _buildFormField(
                                    controller: _restaurantController,
                                    label: 'Restaurant Name',
                                    icon: Icons.restaurant_outlined,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter restaurant name';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  _buildFormField(
                                    controller: _nameController,
                                    label: 'Full Name',
                                    icon: Icons.person_outline,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your name';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  _buildFormField(
                                    controller: _emailController,
                                    label: 'Email Address',
                                    icon: Icons.email_outlined,
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
                                  const SizedBox(height: AppSpacing.md),
                                  _buildFormField(
                                    controller: _phoneController,
                                    label: 'Phone Number',
                                    icon: Icons.phone_outlined,
                                    keyboardType: TextInputType.phone,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your phone number';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  _buildFormField(
                                    controller: _locationController,
                                    label: 'Location',
                                    icon: Icons.location_on_outlined,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your location';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.md),
                                _buildFormField(
                                  controller: _emailController,
                                  label: 'Email Address',
                                  icon: Icons.email_outlined,
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
                                const SizedBox(height: AppSpacing.md),

                                // Password Fields - Full Width
                                _buildPasswordField(
                                  controller: _passwordController,
                                  label: 'Password',
                                  obscureText: _obscurePassword,
                                  onToggleVisibility: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
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
                                _buildPasswordField(
                                  controller: _confirmPasswordController,
                                  label: 'Confirm Password',
                                  obscureText: _obscureConfirmPassword,
                                  onToggleVisibility: () {
                                    setState(() {
                                      _obscureConfirmPassword = !_obscureConfirmPassword;
                                    });
                                  },
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
                                const SizedBox(height: 40),

                                // Create Account Button
                                Consumer<AuthProvider>(
                                  builder: (context, authProvider, child) {
                                    final isProcessing = authProvider.isLoading || _isUploadingLogo;
                                    return SizedBox(
                                      width: double.infinity,
                                      child: CustomButton(
                                        text: isProcessing ? 'Creating Account...' : 'Create Account',
                                        textColor: Colors.white,
                                        color: Colors.blue.shade600,
                                        onPressed: isProcessing ? null : _submit,
                                        isLoading: isProcessing,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 24),

                                // Sign In Link
                                Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Already have an account?',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed: widget.onLoginPressed,
                                        child: Text(
                                          'Sign In',
                                          style: TextStyle(
                                            color: Colors.blue.shade600,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
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

                // Right Side - Benefits/Features (unchanged)
                if (screenWidth > 900) ...[
                  Expanded(
                    flex: 5,
                    child: Container(
                      padding: const EdgeInsets.all(80),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start Your Restaurant Management Journey',
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Join thousands of restaurants using our POS system to streamline their operations and grow their business.',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.grey.shade600,
                                  height: 1.6,
                                ),
                          ),
                          const SizedBox(height: 60),
                          _buildBenefitItem(
                            Icons.point_of_sale,
                            'Easy POS Management',
                            'Simple and intuitive point of sale system',
                          ),
                          _buildBenefitItem(
                            Icons.inventory,
                            'Inventory Management',
                            'Keep track of your stock and supplies',
                          ),
                          _buildBenefitItem(
                            Icons.people,
                            'Staff Management',
                            'Manage your team and their permissions',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // New method for logo upload section
  Widget _buildLogoUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Restaurant Logo',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.shade50,
          ),
          child: Column(
            children: [
              if (_restaurantLogo != null || _restaurantLogoUrl != null) ...[
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: _isWeb() && _restaurantLogo != null
                      ? FutureBuilder<Uint8List?>(
                          future: _imageUploadService.getFileBytes(_restaurantLogo),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  snapshot.data!,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              );
                            }
                            return Icon(
                              Icons.restaurant,
                              size: 40,
                              color: Colors.grey.shade400,
                            );
                          },
                        )
                      : _restaurantLogo != null && !_isWeb()
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _restaurantLogo as File,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            )
                          : _restaurantLogoUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    _restaurantLogoUrl!,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Icon(
                                  Icons.restaurant,
                                  size: 40,
                                  color: Colors.grey.shade400,
                                ),
                ),
                const SizedBox(height: 12),
              ],
              ElevatedButton.icon(
                onPressed: _isUploadingLogo ? null : _pickRestaurantLogo,
                icon: _isUploadingLogo
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload),
                label: Text(_isUploadingLogo ? 'Uploading...' : 
                    _restaurantLogo != null ? 'Change Logo' : 'Upload Logo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade50,
                  foregroundColor: Colors.blue.shade700,
                ),
              ),
              if (_restaurantLogo == null && _restaurantLogoUrl == null) ...[
                const SizedBox(height: 8),
                Text(
                  'Optional: Upload your restaurant logo',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Rest of the existing methods (_buildFormField, _buildPasswordField, _buildBenefitItem) remain the same...
  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: 'Enter your $label',
            prefixIcon: Icon(icon),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: 'Enter your $label',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: Colors.grey.shade500,
              ),
              onPressed: onToggleVisibility,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildBenefitItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.blue.shade600, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}