import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/models/user_profile.dart';
import '../../core/services/app_storage_service.dart';
import '../../domain/repositories/auth_repository.dart';
import '../services/firebase_service.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._storage);

  final AppStorageService _storage;
  final StreamController<UserProfile?> _authStreamController =
      StreamController<UserProfile?>.broadcast();

  UserProfile? _currentProfile;

  @override
  bool get isLoggedIn => _currentProfile != null;

  @override
  Stream<UserProfile?> get onAuthStateChanged => _authStreamController.stream;

  @override
  Future<UserProfile?> getProfile() async {
    if (_currentProfile != null) return _currentProfile;

    if (FirebaseService.isInitialized) {
      try {
        final fb_auth.User? user = fb_auth.FirebaseAuth.instance.currentUser;
        if (user != null) {
          final DocumentSnapshot doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          if (doc.exists && doc.data() != null) {
            _currentProfile = UserProfile.fromMap(doc.data() as Map<String, dynamic>);
            // Update local storage too
            await _storage.saveProfile(_currentProfile!);
            _authStreamController.add(_currentProfile);
            return _currentProfile;
          }
        }
      } catch (e) {
        debugPrint('Error fetching profile from Firestore: $e');
      }
    }

    // Fallback to local storage
    _currentProfile = _storage.readProfile();
    _authStreamController.add(_currentProfile);
    return _currentProfile;
  }

  @override
  Future<void> saveProfile({required String name, required String college}) async {
    final UserProfile profile = UserProfile(name: name, college: college);
    _currentProfile = profile;

    await _storage.saveProfile(profile);

    if (FirebaseService.isInitialized) {
      try {
        final fb_auth.User? user = fb_auth.FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set(profile.toMap(), SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint('Error saving profile to Firestore: $e');
      }
    }

    _authStreamController.add(profile);
  }

  @override
  Future<void> login({required String name, required String college}) async {
    if (FirebaseService.isInitialized) {
      try {
        // Sign in anonymously if not logged in
        fb_auth.UserCredential credential =
            await fb_auth.FirebaseAuth.instance.signInAnonymously();
        final String uid = credential.user!.uid;
        
        final UserProfile profile = UserProfile(name: name, college: college);
        _currentProfile = profile;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(profile.toMap(), SetOptions(merge: true));

        await _storage.saveProfile(profile);
        _authStreamController.add(profile);
        return;
      } catch (e) {
        debugPrint('Firebase Auth login failed: $e. Falling back to local auth.');
      }
    }

    // Local login fallback
    final UserProfile profile = UserProfile(name: name, college: college);
    _currentProfile = profile;
    await _storage.saveProfile(profile);
    _authStreamController.add(profile);
  }

  @override
  Future<void> logout() async {
    _currentProfile = null;
    await _storage.clearProfile();

    if (FirebaseService.isInitialized) {
      try {
        await fb_auth.FirebaseAuth.instance.signOut();
      } catch (e) {
        debugPrint('Error signing out from Firebase: $e');
      }
    }

    _authStreamController.add(null);
  }
}
