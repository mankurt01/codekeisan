import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import 'device_auth_service.dart';

/// Result of the startup auth gate.
enum AuthStartState {
  /// Valid Firebase session restored (or admin bypass active) — open the app.
  sessionRestored,

  /// No valid session — show the login screen.
  needsLogin,

  /// No internet access — block the app (Firebase is mandatory).
  noInternet,
}

/// Service for managing persisted login state and the startup auth gate.
///
/// Startup decision order (see [determineStartState]):
/// 1. Internet access is mandatory — the app cannot be used offline.
/// 2. Admin bypass active → open directly into the app.
/// 3. Firebase session (persisted token cache) valid AND user still approved
///    in Firestore (isApproved == true) → open directly.
/// 4. Otherwise → login screen.
class AuthSessionService {
  static const String _lastUidKey = 'last_signed_in_uid';
  static const String _lastEmailKey = 'last_signed_in_email';
  static const String _lastSignInAtKey = 'last_signed_in_at';
  // Same key/semantics as NewSignInScreen's 5-day admin bypass.
  static const String _adminBypassKey = 'admin_bypass_until';

  /// Determines where the app should start.
  static Future<AuthStartState> determineStartState() async {
    // 1. Internet check (mandatory — Firebase Auth/Firestore unreachable offline)
    if (!await hasInternetAccess()) {
      debugPrint('AuthSessionService: No internet access — blocking app');
      return AuthStartState.noInternet;
    }

    // 2. Admin bypass → straight into the app
    if (await isAdminBypassActive()) {
      debugPrint('AuthSessionService: Admin bypass active — opening app directly');
      return AuthStartState.sessionRestored;
    }

    // 3. Restored Firebase session?
    if (await hasValidSession()) {
      // 3b. Session valid, but the user may have been revoked (isApproved set
      // to false by an admin) since the last sign-in. Enforce approval here.
      final approved = await DeviceAuthService().isUserApproved();
      if (!approved) {
        debugPrint(
            'AuthSessionService: Session restored but user not approved — opening login screen');
        return AuthStartState.needsLogin;
      }
      debugPrint('AuthSessionService: Valid session restored — opening app directly');
      return AuthStartState.sessionRestored;
    }

    debugPrint('AuthSessionService: No valid session — opening login screen');
    return AuthStartState.needsLogin;
  }

  /// Checks internet connectivity by resolving Firebase's API endpoint.
  static Future<bool> hasInternetAccess() async {
    try {
      final result = await InternetAddress.lookup('firebase.googleapis.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (e) {
      debugPrint('AuthSessionService: Internet check failed: $e');
      return false;
    }
  }

  /// Validates the Firebase session restored from the local token cache.
  ///
  /// Forces a token refresh, which also proves Firebase is reachable.
  static Future<bool> hasValidSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      await user.getIdToken(true).timeout(const Duration(seconds: 10));
      return true;
    } catch (e) {
      debugPrint('AuthSessionService: Session invalid (token refresh failed): $e');
      return false;
    }
  }

  /// Checks the admin bypass set via the sign-in screen (5-day window).
  static Future<bool> isAdminBypassActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final until = prefs.getInt(_adminBypassKey);
      return until != null && DateTime.now().millisecondsSinceEpoch < until;
    } catch (e) {
      debugPrint('AuthSessionService: Bypass check failed: $e');
      return false;
    }
  }

  /// Persists info about the signed-in user (reference/debugging aid;
  /// actual session persistence is handled by the Firebase Auth token cache).
  static Future<void> saveSessionInfo(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastUidKey, user.uid);
      await prefs.setString(_lastEmailKey, user.email ?? '');
      await prefs.setString(_lastSignInAtKey, DateTime.now().toIso8601String());
      debugPrint('AuthSessionService: Session info saved for ${user.email}');
    } catch (e) {
      debugPrint('AuthSessionService: Failed to save session info: $e');
    }
  }

  /// Clears persisted session info (called on sign out).
  static Future<void> clearSessionInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastUidKey);
      await prefs.remove(_lastEmailKey);
      await prefs.remove(_lastSignInAtKey);
      debugPrint('AuthSessionService: Session info cleared');
    } catch (e) {
      debugPrint('AuthSessionService: Failed to clear session info: $e');
    }
  }
}