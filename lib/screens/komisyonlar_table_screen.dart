import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import '../routes.dart';
import '../services/data_service.dart';

class KomisyonlarTableScreen extends StatefulWidget {
  const KomisyonlarTableScreen({super.key});

  @override
  State<KomisyonlarTableScreen> createState() => _KomisyonlarTableScreenState();
}

class _KomisyonlarTableScreenState extends State<KomisyonlarTableScreen> {
  Map<String, dynamic> komisyonlar = {};
  (DateTime, DateTime) periodRange = _getDefaultDateRange();
  double selectedPeriodTotal = 0;
  double mevcutKomisyon = 0;
  (DateTime, DateTime) mevcutPeriodRange = _getMevcutDateRange();

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _komisyonlarFile async {
    final path = await _localPath;
    return File('$path/komisyonlar.json');
  }

  static (DateTime, DateTime) _getMevcutDateRange() {
    // Get current month from system and calculate period like _getDateRangeForMonth
    final today = DateTime.now();
    return (
      // 16th of two months before current month
      DateTime(today.year, today.month - 2, 16),
      // 15th of one month before current month
      DateTime(today.year, today.month - 1, 15),
    );
  }

  static (DateTime, DateTime) _getDefaultDateRange() {
    // Default to current month for the period selector
    final today = DateTime.now();
    return (
      DateTime(today.year, today.month, 1),
      DateTime(
        today.year,
        today.month,
        DateTime(today.year, today.month + 1, 0).day,
      ),
    );
  }

  (DateTime, DateTime) _getDateRangeForMonth(DateTime month) {
    // For selected month (e.g., March), show January 16 - February 15
    return (
      // 16th of two months before
      DateTime(month.year, month.month - 2, 16),
      // 15th of one month before
      DateTime(month.year, month.month - 1, 15),
    );
  }

  Future<void> _selectMonth(BuildContext context) async {
    final todayDate = DateTime.now();

    final List<String> months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color.fromRGBO(21, 123, 163, 1.0),
                  Color.fromRGBO(146, 74, 26, 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.3 * 255).toInt()),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  decoration: BoxDecoration(
                    color: Colors.orange[800],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Dönem Seçiniz',
                      style: TextStyle(
                        color: Colors.orange[100],
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 400,
                  width: 300,
                  child: ListView.builder(
                    itemCount: months.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 2.0,
                        ),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          title: Text(
                            months[index],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            final selectedDate = DateTime(
                              todayDate.year,
                              index + 1,
                              1,
                            );
                            setState(() {
                              periodRange = _getDateRangeForMonth(selectedDate);
                            });
                            calculateCommissions();
                          },
                          hoverColor: Colors.white.withAlpha(
                            (0.1 * 255).toInt(),
                          ),
                          splashColor: Colors.orange.withAlpha(
                            (0.3 * 255).toInt(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    loadKomisyonlar();
  }

  Future<void> loadKomisyonlar() async {
    try {
      final file = await _komisyonlarFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        setState(() {
          komisyonlar = json.decode(content);
        });
        await calculateCommissions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Komisyonlar yüklenirken hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> calculateCommissions() async {
    selectedPeriodTotal = _calculateTotalForRange(periodRange);
    mevcutKomisyon = _calculateTotalForRange(mevcutPeriodRange);

    // Save mevcut komisyon using DataService
    await DataService().saveCommission(mevcutKomisyon);
  }

  double _calculateTotalForRange((DateTime, DateTime) range) {
    double total = 0;
    komisyonlar.forEach((dateStr, entry) {
      final entryDate = DateTime.parse(dateStr);
      final isIcHat = entry['isIcHat'] as bool? ?? false;
      if (!isIcHat &&
          entryDate.isAfter(range.$1.subtract(const Duration(days: 1))) &&
          entryDate.isBefore(range.$2.add(const Duration(days: 1)))) {
        final commission = entry['commission'] ?? entry['amount'];
        if (commission != null) {
          total += (commission as num).toDouble();
        }
      }
    });
    return total;
  }

  List<(String, double, double)> getFilteredEntries() {
    List<(String, double, double)> entries = [];
    komisyonlar.forEach((dateStr, entry) {
      final entryDate = DateTime.parse(dateStr);
      if (entryDate.isAfter(periodRange.$1.subtract(const Duration(days: 1))) &&
          entryDate.isBefore(periodRange.$2.add(const Duration(days: 1)))) {
        final commission = entry['commission'] ?? entry['amount'] ?? 0.0;
        entries.add((
          dateStr,
          (entry['amount'] != null ? (entry['amount'] as num).toDouble() : 0.0),
          (commission as num).toDouble(),
        ));
      }
    });
    entries.sort((a, b) => b.$1.compareTo(a.$1)); // Sort by date descending
    return entries;
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
                              'Dönem Komisyonları Yardımı',
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
                              '📊 Dönem Seçimi',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '"Dönem Seçiniz" butonuna tıklayarak istediğiniz ayı seçin. Dönem mantığı şu şekilde çalışır:',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '• Mart ayı seçerseniz: 16 Ocak - 15 Şubat dönemi gösterilir\n'
                              '• Nisan ayı seçerseniz: 16 Şubat - 15 Mart dönemi gösterilir\n'
                              '• Bu sistem THY\'nin maaş dönem sistemiyle uyumludur',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '📋 Tablo Görünümü',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '• Tarih: Komisyonun girildiği gün\n'
                              '• Tutar: Girilen orijinal miktar (€ veya ₺)\n'
                              '• Komisyon: Hesaplanan komisyon miktarı\n'
                              '• En yeni girişler üstte gösterilir',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '💰 Toplam Gösterimi',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '• Mevcut Dönem Komisyonu: Geçerli maaş döneminiz\n'
                              '• Seçilen Dönem Toplamı: Seçtiğiniz dönemin toplamı\n'
                              '• Sadece dış hat komisyonları dahil edilir\n'
                              '• İç hat komisyonları ayrı hesaplanır',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '➕ Yeni Giriş',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Sağ üstteki "+" butonuna tıklayarak yeni komisyon girişi yapabilirsiniz.',
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

  @override
  Widget build(BuildContext context) {
    final entries = getFilteredEntries();

    return Scaffold(
      backgroundColor:
          Colors.transparent, // Make scaffold background transparent
      extendBodyBehindAppBar: false, // Extend content behind AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        flexibleSpace: Container(
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
        ),
        title: Text(
          'Dönem Komisyonları',
          style: TextStyle(
            color: Color(0xFFED6C02),
            fontFamily: 'Poppins',
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline, size: 22, color: Colors.orange[300]),
            tooltip: 'Yardım',
            onPressed: _showHelpDialog,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            color: Colors.orange[300],
            onPressed: () => Navigator.pushNamed(context, Routes.komisyonEntry),
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
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: () => _selectMonth(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[800],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'Dönem Seçiniz! ${periodRange.$1.day}/${periodRange.$1.month}/${periodRange.$1.year} - ${periodRange.$2.day}/${periodRange.$2.month}/${periodRange.$2.year}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Table(
                        border: TableBorder.all(
                          color: Colors.white24,
                          width: 1,
                        ),
                        columnWidths: const {
                          0: FlexColumnWidth(2), // Date
                          1: FlexColumnWidth(1.5), // Amount
                          2: FlexColumnWidth(1.5), // Commission
                        },
                        children: [
                          TableRow(
                            decoration: BoxDecoration(
                              color: Colors.orange[800],
                            ),
                            children: const [
                              TableCell(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                    'Tarih',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              TableCell(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                    'Tutar',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              TableCell(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                    'Komisyon',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          ...entries.map((entry) {
                            final date = DateTime.parse(entry.$1);
                            final entryData = komisyonlar[entry.$1] as Map<String, dynamic>? ?? {};
                            final isIcHat = entryData['isIcHat'] as bool? ?? false;
                            return TableRow(
                              children: [
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      '${date.day}/${date.month}/${date.year}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      isIcHat
                                        ? '${entry.$2.toStringAsFixed(2)} ₺'
                                        : '${entry.$2.toStringAsFixed(2)} €',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      isIcHat
                                        ? '${entry.$3.toStringAsFixed(2)} ₺'
                                        : '${entry.$3.toStringAsFixed(2)} €',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    constraints: const BoxConstraints(maxHeight: 40),
                    color: Colors.orange[800],
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Mevcut Dönem Komisyonu:',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${mevcutKomisyon.toStringAsFixed(2)} €',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    constraints: const BoxConstraints(maxHeight: 40),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color.fromRGBO(21, 123, 163, 1.0),
                          Color.fromRGBO(146, 74, 26, 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((0.3 * 255).toInt()),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Seçilen Dönem Toplamı:',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${selectedPeriodTotal.toStringAsFixed(2)} €',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
