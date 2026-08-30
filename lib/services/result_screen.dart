import 'package:flutter/material.dart';
import 'dart:ui';
import '../routes.dart';
import '../services/data_service.dart';
import '../services/calculation_service.dart';
import '../services/calendar_export_service.dart';
import '../widgets/salary_breakdown_card.dart';

class ResultScreen extends StatelessWidget {
  final bool isSCCM;
  final double dutyHours;
  final double nightHours;
  final Map<String, int> legCounts;
  final double commission;
  final int layoverCount;
  final int offDutyCounts;
  final int sixthDay;
  final int internationalOvernight;
  final String? rosterPeriod;
  final List<Map<String, dynamic>> offDays;

  const ResultScreen({
    super.key,
    required this.isSCCM,
    required this.dutyHours,
    required this.nightHours,
    required this.legCounts,
    required this.commission,
    required this.layoverCount,
    required this.offDutyCounts,
    this.sixthDay = 0,
    this.internationalOvernight = 0,
    this.rosterPeriod,
    this.offDays = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1D2B), // Dark theme background
      floatingActionButton: Builder(
        builder: (context) {
          return FutureBuilder<Map<String, dynamic>?>(
            future: DataService().getBaseSalaryData(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data == null) {
                return const SizedBox.shrink();
              }

              final Map<String, dynamic> updatedBaseSalaryData = {
                ...snapshot.data!,
                'sixthDay': snapshot.data!['sixthDay'] ?? sixthDay,
                'internationalOvernight':
                    snapshot.data!['internationalOvernight'] ??
                    internationalOvernight,
              };

              final components = CalculationService.calculateComponents(
                isSCCM: isSCCM,
                dutyHours: dutyHours,
                nightHours: nightHours,
                legCounts: legCounts,
                commission: commission,
                baseSalaryData: updatedBaseSalaryData,
                layoverCount: layoverCount,
                offDutyCounts: offDutyCounts,
              );

              return FloatingActionButton.extended(
                onPressed: () => _showSaveDialog(
                  context,
                  components['total_euro'] ?? 0,
                  components['total_tl'] ?? 0,
                ),
                label: const Text(
                  'Kaydet',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                icon: const Icon(Icons.save),
                backgroundColor: const Color(0xFF4FACFE),
              );
            },
          );
        },
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          color: Colors.white,
          onPressed: () {
            if (Navigator.canPop(context)) Navigator.pop(context);
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1F1D2B),
              Colors.blue.shade900.withAlpha((0.3 * 255).toInt()),
            ],
          ),
        ),
        child: Stack(
          children: [
            FutureBuilder<Map<String, dynamic>?>(
              future: DataService().getBaseSalaryData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF4FACFE),
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Veri yüklenirken hata: ${snapshot.error}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Lütfen önce taban maaş bilgilerinizi ayarlayın',
                        ),
                        backgroundColor: Colors.red.shade400,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                    Navigator.pushNamed(context, Routes.baseMaas);
                  });
                  return const Center(
                    child: Text(
                      'No base salary data found',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  );
                }

                final Map<String, dynamic> updatedBaseSalaryData = {
                  ...snapshot.data!,
                  'sixthDay': snapshot.data!['sixthDay'] ?? sixthDay,
                  'internationalOvernight':
                      snapshot.data!['internationalOvernight'] ??
                      internationalOvernight,
                };

                // Get domestic commission for the roster period
                return FutureBuilder<double>(
                  future: DataService().getDomesticCommission(rosterPeriod),
                  builder: (context, domesticSnapshot) {
                    if (domesticSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF4FACFE),
                          ),
                        ),
                      );
                    }

                    final domesticCommission = domesticSnapshot.data ?? 0.0;
                    final components = CalculationService.calculateComponents(
                      isSCCM: isSCCM,
                      dutyHours: dutyHours,
                      nightHours: nightHours,
                      legCounts: legCounts,
                      commission: commission,
                      baseSalaryData: updatedBaseSalaryData,
                      layoverCount: layoverCount,
                      offDutyCounts: offDutyCounts,
                      domesticCommission: domesticCommission,
                    );

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(
                                    (0.3 * 255).toInt(),
                                  ),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: SalaryBreakdownCard(
                              components: components,
                              totalEuro: components['total_euro'] ?? 0,
                              isSCCM: isSCCM,
                              baseSalaryData: updatedBaseSalaryData,
                              dutyHours: dutyHours,
                              nightHours: nightHours,
                              legCounts: legCounts,
                              layoverCount: layoverCount,
                              offDutyCounts: offDutyCounts,
                              rosterPeriod: rosterPeriod,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Off Days Section
                          if (offDays.isNotEmpty) _buildOffDaysCard(),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffDaysCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: const Color(0xFF1F1D2B),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1F1D2B),
              const Color(0xFF1F1D2B).withAlpha((0.8 * 255).toInt()),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF228B22), Color(0xFF32CD32)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'İzin Günleri',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Toplam İzin Günleri: ${offDays.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) => Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF228B22), Color(0xFF32CD32)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton.icon(
                  onPressed: () => _showOffDaysDialog(context),
                  icon: const Icon(Icons.visibility, color: Colors.white),
                  label: const Text(
                    'İzin Günlerini Gör',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Calendar Export Button
            Builder(
              builder: (context) => Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9C27B0), Color(0xFF673AB7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton.icon(
                  onPressed: () => _exportToCalendar(context),
                  icon: const Icon(Icons.calendar_month, color: Colors.white),
                  label: const Text(
                    'Takvime Aktar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _exportToCalendar(BuildContext context) async {
    await CalendarExportService.exportToCalendar(
      context: context,
      offDays: offDays,
      layovers: [], // No layovers for simplified version
      rosterPeriod: rosterPeriod ?? '',
    );
  }

  void _showOffDaysDialog(BuildContext context) {
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
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.orange[300],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Text(
                        'İzin Günleri (${offDays.length} gün)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // Content
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: offDays.length,
                        itemBuilder: (context, index) {
                          final offDay = offDays[index];
                          final date = DateTime.parse(offDay['date']);
                          final dateStr = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: const Color.fromARGB(230, 255, 255, 255),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getOffDayColor(offDay['type']),
                                child: Text(
                                  offDay['dayName'].substring(0, 1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                dateStr,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(offDay['description']),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getOffDayColor(offDay['type']),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  offDay['type'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Footer
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[300],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Kapat'),
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

  Color _getOffDayColor(String type) {
    switch (type) {
      case 'BDAY':
        return Colors.blue[400]!;
      case 'OFFB':
        return Colors.orange[400]!;
      case 'OFF.':
        return Colors.red[400]!;
      case 'AVAC':
      case 'Vac':
        return Colors.green[400]!;
      case 'COMM':
        return Colors.purple[400]!;
      default:
        return Colors.red[300]!;
    }
  }

  void _showSaveDialog(BuildContext context, double totalEuro, double totalTL) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1F1D2B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF4FACFE), width: 1),
          ),
          title: const Text(
            'Geçmiş Maaşlarıma Kaydedilsin mi?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Hayır',
                style: TextStyle(
                  color: Color(0xFF4FACFE),
                  fontSize: 16,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();

                  try {
                    final baseSalaryData = await DataService().getBaseSalaryData();
                    if (baseSalaryData == null) return;

                    final updatedBaseSalaryData = {
                      ...baseSalaryData,
                      'sixthDay': baseSalaryData['sixthDay'] ?? sixthDay,
                      'internationalOvernight':
                          baseSalaryData['internationalOvernight'] ??
                          internationalOvernight,
                    };

                    // Get domestic commission for the roster period
                    final domesticCommission = await DataService().getDomesticCommission(rosterPeriod);

                    final components = CalculationService.calculateComponents(
                      isSCCM: isSCCM,
                      dutyHours: dutyHours,
                      nightHours: nightHours,
                      legCounts: legCounts,
                      commission: commission,
                      baseSalaryData: updatedBaseSalaryData,
                      layoverCount: layoverCount,
                      offDutyCounts: offDutyCounts,
                      domesticCommission: domesticCommission,
                    );

                    await DataService().saveSalaryCalculation(
                      euroTotal: totalEuro,
                      tlTotal: totalTL,
                      rosterPeriod: rosterPeriod,
                      components: components,
                      isSCCM: isSCCM,
                      dutyHours: dutyHours,
                      nightHours: nightHours,
                      legCounts: legCounts,
                      layoverCount: layoverCount,
                      offDutyCounts: offDutyCounts,
                    );

                    // Use the parent context for ScaffoldMessenger
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Maaş bilgileri kaydedildi',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.white,
                            ),
                          ),
                          backgroundColor: const Color(0xFF4FACFE),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Kaydetme hatası: $e',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.white,
                            ),
                          ),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Evet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
