import 'package:flutter/material.dart' hide MenuItemButton;
import 'package:flutter_animate/flutter_animate.dart';
import '../routes.dart';
import 'welcome_screen.dart';

/// "Geçmiş" hub screen that groups the history-related screens:
/// Roster Dökümleri and Geçmiş Maaşlarım.
class GecmisScreen extends StatelessWidget {
  const GecmisScreen({super.key});

  static const List<MenuItem> items = [
    MenuItem("Roster Dökümleri", Icons.list_alt, Routes.rosterHistory,
        MenuCategory.history),
    MenuItem("Geçmiş Maaşlarım", Icons.history, Routes.gecmisMaaslar,
        MenuCategory.history),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Geçmiş',
          style: TextStyle(
            color: Color(0xFFED6C02),
            fontSize: 24,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
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
        child: SafeArea(
          bottom: false,
          child: GridView.builder(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: items.length,
            itemBuilder: (BuildContext context, int index) {
              final item = items[index];
              return NeumorphicCard(
                child: MenuItemButton(
                  item: item,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CategoryIndicator(category: item.category),
                      const SizedBox(height: 12),
                      Hero(
                        tag: 'icon-${item.route}',
                        child: Icon(
                          item.icon,
                          color: const Color(0xFFED6C02),
                          size: 32,
                        )
                            .animate(
                              onPlay: (controller) => controller.repeat(),
                            )
                            .shimmer(
                              duration: 2.seconds,
                              delay: 500.milliseconds,
                              color: const Color.fromRGBO(255, 255, 255, 0.5),
                            )
                            .scale(
                              duration: 1.5.seconds,
                              begin: const Offset(0.95, 0.95),
                              end: const Offset(1.05, 1.05),
                              curve: Curves.easeInOut,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(
                    delay: Duration(milliseconds: 100 * index),
                    duration: 400.ms,
                  )
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.0, 1.0),
                    delay: Duration(milliseconds: 100 * index),
                    curve: Curves.easeOut,
                  );
            },
          ),
        ),
      ),
    );
  }
}
