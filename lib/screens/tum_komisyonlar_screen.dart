import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

class TumKomisyonlarScreen extends StatefulWidget {
  const TumKomisyonlarScreen({super.key});

  @override
  State<TumKomisyonlarScreen> createState() => _TumKomisyonlarScreenState();
}

class _TumKomisyonlarScreenState extends State<TumKomisyonlarScreen> {
  Map<String, dynamic> komisyonlar = {};
  String filterBy = 'all'; // 'all', 'year', or 'month'
  int? selectedYear;
  int? selectedMonth;
  double totalKomisyon = 0;

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

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _komisyonlarFile async {
    final path = await _localPath;
    return File('$path/komisyonlar.json');
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
          calculateTotal();
        });
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

  void calculateTotal() {
    totalKomisyon = 0;
    final entries = getFilteredEntries();
    for (var entry in entries) {
      final entryData = komisyonlar[entry.$1] as Map<String, dynamic>? ?? {};
      final isIcHat = entryData['isIcHat'] as bool? ?? false;
      if (!isIcHat) {
        totalKomisyon += entry.$3;
      }
    }
  }

  void _selectYear(BuildContext context) {
    final years =
        komisyonlar.keys
            .map((dateStr) => DateTime.parse(dateStr).year)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

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
                  color: Colors.black.withAlpha(77), // 0.3 * 255 ≈ 77
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
                      'Yıl Seçiniz',
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
                    itemCount: years.length,
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
                            years[index].toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            setState(() {
                              selectedYear = years[index];
                              selectedMonth = null;
                              filterBy = 'year';
                              calculateTotal();
                            });
                          },
                          hoverColor: Colors.white.withAlpha(
                            26,
                          ), // 0.1 * 255 ≈ 26
                          splashColor: Colors.orange.withAlpha(
                            77,
                          ), // 0.3 * 255 ≈ 77
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

  void _selectMonth(BuildContext context) {
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
                  color: Colors.black.withAlpha(77), // 0.3 * 255 ≈ 77
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
                      'Ay Seçiniz',
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
                            setState(() {
                              selectedMonth = index + 1;
                              filterBy = 'month';
                              calculateTotal();
                            });
                          },
                          hoverColor: Colors.white.withAlpha(26),
                          splashColor: Colors.orange.withAlpha(77),
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

  List<(String, double, double, int, int)> getFilteredEntries() {
    List<(String, double, double, int, int)> entries = [];
    komisyonlar.forEach((dateStr, entry) {
      final date = DateTime.parse(dateStr);

      bool shouldInclude =
          filterBy == 'all' ||
          (filterBy == 'year' && date.year == selectedYear) ||
          (filterBy == 'month' && date.month == selectedMonth);

      if (shouldInclude) {
        entries.add((
          dateStr,
          (entry['amount'] != null ? (entry['amount'] as num).toDouble() : 0.0),
          (entry['commission'] != null ? (entry['commission'] as num).toDouble() : 0.0),
          date.year,
          date.month,
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
                              'Girdi Geçmişi Yardımı',
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
                              '🔍 Filtreleme Seçenekleri',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Komisyon girişlerinizi farklı kriterlere göre filtreleyebilirsiniz:',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '• "Yıla Göre": Belirli bir yılın tüm komisyonlarını görün\n'
                              '• "Aya Göre": Belirli bir ayın tüm komisyonlarını görün\n'
                              '• "Tümünü Göster": Filtre temizle, hepsini listele',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '📊 Tablo İçeriği',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '• Tarih: Komisyonun girildiği tarih\n'
                              '• Tutar: Girilen orijinal miktar\n'
                              '• Komisyon: Hesaplanan komisyon miktarı\n'
                              '• € (Euro) veya ₺ (Türk Lirası) para birimi gösterilir',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '💰 Toplam Hesaplama',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '• Alt kısımda seçilen filtreye göre toplam gösterilir\n'
                              '• Sadece dış hat (Euro) komisyonları toplama dahildir\n'
                              '• İç hat (Türk Lirası) komisyonları ayrı hesaplanır\n'
                              '• En yeni kayıtlar üstte görünür',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '⚙️ Kullanım İpuçları',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '• Aktif filtre turuncu renkle vurgulanır\n'
                              '• Yıl filtresinde sadece kayıt bulunan yıllar gösterilir\n'
                              '• Ay filtresinde tüm aylar seçilebilir\n'
                              '• Bu ekrandan sadece görüntüleme yapabilirsiniz',
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
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        title: Text(
          'Tüm Komisyonlarım',
          style: TextStyle(
            color: Color(0xFFED6C02),
            fontSize: 24,
            fontFamily: 'Poppins',
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
                SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight + 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: filterBy == 'year'
                              ? [
                                  const Color.fromRGBO(239, 108, 0, 0.8),
                                  const Color.fromRGBO(239, 108, 0, 0.6),
                                ]
                              : [
                                  const Color.fromRGBO(21, 123, 163, 0.9),
                                  const Color.fromRGBO(146, 74, 26, 0.9),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(77), // 0.3 * 255 ≈ 77
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => _selectYear(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 25,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(
                          filterBy == 'year' && selectedYear != null
                              ? '$selectedYear'
                              : 'Yıla Göre',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: filterBy == 'month'
                              ? [
                                  const Color.fromRGBO(239, 108, 0, 0.8),
                                  const Color.fromRGBO(239, 108, 0, 0.6),
                                ]
                              : [
                                  const Color.fromRGBO(21, 123, 163, 0.9),
                                  const Color.fromRGBO(146, 74, 26, 0.9),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(77), // 0.3 * 255 ≈ 77
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => _selectMonth(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 25,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(
                          filterBy == 'month' && selectedMonth != null
                              ? months[selectedMonth! - 1]
                              : 'Aya Göre',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (filterBy != 'all')
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color.fromRGBO(21, 123, 163, 0.9),
                            Color.fromRGBO(146, 74, 26, 0.9),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(77), // 0.3 * 255 ≈ 77
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            filterBy = 'all';
                            selectedYear = null;
                            selectedMonth = null;
                            calculateTotal();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 25,
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'Tümünü Göster',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
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
                          0: FlexColumnWidth(1.5), // Date
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
              bottom: 60, // Position above home button
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 4.0,
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
                    Text(
                      filterBy == 'all'
                          ? 'Toplam Komisyon:'
                          : filterBy == 'year'
                          ? '$selectedYear Yılı Toplam:'
                          : '${months[selectedMonth! - 1]} Ayı Toplam:',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${totalKomisyon.toStringAsFixed(2)} €',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
