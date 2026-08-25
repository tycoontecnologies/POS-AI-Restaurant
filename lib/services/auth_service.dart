import 'dart:io' show File;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:pos/models/user.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';

import 'dart:html' as html show File;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    required String location,
    required String phoneNo,
    required String restaurantName,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final now = DateTime.now();
      final trialEndsAt = now.add(const Duration(days: 3));

      final user = UserModel(
        id: userCredential.user!.uid,
        email: email,
        name: name,
        role: role,
        createdAt: now,
        trialEndsAt: trialEndsAt,
        subscriptionType: SubscriptionType.trial,
        location: location,
        phoneNo: phoneNo,
        restaurantName: restaurantName,
      );

      await _firestore.collection('vendors').doc(userCredential.user!.uid).set(user.toMap());
      return user;
    } catch (e) {
      throw FirebaseAuthException(code: 'signup-failed', message: e.toString());
    }
  }

  Future<UserModel?> signIn({required String email, required String password}) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final userDoc = await _firestore.collection('vendors').doc(userCredential.user!.uid).get();
      if (userDoc.exists) return UserModel.fromMap(userDoc.data()!, userDoc.id);
      return null;
    } catch (e) {
      throw FirebaseAuthException(code: 'signin-failed', message: e.toString());
    }
  }

  Future<void> deactivateExpiredTrial(String authUid) async {
    await _firestore.collection('vendors').doc(authUid).set({
      'isActive': false,
      'billingStatus': 'trial_expired',
      'deactivatedAt': FieldValue.serverTimestamp(),
      'deactivationReason': '3-day trial expired without an active subscription',
    }, SetOptions(merge: true));
  }

  Future<void> signOut() async => _auth.signOut();

  Future<UserModel?> getCurrentUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final userDoc = await _firestore.collection('vendors').doc(user.uid).get();
    if (userDoc.exists) return UserModel.fromMap(userDoc.data()!, userDoc.id);
    return null;
  }

  Future<void> resetPassword(String email) async => _auth.sendPasswordResetEmail(email: email);

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw FirebaseAuthException(code: 'user-not-found', message: 'No user found with this email address');
      }
      throw FirebaseAuthException(code: 'reset-password-failed', message: e.message ?? 'Failed to send password reset email');
    } catch (_) {
      throw FirebaseAuthException(code: 'reset-password-failed', message: 'An unexpected error occurred');
    }
  }

  Future<void> updateProfile({required String name, required UserRole role, required bool isActive, required String location, required String phoneNo, required String restaurantName}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('vendors').doc(user.uid).update({
      'name': name,
      'role': role.toString().split('.').last,
      'isActive': isActive,
      'location': location,
      'phoneNo': phoneNo,
      'restaurantName': restaurantName,
    });
  }

  Future<String?> uploadRestaurantLogo({required dynamic logoFile, required String vendorId}) async {
    try {
      final String fileName = 'restaurant_logo_${DateTime.now().millisecondsSinceEpoch}${_getFileExtension(logoFile)}';
      final String storagePath = 'vendors/$vendorId/restaurant_logo/$fileName';
      UploadTask uploadTask;
      if (kIsWeb && logoFile is html.File) {
        final metadata = SettableMetadata(contentType: 'image/${_getMimeType(logoFile)}');
        uploadTask = _storage.ref().child(storagePath).putBlob(logoFile.slice(), metadata);
      } else if (logoFile is File) {
        uploadTask = _storage.ref().child(storagePath).putFile(logoFile);
      } else {
        throw Exception('Unsupported file type');
      }
      final TaskSnapshot snapshot = await uploadTask;
      return snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload restaurant logo: $e');
    }
  }

  String _getFileExtension(dynamic file) {
    if (kIsWeb && file is html.File) {
      final fileName = file.name;
      final dotIndex = fileName.lastIndexOf('.');
      return dotIndex != -1 ? fileName.substring(dotIndex) : '.jpg';
    } else if (file is File) {
      return path.extension(file.path);
    }
    return '.jpg';
  }

  String _getMimeType(html.File file) {
    final type = file.type;
    if (type.isNotEmpty) {
      if (type.contains('jpeg') || type.contains('jpg')) return 'jpeg';
      if (type.contains('png')) return 'png';
      if (type.contains('gif')) return 'gif';
      if (type.contains('bmp')) return 'bmp';
      if (type.contains('webp')) return 'webp';
    }
    return 'jpeg';
  }

  Future<void> updateUserLogo({required String userId, required String logoUrl}) async {
    try {
      await _firestore.collection('vendors').doc(userId).update({
        'restaurantLogoUrl': logoUrl,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to update user logo: $e');
    }
  }
}
