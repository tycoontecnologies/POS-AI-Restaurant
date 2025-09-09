import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos/models/user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    try {
      // Create user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final now = DateTime.now();
      final trialEndsAt = now.add(const Duration(minutes: 3));
      // final trialEndsAt = now.add(const Duration(days: 7));

      // Create user document in Firestore
      final user = UserModel(
        id: userCredential.user!.uid,
        email: email,
        name: name,
        role: role,
        createdAt: now,
        trialEndsAt: trialEndsAt,
        subscriptionType: SubscriptionType.trial,
      );

      await _firestore
          .collection('vendors')
          .doc(userCredential.user!.uid)
          .set(user.toMap());

      return user;
    } catch (e) {
      throw FirebaseAuthException(code: 'signup-failed', message: e.toString());
    }
  }

  // Sign in with email and password
  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Get user data from Firestore
      final userDoc = await _firestore
          .collection('vendors')
          .doc(userCredential.user!.uid)
          .get();

      if (userDoc.exists) {
        return UserModel.fromMap(userDoc.data()!, userDoc.id);
      }

      return null;
    } catch (e) {
      throw FirebaseAuthException(code: 'signin-failed', message: e.toString());
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get current user data
  Future<UserModel?> getCurrentUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final userDoc = await _firestore.collection('vendors').doc(user.uid).get();
    if (userDoc.exists) {
      return UserModel.fromMap(userDoc.data()!, userDoc.id);
    }
    return null;
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Update the sendPasswordResetEmail method in auth_service.dart
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      // More specific error handling
      if (e.code == 'user-not-found') {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No user found with this email address',
        );
      } else {
        throw FirebaseAuthException(
          code: 'reset-password-failed',
          message: e.message ?? 'Failed to send password reset email',
        );
      }
    } catch (e) {
      throw FirebaseAuthException(
        code: 'reset-password-failed',
        message: 'An unexpected error occurred',
      );
    }
  }

  // Update user profile
  Future<void> updateProfile({
    required String name,
    required UserRole role,
    required bool isActive,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('vendors').doc(user.uid).update({
      'name': name,
      'role': role.toString().split('.').last,
      'isActive': isActive,
    });
  }
}
