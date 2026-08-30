import 'package:flutter/material.dart';
import '../services/deep_link_service.dart';

class DeepLinkHandler extends StatefulWidget {
  final Widget child;

  const DeepLinkHandler({super.key, required this.child});

  @override
  State<DeepLinkHandler> createState() => _DeepLinkHandlerState();
}

class _DeepLinkHandlerState extends State<DeepLinkHandler> {
  final DeepLinkService _deepLinkService = DeepLinkService();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    // Initialize deep link service
    await _deepLinkService.init();

    // Listen for deep link events
    _deepLinkService.deepLinkStream.listen((uri) {
      _deepLinkService.handleDeepLink(uri);
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    _deepLinkService.dispose();
    super.dispose();
  }
}
