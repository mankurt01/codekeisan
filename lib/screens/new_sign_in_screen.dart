import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:keisan/services/custom_auth_service.dart';
import 'package:keisan/services/app_metadata_service.dart';
import 'package:keisan/services/app_id_service.dart';
import 'package:keisan/routes.dart';
import 'package:keisan/constants/support_info.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class NewSignInScreen extends StatefulWidget {
  final Function()? onSignInSuccess;

  const NewSignInScreen({super.key, this.onSignInSuccess});

  @override
  State<NewSignInScreen> createState() => _NewSignInScreenState();
}

String? encodeQueryParameters(Map<String, String> params) {
  return params.entries
      .map(
        (e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
      )
      .join('&');
}

class _NewSignInScreenState extends State<NewSignInScreen> {
  final CustomAuthService _authService = CustomAuthService();

  String? _appVersion;
  bool _isLoading = false;
  String? _errorMessage;

  // Admin bypass logic
  static const String _adminBypassKey = 'admin_bypass_until';
  static const String _adminPassword = '423301'; // Change as needed
  static bool _globalBypassExecuted = false; // Static flag to prevent multiple executions
  static bool _navigationInProgress = false; // Prevent multiple navigation calls
  int _adminTapCount = 0;
  Timer? _adminTapTimer;
  bool _bypassChecked = false;
  bool _bypassExecuted = false;


  @override
  void initState() {
    super.initState();
    _checkAdminBypass();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final version = await AppMetadataService().getAppVersion();
    if (mounted) {
      setState(() {
        _appVersion = version;
      });
    }
  }

  @override
  void dispose() {
    _adminTapTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAdminBypass() async {
    if (_bypassChecked || _bypassExecuted) return;
    _bypassChecked = true;
    
    // Only check bypass if there's no current Firebase user
    if (FirebaseAuth.instance.currentUser != null) {
      debugPrint('Admin bypass: Firebase user already exists, skipping bypass check');
      return;
    }
    
    final prefs = await SharedPreferences.getInstance();
    final until = prefs.getInt(_adminBypassKey);
    
    // Reset global flags if bypass has expired
    if (until == null || DateTime.now().millisecondsSinceEpoch >= until) {
      _globalBypassExecuted = false;
      _navigationInProgress = false;
      debugPrint('Admin bypass: Bypass expired or not found, resetting global flags');
    }
    
    if (until != null && DateTime.now().millisecondsSinceEpoch < until && !_bypassExecuted && !_globalBypassExecuted && !_navigationInProgress) {
      _bypassExecuted = true;
      _globalBypassExecuted = true; // Set static flag to prevent further executions
      _navigationInProgress = true; // Prevent multiple navigation calls
      debugPrint('Admin bypass: Valid bypass found, proceeding with bypass login');
      // Add a small delay to prevent immediate navigation issues
      await Future.delayed(const Duration(milliseconds: 100));
      if (widget.onSignInSuccess != null && mounted) {
        debugPrint('Admin bypass: Calling onSignInSuccess callback from checkAdminBypass');
        try {
          widget.onSignInSuccess!();
          debugPrint('Admin bypass: Automatic navigation callback completed successfully');
          // Add a delay and reset navigation flag to allow other sign-in methods if this doesn't work
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              _navigationInProgress = false;
              debugPrint('Admin bypass: Navigation flag reset after delay');
            }
          });
        } catch (e) {
          debugPrint('Admin bypass: Error during automatic navigation: $e');
          _navigationInProgress = false; // Reset on error
          _globalBypassExecuted = false; // Allow retry on error
        }
      } else {
        debugPrint('Admin bypass: onSignInSuccess is null or widget not mounted in checkAdminBypass');
        _navigationInProgress = false; // Reset if can't navigate
        _globalBypassExecuted = false; // Allow retry
        if (mounted) _navigateAfterSignIn(); // Fallback for named-route usage
      }
    } else {
      debugPrint('Admin bypass: No valid bypass found or already executed (until: $until, current: ${DateTime.now().millisecondsSinceEpoch}, bypassExecuted: $_bypassExecuted, globalBypassExecuted: $_globalBypassExecuted, navigationInProgress: $_navigationInProgress)');
    }
  }

  void _onAdminTap() {
    _adminTapCount++;
    _adminTapTimer?.cancel();
    _adminTapTimer = Timer(const Duration(seconds: 2), () {
      _adminTapCount = 0;
    });
    if (_adminTapCount >= 5) {
      _adminTapCount = 0;
      _showAdminPasswordDialog();
    }
  }

  void _showAdminPasswordDialog() {
    String input = '';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Admin Login'),
          content: TextField(
            autofocus: true,
            obscureText: true,
            maxLength: 6,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Enter 6-digit password',
              counterText: '',
            ),
            onChanged: (value) {
              input = value;
            },
            onSubmitted: (_) => _validateAdminPassword(input),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog first
                _validateAdminPassword(input);
              },
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _validateAdminPassword(String input) async {
    if (input == _adminPassword) {
      if (_navigationInProgress) {
        debugPrint('Admin bypass: Navigation already in progress, skipping');
        return;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final until = DateTime.now().add(const Duration(days: 5)).millisecondsSinceEpoch;
      await prefs.setInt(_adminBypassKey, until);
      _globalBypassExecuted = true; // Set static flag to prevent further executions
      _navigationInProgress = true; // Prevent multiple navigation calls
      debugPrint('Admin bypass: Password validated, bypass activated for 5 days');
      
      // Add a small delay to ensure dialog is closed and context is ready
      await Future.delayed(const Duration(milliseconds: 200));
      
      if (widget.onSignInSuccess != null && mounted) {
        debugPrint('Admin bypass: Calling onSignInSuccess callback');
        try {
          widget.onSignInSuccess!();
          debugPrint('Admin bypass: Navigation callback completed successfully');
          // Add a delay and reset navigation flag to allow other sign-in methods if this doesn't work
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              _navigationInProgress = false;
              debugPrint('Admin bypass: Navigation flag reset after delay from password validation');
            }
          });
        } catch (e) {
          debugPrint('Admin bypass: Error during navigation: $e');
          _navigationInProgress = false; // Reset on error
          _globalBypassExecuted = false; // Allow retry on error
        }
      } else {
        debugPrint('Admin bypass: onSignInSuccess is null or widget not mounted');
        _navigationInProgress = false; // Reset if can't navigate
        _globalBypassExecuted = false; // Allow retry
        if (mounted) _navigateAfterSignIn(); // Fallback for named-route usage
      }
    } else {
      debugPrint('Admin bypass: Incorrect password entered');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect password')),
      );
    }
  }

  /// Navigates into the app after a successful sign-in when no
  /// [NewSignInScreen.onSignInSuccess] callback was provided
  /// (i.e. when this screen is opened as a named route).
  void _navigateAfterSignIn() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.welcome,
      (route) => false,
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithGoogle();
      if (widget.onSignInSuccess != null && mounted) {
        widget.onSignInSuccess!();
      } else if (mounted) {
        _navigateAfterSignIn();
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getReadableErrorMessage(e);
      });
      debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
    } on PlatformException catch (e) {
      setState(() {
        _errorMessage = _getPlatformExceptionMessage(e);
      });
      debugPrint('PlatformException: ${e.code} - ${e.message}');
    } catch (e) {
      setState(() {
        _errorMessage = 'Sign in failed. Please try again later.';
      });
      debugPrint('Generic error during Google sign-in: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithApple();
      if (widget.onSignInSuccess != null && mounted) {
        widget.onSignInSuccess!();
      } else if (mounted) {
        _navigateAfterSignIn();
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getReadableErrorMessage(e);
      });
      debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
    } on PlatformException catch (e) {
      setState(() {
        _errorMessage = _getPlatformExceptionMessage(e);
      });
      debugPrint('PlatformException: ${e.code} - ${e.message}');
    } catch (e) {
      if (e.toString().contains('canceled')) {
        setState(() {
          _errorMessage = 'Apple sign-in was canceled.';
        });
      } else {
        setState(() {
          _errorMessage = 'Apple sign in failed. Please try again later.';
        });
      }
      debugPrint('Apple Sign In Exception: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Helper method to provide user-friendly Firebase Auth error messages
  String _getReadableErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email. Please sign up.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email but different sign-in method.';
      case 'invalid-credential':
        return 'The authentication credentials are invalid.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      default:
        return e.message ?? 'An error occurred during authentication.';
    }
  }

  // Helper method for handling platform-specific exceptions (like Google Sign-In errors)
  String _getPlatformExceptionMessage(PlatformException e) {
    switch (e.code) {
      case 'sign_in_failed':
        return 'Google sign-in failed. Please try again.';
      case 'sign_in_canceled':
        return 'Sign-in was canceled.';
      case 'network_error':
        return 'Network error. Please check your connection.';
      default:
        return e.message ?? 'An error occurred during sign-in.';
    }
  }


  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromRGBO(21, 123, 163, 1.0),
              Color.fromRGBO(146, 74, 26, 0.9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          body: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Stack(
              children: [
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      // Logo or App Name
                      const Text(
                        'Keisan',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // App description
                      const Text(
                        'Sign in to access your account',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 60),

                      // Error Message
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(51),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red.withAlpha(77),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      // Google Sign-In Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _signInWithGoogle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                          icon: _isLoading
                              ? Container(
                                  width: 24,
                                  height: 24,
                                  padding: const EdgeInsets.all(2.0),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFFED6C02),
                                    ),
                                  ),
                                )
                              : Image.asset(
                                  'assets/icons/google_logo.png',
                                  height: 24,
                                  width: 24,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.g_mobiledata, size: 24),
                                ),
                          label: Text(
                            _isLoading
                                ? 'Signing in...'
                                : 'Sign in with Google',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Apple Sign-In Button (iOS only)
                      if (Platform.isIOS)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _signInWithApple,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            icon: _isLoading
                                ? Container(
                                    width: 24,
                                    height: 24,
                                    padding: const EdgeInsets.all(2.0),
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 3,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.apple,
                                    size: 24,
                                    color: Colors.white,
                                  ),
                            label: Text(
                              _isLoading
                                  ? 'Signing in...'
                                  : 'Sign in with Apple',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Account deletion request link
                      TextButton(
                        onPressed: () async {
                          try {
                            final email = SupportInfo.supportEmail;
                            final simpleUri = Uri(
                              scheme: 'mailto',
                              path: email,
                              query:
                                  'subject=Account Deletion Request&body=Please delete my account',
                            );

                            final canLaunch = await canLaunchUrl(simpleUri);
                            if (canLaunch) {
                              await launchUrl(simpleUri);
                            } else {
                              // Fallback to simpler URI format
                              final fallbackUri = Uri.parse('mailto:$email');
                              await launchUrl(fallbackUri);
                            }
                          } catch (e) {
                            debugPrint('Error launching email: $e');
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                        ),
                        child: const Text(
                          'Request Account Deletion',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Support link
TextButton(
  onPressed: () async {
    try {
      final uri = Uri.parse(SupportInfo.supportUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open support page.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching support link: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  },
  style: TextButton.styleFrom(
    foregroundColor: Colors.white70,
  ),
  child: const Text(
    'Need Help? Contact Support',
    style: TextStyle(fontSize: 12),
  ),
),
                        ],
                      ),
                    ),
                  ),
                ),
                // Bottom layout: App Number and Version above, Kanji below, with same alignments
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top row: App Number and Version centered
                      Row(
                        children: [
                          const SizedBox(width: 48), // Left spacer for symmetry
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // App Number button centered
                                TextButton(
                                  onPressed: () async {
                                    final appId = await AppIdService().getAppId();
                                    if (context.mounted) {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('App Number'),
                                          content: SelectableText(
                                            appId,
                                            style: TextStyle(
                                              color: Colors.blue,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(),
                                              child: const Text('Close'),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white70,
                                  ),
                                  child: const Text(
                                    'App Number',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                                // Version number directly below app number
                                Text(
                                  _appVersion != null ? 'Version $_appVersion' : '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 48), // Right spacer for symmetry
                        ],
                      ),
                      const SizedBox(height: 8), // Spacing between rows
                      // Bottom row: Kanji on the left
                      Row(
                        children: [
                          // Kanji on the left
                          Opacity(
                            opacity: 0.2,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16.0),
                              child: GestureDetector(
                                onTap: _onAdminTap,
                                child: const Text(
                                  'マンクルトのアプリ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Spacer to push kanji to the left
                          const Spacer(),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }
}
