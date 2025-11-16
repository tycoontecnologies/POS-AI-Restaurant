import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:pos/services/auth_service.dart';
import 'package:pos/models/user.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  // auth_provider.dart - Ensure initialize method sets loading correctly
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = await _authService.getCurrentUserData();
      _error = null;
    } catch (e) {
      _error = e.toString();
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update the signUp method in AuthProvider
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    required String location,
    required String phoneNo,
    required String restaurantName,
    dynamic restaurantLogo, // New optional parameter
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // First create the user account
      _currentUser = await _authService.signUp(
        email: email,
        password: password,
        name: name,
        role: role,
        location: location,
        phoneNo: phoneNo,
        restaurantName: restaurantName,
      );

      // If logo is provided, upload it and update user document
      if (restaurantLogo != null && _currentUser != null) {
        try {
          final logoUrl = await _authService.uploadRestaurantLogo(
            logoFile: restaurantLogo,
            vendorId: _currentUser!.id,
          );

          // Update user document with logo URL
          if (logoUrl != null) {
            await _authService.updateUserLogo(
              userId: _currentUser!.id,
              logoUrl: logoUrl,
            );

            // Update current user with logo URL
            _currentUser = UserModel(
              id: _currentUser!.id,
              email: _currentUser!.email,
              name: _currentUser!.name,
              role: _currentUser!.role,
              createdAt: _currentUser!.createdAt,
              isActive: _currentUser!.isActive,
              trialEndsAt: _currentUser!.trialEndsAt,
              subscriptionType: _currentUser!.subscriptionType,
              subscriptionEndsAt: _currentUser!.subscriptionEndsAt,
              hasActiveSubscription: _currentUser!.hasActiveSubscription,
              location: _currentUser!.location,
              phoneNo: _currentUser!.phoneNo,
              restaurantName: _currentUser!.restaurantName,
              restaurantLogoUrl: logoUrl,
            );
          }
        } catch (e) {
          // Log logo upload error but don't fail the signup
          print('Logo upload failed: $e');
        }
      }

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign in
  Future<bool> signIn({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await _authService.signIn(
        email: email,
        password: password,
      );
      return _currentUser != null;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign out
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();
      _currentUser = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.resetPassword(email);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add this method to your AuthProvider class
  Future<bool> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.sendPasswordResetEmail(email);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update profile
  Future<bool> updateProfile({
    required String name,
    required String location,
    required String phoneNo,
    required String restaurantName,
    dynamic restaurantLogo,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Upload logo if provided
      String? logoUrl = _currentUser?.restaurantLogoUrl;
      if (restaurantLogo != null && _currentUser != null) {
        logoUrl = await _authService.uploadRestaurantLogo(
          logoFile: restaurantLogo,
          vendorId: _currentUser!.id,
        );
        if (logoUrl != null) {
          await _authService.updateUserLogo(
            userId: _currentUser!.id,
            logoUrl: logoUrl,
          );
        }
      }

      // Update profile data
      await _authService.updateProfile(
        name: name,
        role: _currentUser!.role,
        isActive: _currentUser!.isActive,
        location: location,
        phoneNo: phoneNo,
        restaurantName: restaurantName,
      );

      // Update current user
      _currentUser = UserModel(
        id: _currentUser!.id,
        email: _currentUser!.email,
        name: name,
        role: _currentUser!.role,
        createdAt: _currentUser!.createdAt,
        isActive: _currentUser!.isActive,
        trialEndsAt: _currentUser!.trialEndsAt,
        subscriptionType: _currentUser!.subscriptionType,
        subscriptionEndsAt: _currentUser!.subscriptionEndsAt,
        hasActiveSubscription: _currentUser!.hasActiveSubscription,
        location: location,
        phoneNo: phoneNo,
        restaurantName: restaurantName,
        restaurantLogoUrl: logoUrl,
      );

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
