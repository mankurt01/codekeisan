import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:io' show Platform;

/// Service for managing unique app identification numbers
/// Replaces device ID dependency with persistent app serial numbers
class AppIdService {
  static final AppIdService _instance = AppIdService._internal();
  factory AppIdService() => _instance;
  AppIdService._internal();

  static const String _appIdKey = 'app_unique_id';
  static const String _generatedAtKey = 'app_id_generated_at';
  static const String _versionKey = 'app_id_version';

  /// Gets or generates a unique app identifier
  /// Format: APP-YYYYMMDD-RRRRRRRRRR
  Future<String> getAppId() async {
    final prefs = await SharedPreferences.getInstance();
    String? existingId = prefs.getString(_appIdKey);

    if (existingId != null && existingId.isNotEmpty) {
      debugPrint('Using existing app ID: $existingId');
      return existingId;
    }

    // Generate new app ID
    final newId = await _generateNewAppId();
    await _storeAppId(newId, prefs);

    debugPrint('Generated new app ID: $newId');
    return newId;
  }

  /// Generates a new unique app identifier
  Future<String> _generateNewAppId() async {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    // Generate 10-digit random number
    final random = Random();
    final randomStr = List.generate(10, (_) => random.nextInt(10)).join();

    return 'APP-$dateStr-$randomStr';
  }

  /// Stores the app ID in local storage
  Future<void> _storeAppId(String appId, SharedPreferences prefs) async {
    await prefs.setString(_appIdKey, appId);
    await prefs.setString(_generatedAtKey, DateTime.now().toIso8601String());
    await prefs.setString(_versionKey, '2.0.0'); // Version for migration tracking
  }

  /// Gets platform information
  String getPlatform() {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }

  /// Clears stored app ID (useful for testing or reset)
  Future<void> clearAppId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_appIdKey);
    await prefs.remove(_generatedAtKey);
    await prefs.remove(_versionKey);
    debugPrint('App ID cleared from local storage');
  }

  /// Gets app ID metadata
  Future<Map<String, String?>> getAppIdMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'appId': prefs.getString(_appIdKey),
      'generatedAt': prefs.getString(_generatedAtKey),
      'version': prefs.getString(_versionKey),
      'platform': getPlatform(),
    };
  }
}