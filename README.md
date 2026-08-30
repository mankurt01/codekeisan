# Keisan

Keisan is a Flutter-based mobile application designed to help airline employees analyze their roster (shift) PDF files and automate salary calculations. The app provides a secure, privacy-focused experience with support for Google and Apple sign-in, PDF parsing, and local/remote data storage.

## Features

- **Roster PDF Analysis:** Upload and analyze airline roster files in PDF format.
- **Automated Salary Calculation:** Instantly calculate salaries based on roster data.
- **Multi-Platform Support:** Available for both Android and iOS.
- **Authentication:** Google Sign-In and Apple Sign-In support.
- **Data Privacy:** User data is stored securely, with sensitive information encrypted and most data kept on-device.
- **Statistics & History:** View past salary calculations and roster history.
- **Export & Import:** Export data to PDF or other formats; import previous data.
- **Notifications:** Receive updates and important notifications.
- **Single Device Policy:** Each account can only be used on one device at a time.

## Project Structure

- `lib/` - Main application source code
  - `screens/` - UI screens (salary, roster, statistics, etc.)
  - `services/` - Business logic and integrations (authentication, PDF parsing, data storage, etc.)
  - `models/` - Data models (salary, roster, PDF results)
  - `widgets/` - Reusable UI components
  - `utils/` - Utility functions
  - `constants/` - Static configuration and limits
- `assets/` - App icons, fonts, and images
- `android/`, `ios/` - Platform-specific code and configuration
- `test/` - Unit and widget tests

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (>=3.9.0 <4.0.0)
- Android Studio or Xcode for platform builds

### Installation

1. Clone the repository:
   ```sh
   git clone https://github.com/mankurt01/keisan.git
   cd keisan
   ```
2. Install dependencies:
   ```sh
   flutter pub get
   ```
3. Run the app:
   ```sh
   flutter run
   ```

### Configuration

- Firebase is required for authentication and data storage. Set up your own Firebase project and update `firebase_options.dart` as needed.
- App icons and splash screens are configured via `flutter_launcher_icons` and `flutter_native_splash`.

## Dependencies

- Firebase (Core, Auth, Firestore, Storage, Messaging, Remote Config)
- PDF parsing and generation (`pdf`, `syncfusion_flutter_pdf`)
- File picker, provider, shared_preferences, intl, and more

See `pubspec.yaml` for the full list.

## Privacy & Compliance

- User data is handled according to strict privacy standards. See [PRIVACY_POLICY.md](PRIVACY_POLICY.md) for details.
- Only essential data is collected, and most is stored locally on the device.
- The app complies with GDPR and KVKK regulations.

## Documentation

- [PRIVACY_POLICY.md](PRIVACY_POLICY.md)
- [ENCRYPTION_COMPLIANCE_DOCUMENTATION.md](ENCRYPTION_COMPLIANCE_DOCUMENTATION.md)
- [APP_STORE_REVIEWER_NOTES.md](APP_STORE_REVIEWER_NOTES.md)
- [ANDROID_15_EDGE_TO_EDGE_MIGRATION.md](ANDROID_15_EDGE_TO_EDGE_MIGRATION.md)
- [DEEP_LINK_DEPLOYMENT_SUMMARY.md](DEEP_LINK_DEPLOYMENT_SUMMARY.md)

## License

© 2024 Keisan. All rights reserved.

---

**Disclaimer:** This application provides estimated salary calculations. Results are approximate and not official. For official salary information, consult your employer or relevant authorities.
