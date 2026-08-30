import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A wrapper widget that ensures proper edge-to-edge display
/// and handles system UI overlay styles for Android 15 compatibility
class EdgeToEdgeWrapper extends StatelessWidget {
  final Widget child;
  final SystemUiOverlayStyle? overlayStyle;
  final bool automaticSystemUiAdjustment;

  const EdgeToEdgeWrapper({
    super.key,
    required this.child,
    this.overlayStyle,
    this.automaticSystemUiAdjustment = true,
  });

  @override
  Widget build(BuildContext context) {
    // Get the current theme brightness
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    // Default overlay style based on theme and Android version
    final defaultOverlayStyle = SystemUiOverlayStyle(
      // On Android 15+ (API 35+), avoid setting deprecated colors
      statusBarColor: null,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: null,
      systemNavigationBarDividerColor: null,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle ?? defaultOverlayStyle,
      child: automaticSystemUiAdjustment
          ? SafeArea(
              top: false,
              bottom: false,
              child: child,
            )
          : child,
    );
  }
}

/// Extension to easily apply edge-to-edge wrapper to any widget
extension EdgeToEdgeExtension on Widget {
  Widget wrapWithEdgeToEdge({
    SystemUiOverlayStyle? overlayStyle,
    bool automaticSystemUiAdjustment = true,
  }) {
    return EdgeToEdgeWrapper(
      overlayStyle: overlayStyle,
      automaticSystemUiAdjustment: automaticSystemUiAdjustment,
      child: this,
    );
  }
}
