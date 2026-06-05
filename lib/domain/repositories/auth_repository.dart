import '../../core/models/user_profile.dart';

abstract class AuthRepository {
  Future<UserProfile?> getProfile();
  Future<void> saveProfile({required String name, required String college});
  Future<void> login({required String name, required String college});
  Future<void> logout();
  Stream<UserProfile?> get onAuthStateChanged;
  bool get isLoggedIn;
}
