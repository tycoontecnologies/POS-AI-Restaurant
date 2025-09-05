import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos/providers/auth_provider.dart';

class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSuccess = false;


  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: true);

    return AlertDialog(
      title: Text(_isSuccess ? 'Check Your Email' : 'Reset Password'),
      content: _isSuccess
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'If an account exists for ${_emailController.text}, we\'ve sent a password reset link to your email address.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'Please check your inbox and spam folder.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            )
          : Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Enter your email address and we\'ll send you a link to reset your password.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email address',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  if (authProvider.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        authProvider.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
      actions: _isSuccess
          ? [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ]
          : [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: authProvider.isLoading
                    ? null
                    : () async {
                        if (_formKey.currentState!.validate()) {
                          final success = await authProvider.sendPasswordResetEmail(
                            _emailController.text.trim(),
                          );
                          
                          if (success) {
                            setState(() {
                              _isSuccess = true;
                            });
                          }
                        }
                      },
                child: authProvider.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send Reset Link'),
              ),
            ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}