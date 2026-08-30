import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'dart:developer' as developer;
import 'firebase_options.dart'; // Import generated options
import 'routes.dart'; // Restore routes import
import 'widgets/deep_link_handler.dart';
import 'services/app_update_service.dart';
import 'widgets/update_dialog.dart';
import 'services/auth_session_service.dart';
import 'screens/no_internet_screen.dart';

// Remove imports and providers temporarily moved here
// import 'package:firebase_ui_auth/firebase_ui_auth.dart' as f_ui;
// import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
// final List<f_ui.AuthProvider> providers = [ ... ];

void main() async {
  // Make main async
  WidgetsFlutterBinding.ensureInitialized(); // Ensure bindings are initialized

  // --- Remove timing logs ---
  // final stopwatch = Stopwatch()..start();
  // developer.log('Firebase initializing...', name: 'main');
  await Firebase.initializeApp(
    // Initialize Firebase
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // stopwatch.stop();
  // developer.log('Firebase initialized in ${stopwatch.elapsedMilliseconds}ms', name: 'main');
  // --- End remove timing logs ---

  Logger.root.level = Level.WARNING; // Set appropriate level
  Logger.root.onRecord.listen((record) {
    developer.log(
      '${record.level.name}: ${record.message}',
      time: record.time,
      name: record.loggerName,
      level: record.level.value,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });

  runApp(const SalaryCalculatorApp());
}

class SalaryCalculatorApp extends StatefulWidget {
  const SalaryCalculatorApp({super.key});

  @override
  State<SalaryCalculatorApp> createState() => _SalaryCalculatorAppState();
}

class _SalaryCalculatorAppState extends State<SalaryCalculatorApp> {
  final AppUpdateService _updateService = AppUpdateService();
  bool _updateCheckCompleted = false;
  UpdateCheckResult? _updateResult;
  AuthStartState? _startState;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
    _determineStartState();
  }

  /// Startup auth gate: internet check -> admin bypass -> session restore.
  Future<void> _determineStartState() async {
    try {
      final state = await AuthSessionService.determineStartState();
      developer.log('Start state: $state', name: 'AuthGate');
      if (mounted) setState(() => _startState = state);
    } catch (e) {
      developer.log('Failed to determine start state: $e', name: 'AuthGate');
      if (mounted) setState(() => _startState = AuthStartState.needsLogin);
    }
  }

  Future<void> _checkForUpdates() async {
    try {
      developer.log('Checking for app updates...', name: 'UpdateCheck');
      final result = await _updateService.checkForUpdate();
      developer.log('Update check result: $result', name: 'UpdateCheck');
      
      setState(() {
        _updateResult = result;
        _updateCheckCompleted = true;
      });
      
      // Show update dialog if update is required and widget is mounted
      if (result.updateRequired && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showUpdateDialog(result);
          }
        });
      }
    } catch (e) {
      developer.log('Update check failed: $e', name: 'UpdateCheck');
      // On error, allow app to continue
      setState(() {
        _updateCheckCompleted = true;
      });
    }
  }

  void _showUpdateDialog(UpdateCheckResult result) {
    UpdateDialog.show(
      context,
      currentVersion: result.currentVersion,
      minimumVersion: result.minimumVersion,
      forceUpdate: result.forceUpdate,
      onUpdateLater: result.forceUpdate ? null : () {
        // Allow user to continue with optional updates
        developer.log('User chose to update later', name: 'UpdateCheck');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while checking updates and determining start state
    if (!_updateCheckCompleted || _startState == null) {
      return MaterialApp(
        title: 'Keisan',
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Starting Keisan...'),
              ],
            ),
          ),
        ),
      );
    }

    // Block app if force update is required
    if (_updateResult?.forceUpdate == true) {
      return MaterialApp(
        title: 'Keisan',
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.system_update,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Update Required',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Please update Keisan to the latest version to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => _showUpdateDialog(_updateResult!),
                    icon: const Icon(Icons.download),
                    label: const Text('Update Now'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Block app when there is no internet connection (required for Firebase)
    if (_startState == AuthStartState.noInternet) {
      return MaterialApp(
        title: 'Keisan',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFED6C02),
            primary: const Color(0xFFED6C02),
          ),
          useMaterial3: true,
        ),
        home: NoInternetScreen(onRetry: _determineStartState),
      );
    }

    // Normal app flow - no blocking update required
    return DeepLinkHandler(
      child: MaterialApp(
        title: 'Keisan',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFED6C02),
            primary: const Color(0xFFED6C02),
          ),
          useMaterial3: true,
          // --- Restore textTheme ---
          textTheme: const TextTheme(
            // Large headings
            displayLarge: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
            ),
            displayMedium: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
            ),
            displaySmall: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
            ),
            // Headings
            headlineLarge: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
            ),
            headlineMedium: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
            ),
            headlineSmall: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
            ),
            titleLarge: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.orange,
            ),
            // Body text using Lato
            bodyLarge: TextStyle(
              fontFamily: 'Lato',
              fontSize: 16,
              color: Colors.white,
            ),
            bodyMedium: TextStyle(
              fontFamily: 'Lato',
              fontSize: 14,
              color: Colors.white,
            ),
            bodySmall: TextStyle(
              fontFamily: 'Lato',
              fontSize: 12,
              color: Colors.white,
            ),
          ),
          // --- End restore textTheme ---
        ),
        // --- Ensure initialRoute and routes are correctly set ---      // home: custom_signin.CustomSignInScreen(providers: providers), // Ensure home is removed/commented
        initialRoute: _startState == AuthStartState.needsLogin
            ? Routes.signIn // No valid session -> login screen
            : Routes.welcome, // Session restored or admin bypass -> app
        routes: Routes.routes, // Use named routes map
       // --- End route setup ---
     ),
   );
 }
}
