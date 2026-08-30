import 'package:flutter/material.dart';
import '../services/data_service.dart';
import '../utils/date_utils.dart' as app_date_utils;

class GecmisMaaslarScreen extends StatefulWidget {
  const GecmisMaaslarScreen({super.key});

  @override
  State<GecmisMaaslarScreen> createState() => _GecmisMaaslarScreenState();
}

class _GecmisMaaslarScreenState extends State<GecmisMaaslarScreen> {
  List<Map<String, dynamic>> salaries = [];
  String filterBy = 'all';
  int? selectedYear;
  int? selectedMonth;

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

  @override
  void initState() {
    super.initState();
    loadSalaries();
  }

  Future<void> loadSalaries() async {
    try {
      final loadedSalaries = await DataService().getPreviousSalaries();
      setState(() {
        salaries = loadedSalaries.reversed.toList();
      });
    } catch (e) {
      debugPrint('Error loading salaries: $e');
    }
  }

  Future<void> deleteSalaryRecord(Map<String, dynamic> salary) async {
    try {
      await DataService().deleteSalaryRecord(salary);
    } catch (e) {
      debugPrint('Error deleting salary: $e');
    }
  }

  /// Returns true when [item] and [salary] represent the same saved record.
  ///
  /// Matches by `id` when available, otherwise falls back to the identity
  /// fields (date, euro, tl, roster period) for legacy records without an id.
  bool _isSameSalaryRecord(Map<String, dynamic> item, Map<String, dynamic> salary) {
    final id = salary['id']?.toString();
    if (id != null && id.isNotEmpty) {
      return item['id']?.toString() == id;
    }
    return item['date']?.toString() == salary['date']?.toString() &&
        (item['euro'] as num?)?.toDouble() == (salary['euro'] as num?)?.toDouble() &&
        (item['tl'] as num?)?.toDouble() == (salary['tl'] as num?)?.toDouble() &&
        item['rosterPeriod']?.toString() == salary['rosterPeriod']?.toString();
  }

  List<Map<String, dynamic>> getFilteredSalaries() {
    if (filterBy == 'all') {
      return salaries;
    }

    return salaries.where((salary) {
      if (filterBy == 'year') {
        // For year filtering, use file save date
        final date = DateTime.parse(salary['date']);
        return date.year == selectedYear;
      } else if (filterBy == 'month') {
        // For month filtering, use payment month calculated from roster period
        final rosterPeriod = salary['rosterPeriod'] as String?;
        if (rosterPeriod != null && rosterPeriod.isNotEmpty) {
          final paymentMonthInt = _getPaymentMonthNumber(rosterPeriod);
          return paymentMonthInt == selectedMonth;
        }
        // Fallback to file date if no roster period
        final date = DateTime.parse(salary['date']);
        return date.month == selectedMonth;
      }
      return false;
    }).toList();
  }

  /// Helper method to get payment month number from roster period
  int _getPaymentMonthNumber(String rosterPeriod) {
    // Parse roster period using the same logic as DateUtils
    final RegExp regExp = RegExp(r'(\d{2})([A-Za-z]{3})(\d{2})', caseSensitive: false);
    final match = regExp.firstMatch(rosterPeriod);
    
    if (match == null) {
      return DateTime.now().month; // Fallback to current month
    }

    final monthAbbr = match.group(2)!.toUpperCase();
    const Map<String, int> monthMap = {
      'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
      'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12
    };
    
    final rosterMonth = monthMap[monthAbbr];
    if (rosterMonth == null) {
      return DateTime.now().month; // Fallback to current month
    }

    // Payment month is the next month
    int paymentMonth = rosterMonth + 1;
    
    // Handle year rollover (December -> January)
    if (paymentMonth > 12) {
      paymentMonth = 1;
    }

    return paymentMonth;
  }

  @override
  Widget build(BuildContext context) {
    final filteredSalaries = getFilteredSalaries();

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          centerTitle: false,
          leading: Padding(
            padding: EdgeInsets.only(left: 8.0, top: 8.0),
            child: BackButton(),
          ),
          title: Padding(
            padding: EdgeInsets.only(top: 16.0),
            child: Text(
              'Geçmiş Maaşlarım',
              style: TextStyle(
                color: Color(0xFFED6C02),
                fontSize: 24,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.help_outline, size: 22, color: Colors.orange[300]),
              tooltip: 'Yardım',
              onPressed: () => _showHelpDialog(context),
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
                const SizedBox(height: 120),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFilterButton(
                      text: filterBy == 'year' && selectedYear != null
                          ? '$selectedYear'
                          : 'Yıla Göre',
                      isActive: filterBy == 'year',
                      onPressed: () => _selectYear(context),
                    ),
                    _buildFilterButton(
                      text: filterBy == 'month' && selectedMonth != null
                          ? months[selectedMonth! - 1]
                          : 'Aya Göre',
                      isActive: filterBy == 'month',
                      onPressed: () => _selectMonth(context),
                    ),
                  ],
                ),
                if (filterBy != 'all')
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: _buildFilterButton(
                      text: 'Tümünü Göster',
                      onPressed: () {
                        setState(() {
                          filterBy = 'all';
                          selectedYear = null;
                          selectedMonth = null;
                        });
                      },
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: filteredSalaries.isEmpty
                        ? const Center(
                            child: Text(
                              'No previous salary data found',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredSalaries.length,
                            itemBuilder: (context, index) => _buildSalaryCard(
                              context,
                              filteredSalaries[index],
                              index,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton({
    required String text,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive
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
            color: Colors.black.withAlpha(77),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSalaryCard(
    BuildContext context,
    Map<String, dynamic> salary,
    int index,
  ) {
    return Dismissible(
      key: Key(salary['id'] ?? (salary['date'] + index.toString())),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) => _confirmDelete(context),
      onDismissed: (direction) {
        setState(() {
          // Remove by identity (id when available), not by index - the visible
          // list can be filtered, so the index may point to another record.
          salaries.removeWhere((item) => _isSameSalaryRecord(item, salary));
        });
        // Always delete from disk, even for legacy records without an id,
        // otherwise the record would reappear on the statistics page.
        deleteSalaryRecord(salary);
      },
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        color: Colors.white.withAlpha((0.1 * 255).toInt()),
        margin: const EdgeInsets.only(bottom: 16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () => _showSalaryDetails(context, salary),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date: ${salary['date']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '€${salary['euro'].toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₺${salary['tl'].toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.orange[300],
                          fontSize: 20,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Dönem: ${salary['rosterPeriod'] ?? 'N/A'}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  if (salary['rosterPeriod'] != null && salary['rosterPeriod'].isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Ödeme: ${app_date_utils.DateUtils.getPaymentMonth(salary['rosterPeriod'])}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        fontFamily: 'Poppins',
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color.fromRGBO(42, 45, 62, 0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Bu maaş kaydını silmek istediğinize emin misiniz?',
                style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(backgroundColor: Colors.grey),
                    child: const Text(
                      'İptal',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text(
                      'Sil',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSalaryDetails(BuildContext context, Map<String, dynamic> salary) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color.fromARGB(166, 0, 0, 0),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color.fromARGB(255, 30, 84, 121),
                Color.fromARGB(255, 7, 163, 137),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFF4500), width: 2),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFED6C02), Color(0xFFFFA726)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Maaş Detayları',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _formatBreakdown(
                      components: Map<String, double>.from(
                        salary['components'] ?? {},
                      ),
                      totalEuro: salary['euro'] ?? 0.0,
                      isSCCM: salary['isSCCM'] ?? false,
                      dutyHours: salary['dutyHours'] ?? 0.0,
                      nightHours: salary['nightHours'] ?? 0.0,
                      legCounts: Map<String, int>.from(
                        salary['legCounts'] ?? {},
                      ),
                      offDutyCounts: salary['offDutyCounts'] ?? 0,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectYear(BuildContext context) {
    final years =
        salaries
            .map((salary) => DateTime.parse(salary['date']).year)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                color: Colors.black.withAlpha(77),
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
      ),
    );
  }

  void _selectMonth(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                color: Colors.black.withAlpha(77),
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
      ),
    );
  }

  String _formatBreakdown({
    required Map<String, double> components,
    required double totalEuro,
    required bool isSCCM,
    required double dutyHours,
    required double nightHours,
    required Map<String, int> legCounts,
    required int offDutyCounts,
  }) {
    final StringBuffer buffer = StringBuffer();
    final role = isSCCM ? 'SCCM' : 'CCM';

    buffer.writeln('👨‍✈️ $role Maaş Detayları\n');

    buffer.writeln('📊 Temel Bileşenler');
    buffer.writeln('────────────────────');
    buffer.writeln(
      '💰 Taban Maaş: €${components['base_pay']?.toStringAsFixed(2)}',
    );
    buffer.writeln(
      '💵 Komisyon: €${components['commission']?.toStringAsFixed(2)}',
    );
    if ((components['ic_hat_komisyon'] ?? 0) > 0) {
      buffer.writeln('🏠 İç Hat Komisyon: ${components['ic_hat_komisyon']?.toStringAsFixed(2)} ₺');
    }
    buffer.writeln('');

    final regularHours = dutyHours.clamp(0, 100);
    final overtimeHours = dutyHours > 100 ? dutyHours - 100 : 0;

    buffer.writeln('✈️ Uçuş Süreleri Detayı');
    buffer.writeln('────────────────────');
    buffer.writeln('⏱️ Normal Görev: ${regularHours.toStringAsFixed(1)} saat');
    buffer.writeln(
      '   └─ Ücret: €${components['duty_pay']?.toStringAsFixed(2)}',
    );

    if (overtimeHours > 0) {
      buffer.writeln('⚡ Fazla Mesai: ${overtimeHours.toStringAsFixed(1)} saat');
      buffer.writeln(
        '   └─ Ücret: €${components['overtime_pay']?.toStringAsFixed(2)}',
      );
    }
    buffer.writeln('🌙 Gece Uçuşu: ${nightHours.toStringAsFixed(1)} saat');
    buffer.writeln(
      '   └─ Ücret: €${components['night_hours_pay']?.toStringAsFixed(2)}\n',
    );

    buffer.writeln('🛫 Sektör Ödemeleri');
    buffer.writeln('────────────────────');
    buffer.writeln(
      '3️⃣ Sektör (${legCounts['leg3']} uçuş): €${components['leg3_pay']?.toStringAsFixed(2)}',
    );
    buffer.writeln(
      '4️⃣ Sektör (${legCounts['leg4']} uçuş): €${components['leg4_pay']?.toStringAsFixed(2)}',
    );
    buffer.writeln(
      '5️⃣ Sektör (${legCounts['leg5']} uçuş): €${components['leg5_pay']?.toStringAsFixed(2)}\n',
    );

    buffer.writeln('📅 Ek Ödemeler');
    buffer.writeln('────────────────────');
    buffer.writeln(
      '🏠 Off Günleri ($offDutyCounts gün): €${components['off_duty_pay']?.toStringAsFixed(2)}',
    );
    buffer.writeln(
      '6️⃣ 6. Gün Ödemesi: €${components['sixth_day_pay']?.toStringAsFixed(2)}',
    );
    buffer.writeln('🏨 Konaklama Ödemeleri:');
    buffer.writeln(
      '   ├─ Yurtiçi (${components['domestic_overnight_count']?.toInt()} gece): €${components['domestic_overnight_pay']?.toStringAsFixed(2)}',
    );
    buffer.writeln(
      '   └─ Yurtdışı (${components['international_overnight_count']?.toInt()} gece): €${components['international_overnight_pay']?.toStringAsFixed(2)}\n',
    );

    if (components['duzeltme'] != 0) {
      buffer.writeln(
        '📝 Yatı Düzeltme: ${components['duzeltme']?.toInt()} gece',
      );
      buffer.writeln(
        '   └─ Toplam Yatı: ${components['adjusted_layovers']?.toInt()} gece\n',
      );
    }

    buffer.writeln('💶 Toplam Özet');
    buffer.writeln('════════════════════');
    buffer.writeln(
      '💰 Toplam (EUR): €${components['total_euro']?.toStringAsFixed(2)}',
    );
    buffer.writeln(
      '💵 Toplam (TL): ${components['total_tl']?.toStringAsFixed(2)} ₺',
    );
    buffer.writeln(
      '💱 Euro Kuru: ${components['euro_rate']?.toStringAsFixed(2)} ₺',
    );

    return buffer.toString();
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color.fromRGBO(21, 123, 163, 1.0),
                Color.fromRGBO(146, 74, 26, 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange[800],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.help_outline, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Geçmiş Maaşlar Nasıl Kullanılır?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHelpSection(
                        '💰 Genel Bakış',
                        'Bu sayfa daha önce hesapladığınız tüm maaş kayıtlarını görüntüler. Her kayıt roster dönemi ve hesaplama tarihiyle birlikte saklanır.',
                      ),
                      const SizedBox(height: 16),
                      _buildHelpSection(
                        '📅 Filtreleme Seçenekleri',
                        '• Yıla Göre: Dosya kayıt tarihine göre filtreleme\n• Aya Göre: Ödeme ayına göre filtreleme (roster dönemi + 1 ay)\n• Örnek: Eylül roster dönemi → Ekim ödeme ayı',
                      ),
                      const SizedBox(height: 16),
                      _buildHelpSection(
                        '👆 Etkileşim',
                        '• Kartlara tıklayarak detaylı maaş bileşenlerini görüntüleyebilirsiniz\n• Sola kaydırarak kayıtları silebilirsiniz\n• Silme işlemi geri alınamaz - onay istenir',
                      ),
                      const SizedBox(height: 16),
                      _buildHelpSection(
                        '📊 Görüntülenen Bilgiler',
                        '• Hesaplama tarihi\n• Toplam maaş (EUR ve TL)\n• Roster dönemi\n• Ödeme ayı (otomatik hesaplanır)\n• Detaylı maaş bileşenleri (tıklayınca açılır)',
                      ),
                      const SizedBox(height: 16),
                      _buildHelpSection(
                        '📋 Detay Görünümü',
                        'Bir kayda tıkladığınızda şunları görebilirsiniz:\n• Taban maaş ve komisyon\n• Görev saati ödemeleri\n• Gece uçuşu ödemeleri\n• Sektör ödemeleri (3,4,5 sektör)\n• Yatı ödemeleri\n• Euro kuru ve TL karşılığı',
                      ),
                    ],
                  ),
                ),
              ),
              // Footer with Anladım button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange[800],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.orange[800],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Anladım',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.orange,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
