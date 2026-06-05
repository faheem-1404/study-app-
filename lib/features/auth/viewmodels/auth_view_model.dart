import 'package:flutter/foundation.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/app_storage_service.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._storage);

  final AppStorageService _storage;

  UserProfile? _profile;
  bool _isLoading = true;

  bool get isLoading => _isLoading;

  bool get isLoggedIn => _profile != null;

  UserProfile? get profile => _profile;

  Future<void> loadProfile() async {
    _profile = _storage.readProfile();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveProfile({
    required String name,
    required String college,
  }) async {
    final UserProfile profile = UserProfile(name: name, college: college);
    await _storage.saveProfile(profile);
    _profile = profile;
    notifyListeners();
  }

  Future<void> logout() async {
    await _storage.clearProfile();
    _profile = null;
    notifyListeners();
  }
}