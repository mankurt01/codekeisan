import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../routes.dart'; // Assuming your routes are defined here

class DisclaimerScreen extends StatefulWidget {
  const DisclaimerScreen({super.key});

  @override
  State<DisclaimerScreen> createState() => _DisclaimerScreenState();
}

class _DisclaimerScreenState extends State<DisclaimerScreen> {
  bool _isDisclaimerAccepted = false;

  Future<void> _acceptDisclaimer(BuildContext context) async {
    if (!_isDisclaimerAccepted) {
      return; // Should not happen if button is disabled
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('disclaimer_accepted', true);
    if (context.mounted) {
      // Navigate to the main app screen after accepting
      Navigator.of(context).pushReplacementNamed(Routes.welcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final Color backgroundColor = isDarkMode ? Colors.grey[900]! : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Color appBarBackgroundColor = isDarkMode
        ? Colors.grey[850]!
        : Theme.of(context).primaryColor;
    final Color appBarTextColor = isDarkMode
        ? Colors.white
        : Theme.of(context).colorScheme.onPrimary;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Yasal Uyarı',
          style: TextStyle(
            color: appBarTextColor,
            fontSize: 24,
            fontWeight: FontWeight.w500,
            fontFamily: 'Poppins',
          ),
        ),
        backgroundColor: appBarBackgroundColor,
        automaticallyImplyLeading: false, // Prevent back button
        centerTitle: false,
        iconTheme: IconThemeData(
          color: appBarTextColor,
        ), // For potential future icons
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  'Bu uygulama, yalnızca kullanıcıya tahmini maaş hesaplamaları sunmak amacıyla hazırlanmıştır. Uygulama, herhangi bir resmi kurum, kuruluş veya şirket ile doğrudan ya da dolaylı olarak bağlantılı değildir, bu kurumlar tarafından onaylanmamış veya desteklenmemiştir. Yapılan hesaplamalar yaklaşık değerler olup, çeşitli varsayımlar ve genel bilgiler temel alınarak oluşturulmuştur. Bu nedenle uygulama tarafından sağlanan bilgiler, kesin ve bağlayıcı sonuçlar içermez.\n\n'
                  'Kullanıcılar, bu uygulamada sunulan verileri resmi işlemler, finansal planlama, iş sözleşmeleri veya herhangi bir hukuki karar için dayanak olarak kullanmamalıdır. Gerçek maaş tutarları ve diğer resmi bilgiler için ilgili kurum veya uzmanlardan doğrudan bilgi alınması tavsiye edilir.\n\n'
                  'Uygulama geliştiricisi, bu uygulamada sunulan bilgilerin kullanımından doğabilecek doğrudan veya dolaylı herhangi bir zarar veya kayıptan sorumlu tutulamaz.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Checkbox(
                  value: _isDisclaimerAccepted,
                  onChanged: (bool? value) {
                    setState(() {
                      _isDisclaimerAccepted = value ?? false;
                    });
                  },
                  activeColor: Theme.of(context).colorScheme.primary,
                  checkColor: Theme.of(context).colorScheme.onPrimary,
                  side: BorderSide(color: textColor),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isDisclaimerAccepted = !_isDisclaimerAccepted;
                      });
                    },
                    child: Text(
                      'Okudum, anladım! Kabul ediyorum!',
                      style: textTheme.bodyMedium?.copyWith(color: textColor),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isDisclaimerAccepted
                  ? () => _acceptDisclaimer(context)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isDisclaimerAccepted
                    ? Theme.of(context).colorScheme.primary
                    : Colors
                          .grey, // Use theme's primary color or grey if disabled
                foregroundColor: Theme.of(
                  context,
                ).colorScheme.onPrimary, // Text color on primary
              ),
              child: const Text('Kabul Et ve Devam Et'),
            ),
          ],
        ),
      ),
    );
  }
}
