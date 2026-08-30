import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

class DeepLinkService {
  static const String _deepLinkPatchesKey = 'deep_link_patches';
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _deepLinkStreamController = StreamController<Uri>.broadcast();
  Stream<Uri> get deepLinkStream => _deepLinkStreamController.stream;

  // Remote config instance
  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  Map<String, dynamic> _patches = {};

  // Add a platform method channel to listen for deep links
  static const platform = MethodChannel('com.keisan.app/deep_links');

  // Initialize listeners
  Future<void> init() async {
    // Initialize remote config
    await _initializeRemoteConfig();
    // Listen for deep links when app is already running
    platform.setMethodCallHandler((call) async {
      if (call.method == 'handleDeepLink') {
        final link = call.arguments as String?;
        if (link != null) {
          final uri = Uri.parse(link);
          _deepLinkStreamController.add(uri);
        }
      }
    });

    // Check if app was opened from a deep link
    try {
      final initialLink = await platform.invokeMethod<String>(
        'getInitialDeepLink',
      );
      if (initialLink != null) {
        _deepLinkStreamController.add(Uri.parse(initialLink));
      }
    } on PlatformException catch (e) {
      debugPrint('Error getting initial deep link: ${e.message}');
    } on MissingPluginException {
      // No native implementation for deep links on this platform.
      debugPrint('Deep link plugin not available; skipping initial deep link check.');
    }
  }

  // Initialize Remote Config
  Future<void> _initializeRemoteConfig() async {
    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));

      // Set default values
      await _remoteConfig.setDefaults({
        _deepLinkPatchesKey: '{}',
      });
      
      // Fetch and activate
      await _remoteConfig.fetchAndActivate();
      _updatePatches();
      
      // Listen for remote config updates
      _remoteConfig.onConfigUpdated.listen((event) async {
        await _remoteConfig.activate();
        _updatePatches();
      });

      debugPrint('Remote config initialized successfully');
    } catch (e) {
      debugPrint('Error initializing remote config: $e');
    }
  }

  // Update patches from remote config
  void _updatePatches() {
    try {
      final patchesJson = _remoteConfig.getString(_deepLinkPatchesKey);
      if (patchesJson.isNotEmpty) {
        _patches = Map<String, dynamic>.from(json.decode(patchesJson));
        debugPrint('Updated deep link patches: $_patches');
      }
    } catch (e) {
      debugPrint('Error updating patches: $e');
      // Ensure patches is empty on error
      _patches = {};
    }
  }

  // Helper method to handle different types of deep links
  void handleDeepLink(Uri uri) {
    // Log the incoming deep link for debugging
    debugPrint('Received deep link: $uri');

    // Check for patched handling first
    final patchedHandler = _getPatchedHandler(uri);
    if (patchedHandler != null) {
      debugPrint('Using patched handler for: $uri');
      return;
    }

    // Default handling if no patch exists
    if (uri.path.contains('login') ||
        uri.path.contains('auth') ||
        uri.path.contains('signin') ||
        uri.path.contains('sign-in')) {
      debugPrint('Handling auth deep link: $uri');
      // The Firebase Auth SDK will pick up these links automatically
      // No need to manually navigate for OAuth redirects
    } else if (uri.path.contains('reset-password')) {
      // Handle password reset
      debugPrint('Handling password reset deep link: $uri');
      // Navigate to password reset screen
    } else if (uri.path.contains('__/auth/')) {
      // This is a Firebase Auth redirect pattern
      debugPrint('Handling Firebase Auth deep link: $uri');
      // Firebase Auth SDK will handle this
    } else {
      // Handle other links
      debugPrint('Handling general deep link: $uri');
    }
  }

  // Check for patched handling of deep links
  dynamic _getPatchedHandler(Uri uri) {
    if (_patches.isEmpty) return null;

    for (final patch in _patches.entries) {
      final pattern = patch.key;
      if (RegExp(pattern).hasMatch(uri.toString())) {
        final patchConfig = patch.value;
        try {
          if (patchConfig is Map<dynamic, dynamic>) {
            // Convert the dynamic Map to Map<String, dynamic>
            final typedConfig = Map<String, dynamic>.from(patchConfig);
            // Handle the deep link according to patch configuration
            _handlePatchedDeepLink(uri, typedConfig);
            return true;
          }
        } catch (e) {
          debugPrint('Error handling patched deep link: $e');
        }
      }
    }
    return null;
  }

  // Handle deep link according to patch configuration
  void _handlePatchedDeepLink(Uri uri, Map<String, dynamic> config) {
    final action = config['action'] as String?;
    final params = config['params'] as Map<String, dynamic>?;

    switch (action) {
      case 'redirect':
        if (params?['url'] != null) {
          launchURL(params!['url']);
        }
        break;
      case 'block':
        debugPrint('Deep link blocked by patch: $uri');
        break;
      // Add more patch actions as needed
    }
  }

  // Method to create authentication link
  static Future<String> createAuthLink(String email) async {
    // Use the firebaseapp.com domain as that's what is configured in the iOS Info.plist
    final url =
        'https://keisan-4bf8e.firebaseapp.com/auth?email=${Uri.encodeComponent(email)}';
    return url;
  }

  // Method to open links externally
  static Future<bool> launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
    return true;
  }

  void dispose() {
    _deepLinkStreamController.close();
  }

  // Force fetch latest patches
  Future<bool> refreshPatches() async {
    try {
      await _remoteConfig.fetch();
      final activated = await _remoteConfig.activate();
      if (activated) {
        _updatePatches();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error refreshing patches: $e');
      return false;
    }
  }

  // Get current patches for debugging
  Map<String, dynamic> get currentPatches => Map<String, dynamic>.from(_patches);
}
