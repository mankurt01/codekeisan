import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;

class UpdateDialog extends StatelessWidget {
  final String currentVersion;
  final String minimumVersion;
  final bool forceUpdate;
  final VoidCallback? onUpdateLater;

  const UpdateDialog({
    super.key,
    required this.currentVersion,
    required this.minimumVersion,
    required this.forceUpdate,
    this.onUpdateLater,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !forceUpdate,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.system_update,
              color: Theme.of(context).primaryColor,
              size: 28,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Update Available',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              forceUpdate
                  ? 'A critical update is required to continue using the app.'
                  : 'A new version of Keisan is available.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Current Version:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        currentVersion,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Required Version:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        minimumVersion,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (forceUpdate) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'This update is mandatory for security and functionality.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!forceUpdate && onUpdateLater != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onUpdateLater!();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
              ),
              child: const Text('Update Later'),
            ),
          ElevatedButton.icon(
            onPressed: () => _launchAppStore(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.download, size: 20),
            label: const Text(
              'Update Now',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      ),
    );
  }

  Future<void> _launchAppStore(BuildContext context) async {
    try {
      late String storeUrl;
      
      if (Platform.isIOS) {
        // iOS App Store URL - replace with your actual app ID
        storeUrl = 'https://apps.apple.com/app/keisan/id6738291850';
      } else {
        // Android Play Store URL - replace with your actual package name
        storeUrl = 'https://play.google.com/store/apps/details?id=com.keisan.app';
      }

      final uri = Uri.parse(storeUrl);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw Exception('Could not launch app store');
      }
    } catch (e) {
      debugPrint('Error launching app store: $e');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open app store. Please search for "Keisan" in your app store.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Show the update dialog
  static Future<void> show(
    BuildContext context, {
    required String currentVersion,
    required String minimumVersion,
    required bool forceUpdate,
    VoidCallback? onUpdateLater,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) => UpdateDialog(
        currentVersion: currentVersion,
        minimumVersion: minimumVersion,
        forceUpdate: forceUpdate,
        onUpdateLater: onUpdateLater,
      ),
    );
  }
}