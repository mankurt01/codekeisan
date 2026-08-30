import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppMetadataService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  PackageInfo? _packageInfo;

  // Singleton pattern
  static final AppMetadataService _instance = AppMetadataService._internal();
  factory AppMetadataService() => _instance;
  AppMetadataService._internal();

  /// Gets detailed device and app info
  Future<Map<String, dynamic>> getDeviceDetails() async {
    final Map<String, dynamic> deviceData = <String, dynamic>{};

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceData['platform'] = 'android';
        deviceData['version'] = androidInfo.version.release;
        deviceData['manufacturer'] = androidInfo.manufacturer;
        deviceData['model'] = androidInfo.model;
        deviceData['device'] = androidInfo.device;
        deviceData['isPhysical'] = androidInfo.isPhysicalDevice;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceData['platform'] = 'ios';
        deviceData['version'] = iosInfo.systemVersion;
        deviceData['model'] = iosInfo.model;
        deviceData['name'] = iosInfo.name;
        deviceData['isPhysical'] = iosInfo.isPhysicalDevice;
      }
    } catch (e) {
      debugPrint('Error collecting device data: $e');
    }

    return deviceData;
  }

  /// Initialize package info if not already initialized
  Future<void> _initPackageInfo() async {
    if (_packageInfo == null) {
      try {
        _packageInfo = await PackageInfo.fromPlatform();
      } catch (e) {
        debugPrint('Error initializing package info: $e');
      }
    }
  }

  /// Get app version information
  Future<Map<String, String>> _getAppInfo() async {
    await _initPackageInfo();
    return {
      'version': _packageInfo?.version ?? 'unknown',
      'buildNumber': _packageInfo?.buildNumber ?? 'unknown',
      'packageName': _packageInfo?.packageName ?? 'unknown',
    };
  }

  /// Updates user metadata including device and app info
  Future<void> updateUserMetadata() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final deviceDetails = await getDeviceDetails();
      final appInfo = await _getAppInfo();

      await _firestore.collection('user_metadata').doc(user.uid).set({
        'email': user.email,
        'displayName': user.displayName,
        'lastLogin': FieldValue.serverTimestamp(),
        'deviceInfo': deviceDetails,
        'appVersion': appInfo['version'],
        'buildNumber': appInfo['buildNumber'],
        'packageName': appInfo['packageName'],
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating user metadata: $e');
    }
  }

  /// Public method to get app version string
  Future<String> getAppVersion() async {
    final info = await _getAppInfo();
    return info['version'] ?? 'unknown';
  }
}
