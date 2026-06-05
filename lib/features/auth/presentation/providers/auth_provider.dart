import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/user_profile.dart';
import '../../../../core/providers/providers.dart';
import '../../../../domain/repositories/auth_repository.dart';

class AuthState {
  const AuthState({this.profile, this.isLoading = true});

  final UserProfile? profile;
  final bool isLoading;

  bool get isLoggedIn => profile != null;
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthState()) {
    loadProfile();
  }

  final AuthRepository _repository;

  Future<void> loadProfile() async {
    state = const AuthState(profile: null, isLoading: true);
    final profile = await _repository.getProfile();
    state = AuthState(profile: profile, isLoading: false);
  }

  Future<void> saveProfile({required String name, required String college}) async {
    state = AuthState(profile: state.profile, isLoading: true);
    await _repository.saveProfile(name: name, college: college);
    state = AuthState(profile: UserProfile(name: name, college: college), isLoading: false);
  }

  Future<void> login({required String name, required String college}) async {
    state = const AuthState(profile: null, isLoading: true);
    await _repository.login(name: name, college: college);
    final profile = await _repository.getProfile();
    state = AuthState(profile: profile, isLoading: false);
  }

  Future<void> logout() async {
    state = const AuthState(profile: null, isLoading: true);
    await _repository.logout();
    state = const AuthState(profile: null, isLoading: false);
  }
}

/// Global AuthController Provider
final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(repository);
});
