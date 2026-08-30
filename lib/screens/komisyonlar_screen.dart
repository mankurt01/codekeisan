import 'package:flutter/material.dart';
import 'dart:ui';
import '../routes.dart';

class KomisyonlarScreen extends StatefulWidget {
  const KomisyonlarScreen({super.key});

  @override
  State<KomisyonlarScreen> createState() => _KomisyonlarScreenState();
}

class _KomisyonlarScreenState extends State<KomisyonlarScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // This removes the default back arrow
        title: Text(
          'Komisyonlarım',
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: Color(0xFFED6C02),
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline, size: 22, color: Colors.orange[300]),
            tooltip: 'Yardım',
            onPressed: _showHelpDialog,
          ),
          IconButton(
            icon: Icon(Icons.home, size: 22, color: Colors.orange[300]),
            tooltip: 'Ana Sayfa',
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromRGBO(21, 123, 163, 1.0),
              Color.fromRGBO(146, 74, 26, 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildButton(
                    context,
                    'Komisyon Giriniz',
                    () => Navigator.pushNamed(context, Routes.komisyonEntry),
                  ),
                  const SizedBox(height: 20),
                  _buildButton(
                    context,
                    'Dönem Komisyonları',
                    () => Navigator.pushNamed(context, Routes.komisyonlarTable),
                  ),
                  const SizedBox(height: 20),
                  _buildButton(
                    context,
                    'Girdi Geçmişi',
                    () => Navigator.pushNamed(context, Routes.tumKomisyonlar),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.fromRGBO(21, 123, 163, 1.0),
                      Color.fromRGBO(146, 74, 26, 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24.0),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromRGBO(0, 0, 0, 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.orange[300]!.withAlpha(100),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.only(
                        top: 24.0,
                        bottom: 18.0,
                        left: 24.0,
                        right: 24.0,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color.fromRGBO(21, 123, 163, 1.0),
                            Color.fromRGBO(146, 74, 26, 0.9),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(77),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.help_outline,
                            color: Colors.orange[300],
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Komisyonlar Yardımı',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '💰 Komisyon Sistemi',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Bu bölümde komisyon işlemlerinizi yönetebilirsiniz. Üç ana seçenek bulunmaktadır:',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '📝 Komisyon Giriniz',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '• Günlük komisyon gelirlerinizi girin\n'
                              '• Dış hat ve iç hat komisyonları ayrı ayrı işlenir\n'
                              '• 5 kişi seçeneği ile komisyon oranı değişir (2% vs 2.5%)\n'
                              '• Takvim üzerinden kolayca tarih seçimi yapın',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '📊 Dönem Komisyonları',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '• Aylık komisyon toplamlarınızı görüntüleyin\n'
                              '• Detaylı analiz ve istatistikler\n'
                              '• Grafik gösterimler ile trend analizi',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '📋 Girdi Geçmişi',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '• Tüm komisyon girişlerinizi listeleyin\n'
                              '• Düzenleme ve silme işlemleri\n'
                              '• Tarih bazında filtreleme ve arama',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Footer
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 16.0,
                        bottom: 24.0,
                        left: 24.0,
                        right: 24.0,
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFED6C02),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          'Anladım',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildButton(
    BuildContext context,
    String text,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: 220, // Increased width from 200 to 220
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFED6C02),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Text(
          text,
          textAlign: TextAlign.left, // Added text alignment
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 16),
        ),
      ),
    );
  }
}
