import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:pos/services/auth_service.dart';
import 'package:pos/services/session_audit_service.dart';
import 'package:pos/services/notification_service.dart';
import 'package:pos/models/user.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final SessionAuditService _auditService = SessionAuditService();
  final NotificationService _notificationService = NotificationService();
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

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

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    required String location,
    required String phoneNo,
    required String restaurantName,
    dynamic restaurantLogo,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await _authService.signUp(
        email: email,
        password: password,
        name: name,
        role: role,
        location: location,
        phoneNo: phoneNo,
        restaurantName: restaurantName,
      );

      if (restaurantLogo != null && _currentUser != null) {
        try {
          final logoUrl = await _authService.uploadRestaurantLogo(
            logoFile: restaurantLogo,
            vendorId: _currentUser!.id,
          );
          if (logoUrl != null) {
            await _authService.updateUserLogo(userId: _currentUser!.authUid, logoUrl: logoUrl);
            _currentUser = _copyCurrent(restaurantLogoUrl: logoUrl);
          }
        } catch (e) {
          debugPrint('Logo upload failed: $e');
        }
      }

      if (_currentUser != null) {
        await _auditService.startSession(_currentUser!);
        await _notificationService.publish(
          actor: _currentUser!,
          type: 'work_started',
          title: 'Work started',
          message: '${_currentUser!.name} signed in and started work.',
          severity: 'success',
        );
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

  Future<bool> signIn({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await _authService.signIn(email: email, password: password);
      if (_currentUser == null) return false;
      if (!_currentUser!.isActive) {
        await _authService.signOut();
        _currentUser = null;
        _error = 'This account has been disabled by the administrator.';
        return false;
      }
      await _auditService.startSession(_currentUser!);
      try {
        await _notificationService.publish(
          actor: _currentUser!,
          type: 'work_started',
          title: 'Work started',
          message: '${_currentUser!.name} signed in to ${_currentUser!.branchName}.',
          severity: 'success',
        );
      } catch (e) {
        debugPrint('Login notification failed: $e');
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

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = _currentUser;
      if (user != null) {
        try {
          await _auditService.endSession(user);
          await _notificationService.publish(
            actor: user,
            type: 'work_ended',
            title: 'Work ended',
            message: '${user.name} signed out from ${user.branchName}.',
          );
        } catch (e) {
          debugPrint('Session audit close failed: $e');
        }
      }
      await _authService.signOut();
      _currentUser = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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
      if (_currentUser == null) return false;
      String? logoUrl = _currentUser!.restaurantLogoUrl;
      if (restaurantLogo != null) {
        logoUrl = await _authService.uploadRestaurantLogo(
          logoFile: restaurantLogo,
          vendorId: _currentUser!.id,
        );
        if (logoUrl != null) {
          await _authService.updateUserLogo(userId: _currentUser!.authUid, logoUrl: logoUrl);
        }
      }

      await _authService.updateProfile(
        name: name,
        role: _currentUser!.role,
        isActive: _currentUser!.isActive,
        location: location,
        phoneNo: phoneNo,
        restaurantName: restaurantName,
      );

      _currentUser = _copyCurrent(
        name: name,
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

  UserModel _copyCurrent({
    String? name,
    String? location,
    String? phoneNo,
    String? restaurantName,
    String? restaurantLogoUrl,
  }) {
    final u = _currentUser!;
    return UserModel(
      id: u.id,
      authUid: u.authUid,
      email: u.email,
      name: name ?? u.name,
      role: u.role,
      department: u.department,
      permissions: u.permissions,
      branchId: u.branchId,
      branchName: u.branchName,
      createdAt: u.createdAt,
      isActive: u.isActive,
      trialEndsAt: u.trialEndsAt,
      subscriptionType: u.subscriptionType,
      subscriptionEndsAt: u.subscriptionEndsAt,
      hasActiveSubscription: u.hasActiveSubscription,
      location: location ?? u.location,
      phoneNo: phoneNo ?? u.phoneNo,
      restaurantName: restaurantName ?? u.restaurantName,
      restaurantLogoUrl: restaurantLogoUrl ?? u.restaurantLogoUrl,
    );
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
