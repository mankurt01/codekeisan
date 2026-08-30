// lib/widgets/floating_home_button.dart
import 'package:flutter/material.dart';
import '../routes.dart';

class FloatingHomeButton extends StatelessWidget {
  const FloatingHomeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        Navigator.pushNamedAndRemoveUntil(
          context,
          Routes.welcome,
          (route) => false,
        );
      },
      backgroundColor: Colors.orange[300],
      tooltip: 'Ana Sayfa',
      child: const Icon(Icons.home),
    );
  }
}
