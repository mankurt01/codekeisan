import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For PlatformException
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:keisan/services/device_auth_service.dart';
import 'package:keisan/services/auth_session_service.dart';

/// A custom authentication service that directly uses Firebase Auth
/// without depending on Firebase Dynamic Links
class CustomAuthService {
  static final CustomAuthService _instance = CustomAuthService._internal();
  factory CustomAuthService() => _instance;
  CustomAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Use proper platform-specific client IDs
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      debugPrint('CustomAuthService.signInWithGoogle: Starting Google sign-in process...');

      // Use web client ID for better compatibility across platforms
      final String serverClientId = '642446362685-muvovvv6tbubgqv2nkn6854a3hpet7ms.apps.googleusercontent.com';

      debugPrint('CustomAuthService.signInWithGoogle: Using web serverClientId: $serverClientId');

      // Initialize GoogleSignIn with web serverClientId
      await _googleSignIn.initialize(
        serverClientId: serverClientId,
      );

      // Start the Google sign-in flow
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      debugPrint('CustomAuthService.signInWithGoogle: Google sign-in successful for: ${googleUser.email}');

      // Get authentication details
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      debugPrint(
        'CustomAuthService.signInWithGoogle: Got Google auth tokens. ID token present: ${googleAuth.idToken != null}',
      );

      // Create credentials
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credentials
      debugPrint('CustomAuthService.signInWithGoogle: Signing into Firebase with Google credential...');
      final userCredential = await _auth.signInWithCredential(credential);
      debugPrint(
        'CustomAuthService.signInWithGoogle: Firebase sign-in successful for: ${userCredential.user?.email}',
      );

      // Verify device after Firebase auth but before completing sign-in
      debugPrint('CustomAuthService.signInWithGoogle: Starting device verification...');
      final deviceAuthService = DeviceAuthService();
      try {
        await deviceAuthService.verifyUserAfterLogin();
        // Persist login info so the session can be restored on next launches
        await AuthSessionService.saveSessionInfo(userCredential.user!);
        debugPrint('CustomAuthService.signInWithGoogle: Device verification completed successfully');
      } catch (e) {
        // If device verification fails, sign out and rethrow
        debugPrint('CustomAuthService.signInWithGoogle: Device verification failed during Google sign-in: $e');
        await _auth.signOut();
        await _googleSignIn.signOut();
        rethrow;
      }

      debugPrint('CustomAuthService.signInWithGoogle: Google sign-in process completed successfully');
      return userCredential;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      // Try to get more details about the error
      if (e is PlatformException) {
        debugPrint(
          'Platform Exception code: ${e.code}, message: ${e.message}, details: ${e.details}',
        );
      }
      rethrow;
    }
  }

  // Sign in with Apple

  Future<UserCredential> signInWithApple() async {
  try {
    debugPrint('Starting Apple sign-in process...');

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      webAuthenticationOptions: WebAuthenticationOptions(
        clientId: 'com.keisan.auth.service',
        redirectUri: Uri.parse(
          'https://keisan-4bf8e.firebaseapp.com/__/auth/handler',
        ),
      ),
    );

    debugPrint('Apple sign-in successful');

    final oauthCredential = OAuthProvider("apple.com").credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    debugPrint('Signing into Firebase with Apple credential...');
    final userCredential = await _auth.signInWithCredential(oauthCredential);
    debugPrint('Firebase sign-in successful for: ${userCredential.user?.email}');

    final deviceAuthService = DeviceAuthService();
    try {
      await deviceAuthService.verifyUserAfterLogin();
      await AuthSessionService.saveSessionInfo(userCredential.user!);
    } catch (e) {
      debugPrint('Device verification failed during Apple sign-in: $e');
      await _auth.signOut();
      rethrow;
    }

    return userCredential;
  } catch (e) {
    debugPrint('Error signing in with Apple: $e');
    rethrow;
  }
}

  // Sign out
  Future<void> signOut() async {
    try {
      await AuthSessionService.clearSessionInfo();
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }
}
