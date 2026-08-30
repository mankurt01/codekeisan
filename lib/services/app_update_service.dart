import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';

class AppUpdateService {
  static const String _minVersionKey = 'min_app_version';
  static const String _forceUpdateKey = 'force_update';
  
  /// Check if app update is required
  /// Returns UpdateCheckResult with update status and version info
  Future<UpdateCheckResult> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuild = packageInfo.buildNumber;
      
      debugPrint('AppUpdateService: Current version: $currentVersion ($currentBuild)');
      
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      
      // Set default values
      await remoteConfig.setDefaults({
        _minVersionKey: currentVersion,
        _forceUpdateKey: false,
      });
      
      // Fetch remote config
      await remoteConfig.fetchAndActivate();
      
      final minVersion = remoteConfig.getString(_minVersionKey);
      final forceUpdate = remoteConfig.getBool(_forceUpdateKey);
      
      debugPrint('AppUpdateService: Remote min version: $minVersion, force update: $forceUpdate');
      
      // Compare versions
      final updateRequired = _isUpdateRequired(currentVersion, minVersion);
      
      return UpdateCheckResult(
        updateRequired: updateRequired,
        forceUpdate: forceUpdate && updateRequired,
        currentVersion: currentVersion,
        minimumVersion: minVersion,
      );
    } catch (e) {
      debugPrint('AppUpdateService: Error checking for update: $e');
      // Return no update required on error to avoid blocking users
      return UpdateCheckResult(
        updateRequired: false,
        forceUpdate: false,
        currentVersion: 'unknown',
        minimumVersion: 'unknown',
      );
    }
  }
  
  /// Compare version strings to determine if update is required
  /// Returns true if currentVersion is less than minVersion
  bool _isUpdateRequired(String currentVersion, String minVersion) {
    try {
      final current = _parseVersion(currentVersion);
      final minimum = _parseVersion(minVersion);
      
      // Compare major.minor.patch
      for (int i = 0; i < 3; i++) {
        if (current[i] < minimum[i]) {
          return true;
        } else if (current[i] > minimum[i]) {
          return false;
        }
      }
      
      return false; // Versions are equal
    } catch (e) {
      debugPrint('AppUpdateService: Error parsing versions: $e');
      return false; // Don't require update if version parsing fails
    }
  }
  
  /// Parse version string into [major, minor, patch] integers
  List<int> _parseVersion(String version) {
    final parts = version.split('.');
    return [
      int.parse(parts.isNotEmpty ? parts[0] : '0'),
      int.parse(parts.length > 1 ? parts[1] : '0'),
      int.parse(parts.length > 2 ? parts[2] : '0'),
    ];
  }
}

class UpdateCheckResult {
  final bool updateRequired;
  final bool forceUpdate;
  final String currentVersion;
  final String minimumVersion;
  
  const UpdateCheckResult({
    required this.updateRequired,
    required this.forceUpdate,
    required this.currentVersion,
    required this.minimumVersion,
  });
  
  @override
  String toString() {
    return 'UpdateCheckResult(updateRequired: $updateRequired, forceUpdate: $forceUpdate, current: $currentVersion, minimum: $minimumVersion)';
  }
}