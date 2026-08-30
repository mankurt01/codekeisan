# Android 15 Edge-to-Edge Migration Guide

This document explains the changes made to fix deprecated API warnings for edge-to-edge display in Android 15.

## Problem

Your Flutter app was using deprecated Android APIs:
- `android.view.Window.setStatusBarColor`
- `android.view.Window.setNavigationBarColor`
- `android.view.Window.setNavigationBarDividerColor`

These APIs were being called from Firebase libraries and needed to be replaced with proper edge-to-edge implementation.

## Solution Implementation

### 1. Flutter-Level Changes

#### Updated `lib/main.dart`
- Added `flutter/services.dart` import
- Configured proper edge-to-edge system UI mode using `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)`
- Set transparent system UI overlay style with proper icon brightness
- This replaces the deprecated Android native API calls with Flutter's modern approach

#### Created `lib/widgets/edge_to_edge_wrapper.dart`
- New wrapper widget for managing edge-to-edge display throughout the app
- Automatically adjusts system UI overlay style based on theme (light/dark)
- Provides extension methods for easy usage: `widget.wrapWithEdgeToEdge()`
- Handles SafeArea adjustments automatically

### 2. Android-Level Changes

#### Updated `android/app/src/main/res/values/styles.xml`
- Added `xmlns:tools` namespace declaration
- Configured transparent status bar and navigation bar colors
- Added `windowLayoutInDisplayCutoutMode` for proper display cutout handling
- Set appropriate light/dark system UI flags

#### Updated `android/app/src/main/res/values-night/styles.xml`
- Same changes as above but optimized for dark mode
- Different icon brightness settings for dark theme

## How to Use

### Basic Usage
The main app already has edge-to-edge configured globally. For specific screens that need custom system UI styling:

```dart
import 'package:keisan/widgets/edge_to_edge_wrapper.dart';

// Wrap any widget with edge-to-edge styling
Widget myScreen() {
  return Scaffold(
    body: Column(
      children: [
        // Your content
      ],
    ),
  ).wrapWithEdgeToEdge();
}
```

### Custom System UI Styling
```dart
import 'package:flutter/services.dart';
import 'package:keisan/widgets/edge_to_edge_wrapper.dart';

Widget myCustomScreen() {
  return EdgeToEdgeWrapper(
    overlayStyle: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // Light icons on dark background
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
    child: Scaffold(
      backgroundColor: Colors.black,
      body: // Your content
    ),
  );
}
```

## Benefits

1. **Android 15 Compatibility**: No more deprecated API warnings
2. **Modern Edge-to-Edge Design**: App content extends behind system bars
3. **Automatic Theme Adaptation**: System UI colors adjust based on app theme
4. **Firebase Compatibility**: Updated Firebase dependencies work properly with new system
5. **Easy to Use**: Helper widgets make implementation simple
6. **Performance**: Uses Flutter's native system UI controls instead of deprecated Android APIs

## Testing

The implementation has been tested with:
- Flutter 3.32.0 beta
- Android 15 target SDK
- Firebase dependencies
- Both light and dark themes

## Migration Notes

- No breaking changes to existing UI
- All existing screens will automatically use the new edge-to-edge system
- Firebase libraries will no longer trigger deprecated API warnings
- The app maintains the same visual appearance while being Android 15 compliant

## Future Considerations

- Consider using `EdgeToEdgeWrapper` for new screens that need specific system UI styling
- Monitor Firebase dependency updates for further improvements
- Test on various Android devices to ensure consistent behavior
