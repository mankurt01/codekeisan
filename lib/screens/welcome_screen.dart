import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../routes.dart';
import 'package:keisan/constants/support_info.dart';
import 'package:url_launcher/url_launcher.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    this.items = const [
      MenuItem("Roster Yükle", Icons.upload_file, Routes.pdfUpload,
          MenuCategory.action),
      MenuItem("Roster Takvimi", Icons.calendar_month, Routes.rosterTakvimi,
          MenuCategory.action),
      MenuItem("Geçmiş", Icons.history, Routes.gecmis, MenuCategory.history),
      MenuItem("Komisyonlarım", Icons.monetization_on, Routes.komisyonlar,
          MenuCategory.finance),
      MenuItem("Hesapla", Icons.data_usage, Routes.baseMaas, MenuCategory.data),
      MenuItem("Yardım", Icons.help_outline, Routes.help,
          MenuCategory.help),
      MenuItem("İstatistikler", Icons.bar_chart, Routes.statistics, MenuCategory.data),
      //MenuItem("Duty Time Hesapla", Icons.access_time, Routes.dutyTimeCalculator, MenuCategory.data),
      //MenuItem("SHGM FTL", Icons.assignment_turned_in, "/shgmFtl", MenuCategory.data),
      MenuItem("Merak", Icons.lightbulb, Routes.merak, MenuCategory.data),
    ],
  });

  static const routeName = '/';
  final List<MenuItem> items;

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (bounds) {
            return const LinearGradient(
              colors: [
                Color(0xFFED6C02),
                Color(0xFFFFA726),
                Color(0xFFED6C02),
              ],
              stops: [0.0, 0.5, 1.0],
              tileMode: TileMode.mirror,
            ).createShader(bounds);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: 'KEISAN'.split('').map((char) {
              return Text(
                char,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Color(0xFF924A1A),
                      blurRadius: 4,
                      offset: Offset(1, 1),
                    ),
                  ],
                ),
              )
                  .animate(
                    onPlay: (controller) => controller.repeat(),
                  )
                  .shimmer(
                    duration: 3.seconds,
                    delay: 1.seconds,
                    color: const Color(0xFFFFA726),
                  )
                  .scaleXY(
                    begin: 0.8,
                    end: 1.2,
                    duration: 2.seconds,
                    curve: Curves.easeInOut,
                    delay: Duration(milliseconds: 'KEISAN'.indexOf(char) * 100),
                  );
            }).toList(),
          ),
        ),
      ),
      body: Stack(
        children: [
          const ParallaxBackgroundShapes(),
          NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              // This makes the parallax effect work by propagating scroll events
              return false;
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color.fromRGBO(21, 123, 163, 0.9),
                    Color.fromRGBO(146, 74, 26, 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16.0),
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
                                    color: const Color.fromRGBO(
                                        255, 255, 255, 0.5),
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
                            duration: 400.ms)
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
          ),
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.fromRGBO(255, 255, 255, 0.2),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.contact_support,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          backgroundColor: const Color.fromRGBO(
                            42,
                            45,
                            62,
                            0.95,
                          ),
                          title: const Text(
                            'İletişim',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFED6C02),
                            ),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sorularınız için:',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                SupportInfo.supportEmail,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Color(0xFFFFA726),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Destek sayfası:',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => _launchUrl(SupportInfo.supportPageUrl),
                                child: const Text(
                                  'Destek Sayfasını Aç',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Color(0xFFFFA726),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Versiyon: ${SupportInfo.version}',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => _launchUrl(SupportInfo.supportPageUrl),
                              child: const Text(
                                'Destek Sayfası',
                                style: TextStyle(color: Color(0xFFFFA726)),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Tamam',
                                style: TextStyle(color: Color(0xFFFFA726)),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ParallaxBackgroundShapes extends StatefulWidget {
  const ParallaxBackgroundShapes({super.key});

  @override
  State<ParallaxBackgroundShapes> createState() =>
      _ParallaxBackgroundShapesState();
}

class _ParallaxBackgroundShapesState extends State<ParallaxBackgroundShapes>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo.depth == 0) {
          setState(() {
            _scrollOffset = scrollInfo.metrics.pixels;
          });
        }
        return false;
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: ParallaxShapesPainter(_controller.value, _scrollOffset),
            child: Container(),
          );
        },
      ),
    );
  }
}

class ParallaxShapesPainter extends CustomPainter {
  final double animationValue;
  final double scrollOffset;

  ParallaxShapesPainter(this.animationValue, this.scrollOffset);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, 0.05)
      ..style = PaintingStyle.fill;

    // Parallax effect multiplier - adjust as needed
    final parallaxFactor = 0.1;

    for (var i = 0; i < 5; i++) {
      // Calculate parallax effect - each shape moves at different speed
      final parallaxOffset = scrollOffset * parallaxFactor * (i * 0.2 + 0.5);

      final offset = Offset(
        size.width * (0.2 + 0.15 * i),
        size.height * (0.3 + 0.1 * i) - parallaxOffset,
      );

      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate((animationValue + i) * 2 * math.pi);

      if (i % 3 == 0) {
        canvas.drawCircle(Offset.zero, 40, paint);
      } else if (i % 3 == 1) {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: 60, height: 60),
          paint,
        );
      } else {
        final path = Path();
        const size = 40.0;
        path.moveTo(0, -size);
        path.lineTo(size, size);
        path.lineTo(-size, size);
        path.close();
        canvas.drawPath(path, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ParallaxShapesPainter oldDelegate) =>
      animationValue != oldDelegate.animationValue ||
      scrollOffset != oldDelegate.scrollOffset;
}

class NeumorphicCard extends StatelessWidget {
  final Widget child;

  const NeumorphicCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(42, 45, 62, 0.3),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.4),
            offset: Offset(5, 5),
            blurRadius: 12,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Color.fromRGBO(255, 255, 255, 0.15),
            offset: Offset(-5, -5),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(
          color: Color.fromRGBO(255, 255, 255, 0.1),
          width: 1.5,
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromRGBO(255, 255, 255, 0.15),
            Color.fromRGBO(255, 255, 255, 0.05),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: child,
        ),
      ),
    );
  }
}

enum MenuCategory {
  action,
  history,
  finance,
  data,
  help,
}

class CategoryIndicator extends StatelessWidget {
  final MenuCategory category;

  const CategoryIndicator({super.key, required this.category});

  Color get categoryColor {
    switch (category) {
      case MenuCategory.action:
        return const Color(0xFFED6C02);
      case MenuCategory.history:
        return const Color(0xFF157BA3);
      case MenuCategory.finance:
        return const Color(0xFF924A1A);
      case MenuCategory.data:
        return const Color(0xFFFFA726);
      case MenuCategory.help:
        return const Color(0xFFFF5722);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: categoryColor,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class MenuItem {
  final String title;
  final IconData icon;
  final String route;
  final MenuCategory category;

  const MenuItem(this.title, this.icon, this.route, this.category);
}

class MenuItemButton extends StatefulWidget {
  final MenuItem item;
  final Widget child;

  const MenuItemButton({
    super.key,
    required this.item,
    required this.child,
  });

  @override
  State<MenuItemButton> createState() => _MenuItemButtonState();
}

class _MenuItemButtonState extends State<MenuItemButton>
    with SingleTickerProviderStateMixin {
  bool isPressed = false;
  bool isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => isPressed = true);
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => isPressed = false);
    _controller.reverse().then((_) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          // Add this check
          Navigator.pushNamed(context, widget.item.route);
        }
      });
    });
  }

  void _handleTapCancel() {
    setState(() => isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isHovered
                      ? const [
                          BoxShadow(
                            color: Color.fromRGBO(237, 108, 2, 0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          )
                        ]
                      : [],
                ),
                child: child,
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}
