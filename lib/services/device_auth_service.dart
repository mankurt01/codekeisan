import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:keisan/services/app_id_service.dart';

class DeviceAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppIdService _appIdService = AppIdService();

  // Singleton pattern
  static final DeviceAuthService _instance = DeviceAuthService._internal();
  factory DeviceAuthService() => _instance;
  DeviceAuthService._internal();

  /// Checks if the current user is registered and approved
  Future<bool> isUserApproved() async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return false;

      final docRef = _firestore
          .collection('user_registrations')
          .doc(user.email);
      final doc = await docRef.get();

      if (!doc.exists) return false;

      final data = doc.data();
      final isApproved = data?['isApproved'] as bool? ?? false;
      
      debugPrint('DeviceAuthService.isUserApproved: User ${user.email} approved: $isApproved');
      return isApproved;
    } catch (e) {
      debugPrint('Failed to check user approval status: $e');
      return false;
    }
  }

  /// Registers the current user with their app ID
  /// Implements the registration logic:
  /// - If email exists with different app id → DENY
  /// - If both exist with same mapping → ALLOW
  /// - If neither exists → CREATE NEW
  Future<void> registerUser() async {
    final user = _auth.currentUser;
    debugPrint('DeviceAuthService.registerUser: Starting registration for user: ${user?.email}');
    
    if (user == null || user.email == null) {
      throw Exception('Aktif kullanıcı bulunamadı veya e-posta bilgisi eksik.');
    }

    final currentAppId = await _appIdService.getAppId();
    debugPrint('DeviceAuthService.registerUser: Current app ID: $currentAppId');

    // Check if this email already has a registration
    final userRegDocRef = _firestore
        .collection('user_registrations')
        .doc(user.email);
    
    final userRegDoc = await userRegDocRef.get();

    if (userRegDoc.exists) {
      final registrationData = userRegDoc.data();
      final registeredAppId = registrationData?['appId'] as String?;
      final isApproved = registrationData?['isApproved'] as bool? ?? false;
      
      debugPrint('DeviceAuthService.registerUser: Existing registration found - appId: $registeredAppId, approved: $isApproved');

      if (registeredAppId == currentAppId) {
        // CASE: Both exist with same mapping → ALLOW
        debugPrint('DeviceAuthService.registerUser: Email and app mapping exists - updating timestamp');
        
        await userRegDocRef.update({
          'lastUsedAt': FieldValue.serverTimestamp(),
        });
        
        if (!isApproved) {
          throw Exception(
            'Uygulamanız henüz onaylanmamış. Lütfen onay sürecinin tamamlanmasını bekleyin.',
          );
        }
        
        debugPrint('DeviceAuthService.registerUser: User approved and timestamp updated');
        return;
      } else {
        // CASE: Email exists with different app id → DENY
        debugPrint('DeviceAuthService.registerUser: Email registered to different app - DENYING access');
        throw Exception(
          'Bu e-posta (${user.email}) zaten farklı bir uygulama ($registeredAppId) ile kayıtlı. Her e-posta sadece bir uygulama ile eşleştirilebilir.',
        );
      }
    }

    // CASE: Neither exists → CREATE NEW
    debugPrint('DeviceAuthService.registerUser: Creating new registration for ${user.email} with app $currentAppId');
    
    final registrationData = {
      'email': user.email,
      'userId': user.uid,
      'appId': currentAppId,
      'registeredAt': FieldValue.serverTimestamp(),
      'lastUsedAt': FieldValue.serverTimestamp(),
      'isApproved': true, // Default to false - requires admin approval
    };

    try {
      await userRegDocRef.set(registrationData);
      debugPrint('DeviceAuthService.registerUser: New registration created successfully');
      
      // Throw exception to indicate approval is needed
      throw Exception(
        'Uygulama başarıyla kaydedildi ancak admin onayı bekleniyor. Lütfen onay sürecinin tamamlanmasını bekleyin.',
      );
    } catch (e) {
      debugPrint('DeviceAuthService.registerUser: Error during registration: $e');
      // Re-throw if it's our approval message
      if (e.toString().contains('admin onayı bekleniyor')) {
        rethrow;
      }
      throw Exception('Uygulama kaydı sırasında bilinmeyen bir hata oluştu: $e');
    }
  }

  /// Verifies the user after Firebase authentication and registers them if necessary
  Future<void> verifyUserAfterLogin() async {
    final user = _auth.currentUser;
    debugPrint('DeviceAuthService.verifyUserAfterLogin: Starting verification for user: ${user?.email}');
    
    if (user == null || user.email == null) {
      throw Exception('Aktif kullanıcı bulunamadı veya e-posta eksik.');
    }

    try {
      await registerUser();
      debugPrint('DeviceAuthService.verifyUserAfterLogin: User registration/verification completed');
    } catch (e) {
      debugPrint('DeviceAuthService.verifyUserAfterLogin: Registration failed: $e');
      rethrow;
    }
  }

  /// Updates the last used timestamp for the current user
  Future<void> updateLastUsedTimestamp() async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return;

      final userRegDocRef = _firestore
          .collection('user_registrations')
          .doc(user.email);
      
      await userRegDocRef.update({
        'lastUsedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('DeviceAuthService.updateLastUsedTimestamp: Timestamp updated for ${user.email}');
    } catch (e) {
      debugPrint('Failed to update last used timestamp: $e');
    }
  }

  /// Gets the current user's registration info
  Future<Map<String, dynamic>> getUserRegistrationInfo() async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        return {'appId': null, 'isApproved': false, 'email': null};
      }

      final appId = await _appIdService.getAppId();
      final userRegDoc = await _firestore
          .collection('user_registrations')
          .doc(user.email)
          .get();

      if (userRegDoc.exists) {
        final data = userRegDoc.data();
        return {
          'appId': data?['appId'],
          'isApproved': data?['isApproved'] ?? false,
          'email': data?['email'],
          'registeredAt': data?['registeredAt'],
          'userId': data?['userId'],
        };
      }

      return {
        'appId': appId,
        'isApproved': false,
        'email': user.email,
        'registeredAt': null,
        'userId': user.uid,
      };
    } catch (e) {
      debugPrint('Failed to get user registration info: $e');
      return {'appId': null, 'isApproved': false, 'email': null};
    }
  }
}
