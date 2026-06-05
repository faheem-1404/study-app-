import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/redemption_request.dart';
import '../models/user_profile.dart';

class AppStorageService {
  static const String _profileKey = 'studyearn.profile';
  static const String _creditsKey = 'studyearn.credits';
  static const String _todaySecondsKey = 'studyearn.todaySeconds';
  static const String _todayDateKey = 'studyearn.todayDate';
  static const String _redemptionsKey = 'studyearn.redemptions';

  late final SharedPreferences _preferences;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    await _ensureDailyBucket();
  }

  UserProfile? readProfile() {
    final String? rawProfile = _preferences.getString(_profileKey);
    if (rawProfile == null || rawProfile.isEmpty) {
      return null;
    }

    try {
      return UserProfile.fromJson(rawProfile);
    } on FormatException {
      return null;
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _preferences.setString(_profileKey, jsonEncode(profile.toMap()));
  }

  Future<void> clearProfile() async {
    await _preferences.remove(_profileKey);
  }

  double readCredits() {
    return _preferences.getDouble(_creditsKey) ?? 0.0;
  }

  Future<double> addCredits(double value) async {
    final double total = double.parse((readCredits() + value).toStringAsFixed(1));
    await _preferences.setDouble(_creditsKey, total);
    return total;
  }

  Future<double> subtractCredits(double value) async {
    final double total = double.parse((readCredits() - value).toStringAsFixed(1));
    final double safeTotal = total < 0 ? 0.0 : total;
    await _preferences.setDouble(_creditsKey, safeTotal);
    return safeTotal;
  }

  int readTodayStudySeconds() {
    return _preferences.getInt(_todaySecondsKey) ?? 0;
  }

  Future<int> addTodayStudySeconds(int value) async {
    await _ensureDailyBucket();
    final int total = readTodayStudySeconds() + value;
    await _preferences.setInt(_todaySecondsKey, total);
    return total;
  }

  Future<void> resetWallet() async {
    await _preferences.remove(_creditsKey);
    await _preferences.remove(_todaySecondsKey);
    await _preferences.remove(_todayDateKey);
    await _preferences.remove(_redemptionsKey);
    await _ensureDailyBucket();
  }

  List<RedemptionRequest> readRedemptions() {
    final List<String> raw = _preferences.getStringList(_redemptionsKey) ?? <String>[];
    return raw
        .map((String item) => RedemptionRequest.fromJson(item))
        .toList()
      ..sort((RedemptionRequest a, RedemptionRequest b) =>
          b.createdAt.compareTo(a.createdAt));
  }

  Future<void> saveRedemptions(List<RedemptionRequest> redemptions) async {
    await _preferences.setStringList(
      _redemptionsKey,
      redemptions.map((RedemptionRequest request) => request.toJson()).toList(),
    );
  }

  Future<void> _ensureDailyBucket() async {
    final String todayStamp = _todayStamp();
    final String? storedStamp = _preferences.getString(_todayDateKey);
    if (storedStamp != todayStamp) {
      await _preferences.setString(_todayDateKey, todayStamp);
      await _preferences.setInt(_todaySecondsKey, 0);
    }
  }

  String _todayStamp() {
    final DateTime now = DateTime.now();
    final String month = now.month.toString().padLeft(2, '0');
    final String day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }
}