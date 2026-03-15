import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// Manages parent settings and PIN stored in SharedPreferences
class SettingsService {
  static const _settingsKey = 'parent_settings';
  static const _pinHashKey = 'parent_pin_hash';
  static const _activeChildKey = 'active_child_id';

  Future<ParentSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_settingsKey);
    if (jsonStr == null) return ParentSettings();
    return ParentSettings.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
  }

  Future<void> saveSettings(ParentSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final hash = _hashPin(pin);
    await prefs.setString(_pinHashKey, hash);
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_pinHashKey);
    if (storedHash == null) {
      // No PIN set yet — accept any PIN and save it
      await setPin(pin);
      return true;
    }
    return _hashPin(pin) == storedHash;
  }

  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_pinHashKey);
  }

  Future<void> setActiveChild(String childId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeChildKey, childId);
  }

  Future<String?> getActiveChildId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeChildKey);
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }
}

final settingsServiceProvider = Provider<SettingsService>(
  (ref) => SettingsService(),
);
