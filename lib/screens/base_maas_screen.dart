import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../services/data_service.dart';
import '../services/calculation_service.dart';
import './base_salary_service_screen.dart';
import '../models/pdf_result.dart';
import '../routes.dart';

class BaseMaasScreen extends StatefulWidget {
  const BaseMaasScreen({super.key});

  @override
  State<BaseMaasScreen> createState() => _BaseMaasScreenState();
}

class _BaseMaasScreenState extends State<BaseMaasScreen> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, TextEditingController> controllers;
  PdfResult? _selectedRoster;

  String? _role;
  
  final DataService _dataService = DataService();
  double dutyHours = 0.0;
  double nightHours = 0.0;
  Map<String, int> legCounts = {'leg3': 0, 'leg4': 0, 'leg5': 0};
  double commission = 0.0;
  int layoverCount = 0;
  int offDutyCounts = 0;

  final List<(String, String)> fields = [
    ('Base Maaş (€)', 'base_maas'),
    ('6. Gün Uçuş Adedi', 'alti_gun'),
    ('Off to Duty', 'off_duty'),
    ('Euro Kuru (₺)', 'euro_rate'),
  ];

  Future<void> _loadSavedRole() async {
    try {
      final savedRole = await _dataService.getRoleSelection();
      if (mounted && savedRole != null) {
        setState(() {
          _role = savedRole;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kayıtlı pozisyon yüklenirken hata: $e')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    controllers = {
      'base_maas': TextEditingController(),
      'alti_gun': TextEditingController(),
      'off_duty': TextEditingController(),
      'euro_rate': TextEditingController(),
    };
    loadSavedData();
    _loadInitialData();
    _loadSavedRole();
  }

  Future<void> _loadInitialData() async {
    try {
      final dataService = DataService();

      // Load data only if a roster is selected
      if (_selectedRoster == null) {
        return;
      }

      final pdfResult = _selectedRoster;
      final rosterPeriod = pdfResult?.data['rosterPeriod'] as String?;
      final currentCommission = await dataService.getCurrentCommission(
        rosterPeriod,
      );
      final baseSalaryData = await dataService.getBaseSalaryData();
      int localLayoverCount = 0;
      int internationalOvernightCount = 0;

      // Load fixes for selected roster period
      Map<String, dynamic> periodFixes = {};
      if (rosterPeriod != null && rosterPeriod.isNotEmpty) {
        periodFixes = await dataService.getFixesForRosterPeriod(rosterPeriod);
      }

      if (!mounted) return;

      // Parsed roster provides no off-duty count, so load the saved value to
      // use as the fallback when a parsed count is absent
      final savedOffDuty = await dataService.getOffDutyCounts();

      setState(() {
        commission = currentCommission;

        if (pdfResult != null) {
          final totalDutyTime =
              pdfResult.data['totalDutyTime'] as String? ?? "00:00";
          dutyHours = CalculationService.calculateDutyHours(totalDutyTime);

          final totalNightTime =
              pdfResult.data['nightHours'] as String? ?? "00:00";
          nightHours = CalculationService.calculateNightHours(totalNightTime);

          final flightCounts =
              pdfResult.data['flightCounts'] as Map<String, dynamic>? ?? {};
          legCounts = CalculationService.calculateLegCounts(flightCounts);

          final layoverData = pdfResult.data['layoverCount'];
          if (layoverData is Map) {
            localLayoverCount = (layoverData['domestic'] as int? ?? 0) + 
                              (layoverData['international'] as int? ?? 0);
            internationalOvernightCount =
                layoverData['international'] as int? ?? 0;
          } else if (layoverData is int) {
            localLayoverCount = layoverData;
            internationalOvernightCount =
                (baseSalaryData?['internationalOvernight'] as num? ?? 0).toInt();
          } else {
            localLayoverCount = 0;
          }
          layoverCount = localLayoverCount;
        }

        // Load fixes for this period if available. The off-duty count follows
        // the same rules as the 6. Gün field: a per-roster override takes
        // precedence, falling back to the saved global value.
        controllers['alti_gun']?.text =
            periodFixes['alti_gun']?.toString() ?? '0';
        controllers['off_duty']?.text =
            periodFixes['off_duty']?.toString() ?? savedOffDuty.toString();
        offDutyCounts = safeIntConvert(controllers['off_duty']!.text);
      });

      if (pdfResult != null) {
        final internationalOvernights =
            internationalOvernightCount > 0
                ? internationalOvernightCount
                : (baseSalaryData?['internationalOvernight'] as num? ?? 0)
                    .toInt();

        await dataService.saveLayoverData(
          totalLayovers: localLayoverCount,
          internationalLayovers: internationalOvernights,
        );

        await dataService.savePersistentData(
          baseSalary: (baseSalaryData?['baseSalary'] as num? ?? 0.0).toDouble(),
          euroRate: (baseSalaryData?['euroRate'] as num? ?? 0.0).toDouble(),
          offDutyCounts: offDutyCounts,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Veri yüklenirken hata: $e')));
    }
  }

  Future<void> _navigateToResult() async {
    if (_role == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen pozisyonunuzu seçin (CCM/SCCM)')),
      );
      return;
    }

    if (_selectedRoster == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir roster dönemi seçin')),
      );
      return;
    }

    try {
      final baseSalaryData = await DataService().getBaseSalaryData();

      if (!mounted) return;

      await Navigator.pushNamed(
        context,
        Routes.result,
        arguments: {
          'isSCCM': _role == 'SCCM',
          'dutyHours': dutyHours,
          'nightHours': nightHours,
          'legCounts': legCounts,
          'commission': commission,
          'include_commission': _role != 'SCCM',
          'layoverCount': () {
            final data = _selectedRoster?.data['layoverCount'];
            if (data is Map) {
              return (data['domestic'] as int? ?? 0) + (data['international'] as int? ?? 0);
            }
            return data as int? ?? 0;
          }(),
          'offDutyCounts': offDutyCounts,
          'sixthDay': baseSalaryData?['sixthDay'] ?? 0,
          'internationalOvernight':
              baseSalaryData?['internationalOvernight'] ?? 0,
          'rosterPeriod': _selectedRoster?.data['rosterPeriod'] ?? '',
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Veri yüklenirken hata: $e')));
    }
  }

  Future<void> loadSavedData() async {
    try {
      final data = await _dataService.getBaseSalaryData();

      if (data == null) return;

      setState(() {
        // Load base salary data with null safety
        controllers['alti_gun']?.text = data['sixthDay']?.toString() ?? '0';
        controllers['base_maas']?.text = data['baseSalary']?.toString() ?? '0';
        controllers['euro_rate']?.text = data['euroRate']?.toString() ?? '0';
        controllers['off_duty']?.text = data['offDutyCounts']?.toString() ?? '0';

        // Also update role if available
        if (data['role'] != null) {
          _role = data['role'] as String;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kayıtlı değerler yüklenirken hata: $e')),
        );
      }
    }
  }

  double convertTurkishNumber(String text) {
    if (text.isEmpty || text.trim().isEmpty) {
      return 0.0;
    }
    try {
      return double.parse(text.replaceAll(',', '.'));
    } catch (e) {
      throw 'Invalid number format: $text';
    }
  }

  int safeIntConvert(String text) {
    if (text.isEmpty || text.trim().isEmpty) {
      return 0;
    }
    try {
      return int.parse(text);
    } catch (e) {
      throw 'Invalid integer format: $text';
    }
  }

  Future<void> saveValues() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Check if a roster period is selected
        if (_selectedRoster == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Lütfen bir roster dönemi seçin'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        // Check if position is selected
        if (_role == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Lütfen pozisyonunuzu seçin (CCM/SCCM)'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        // Create updated data map - international overnight is derived
        // automatically from the selected roster, not entered manually
        final savedBaseData = await _dataService.getBaseSalaryData();
        final rosterLayoverData = _selectedRoster!.data['layoverCount'];
        final int internationalOvernight = rosterLayoverData is Map
            ? (rosterLayoverData['international'] as int? ?? 0)
            : ((savedBaseData?['internationalOvernight'] as num?)?.toInt() ?? 0);

        final updatedData = {
          'sixthDay': safeIntConvert(controllers['alti_gun']!.text),
          'internationalOvernight': internationalOvernight,
          'baseSalary': convertTurkishNumber(controllers['base_maas']!.text),
          'euroRate': convertTurkishNumber(controllers['euro_rate']!.text),
          'role': _role,
        };

        // Validate required fields
        final baseSalary = updatedData['baseSalary'] as double;
        final euroRate = updatedData['euroRate'] as double;

        if (baseSalary <= 0) {
          throw Exception('Base salary must be greater than 0');
        }
        if (euroRate <= 0) {
          throw Exception('Euro rate must be greater than 0');
        }

        // Off to duty count is entered manually (parsed info provides no value)
        offDutyCounts = safeIntConvert(controllers['off_duty']!.text);

        // Save all data in one operation, including fixes per roster period
        final rosterPeriod = _selectedRoster!.data['rosterPeriod'] as String?;
        await _dataService.saveBaseSalaryData(
          sixthDay: updatedData['sixthDay'] as int,
          internationalOvernight: updatedData['internationalOvernight'] as int,
          baseSalary: updatedData['baseSalary'] as double,
          euroRate: updatedData['euroRate'] as double,
          offDutyCounts: offDutyCounts,
          rosterPeriod: rosterPeriod,
        );

        // Calculate components for saving
        final baseSalaryData = {
          'baseSalary': convertTurkishNumber(controllers['base_maas']!.text),
          'sixthDay': safeIntConvert(controllers['alti_gun']!.text),
          'internationalOvernight': updatedData['internationalOvernight'],
          'euroRate': convertTurkishNumber(controllers['euro_rate']!.text),
        };

        // Get domestic commission for the roster period
        final domesticCommission = await _dataService.getDomesticCommission(rosterPeriod);

        CalculationService.calculateComponents(
          isSCCM: _role == 'SCCM',
          dutyHours: dutyHours,
          nightHours: nightHours,
          legCounts: legCounts,
          commission: commission,
          baseSalaryData: baseSalaryData,
          layoverCount: layoverCount,
          offDutyCounts: offDutyCounts,
          domesticCommission: domesticCommission,
        );

        // Reset fixes after calculation (except euro rate)
        setState(() {
          controllers['alti_gun']?.text = '0';
          controllers['off_duty']?.text = '0';
          // controllers['euro_rate'] stays as is
        });

        if (mounted) {
          // Navigate to result screen
          await _navigateToResult();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Kaydetme başarısız: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String? validateNumber(String? value, {bool isInteger = false}) {
    if (value == null || value.isEmpty) {
      return null;
    }
    try {
      if (isInteger) {
        safeIntConvert(value);
      } else {
        convertTurkishNumber(value);
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> _showRosterSelectionDialog() async {
    final List<PdfResult> rosterHistory = await DataService()
        .getRosterHistory();

    // Notifier so the dialog list refreshes when a period is deleted
    final ValueNotifier<List<PdfResult>> historyNotifier =
        ValueNotifier<List<PdfResult>>(rosterHistory);

    if (!mounted) return;

    await showDialog(
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
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.fromRGBO(
                        21,
                        123,
                        163,
                        1.0,
                      ), // Match app's main gradient start
                      Color.fromRGBO(
                        146,
                        74,
                        26,
                        0.8,
                      ), // Match app's main gradient end
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
                            Icons.calendar_month,
                            color: Colors.orange[300],
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Roster Dönemi Seçin',
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
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: ValueListenableBuilder<List<PdfResult>>(
                        valueListenable: historyNotifier,
                        builder: (context, currentHistory, _) {
                          return currentHistory.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 32.0,
                                      horizontal: 24.0,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.hourglass_empty,
                                          color: Colors.white.withAlpha(179),
                                          size: 64,
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'Henüz roster analizi yapılmamış',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount: currentHistory.length,
                                  itemBuilder: (context, index) {
                                    final result = currentHistory[index];
                                    final isSelected =
                                        _selectedRoster?.date == result.date;

                                    return Container(
                                      margin: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: isSelected
                                            ? Colors.orange.withAlpha(40)
                                            : Colors.white.withAlpha(15),
                                      ),
                                      // Wrap the ListTile in its own transparent Material so its
                                      // background and ink splashes paint ABOVE the Container's
                                      // background color instead of the dialog's Material below
                                      // it. Fixes the Flutter debug error:
                                      // "ListTile background color or ink splashes may be invisible."
                                      child: Material(
                                        type: MaterialType.transparency,
                                        child: ListTile(
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 12,
                                          ),
                                          title: Text(
                                            '${result.data['rosterPeriod']}',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              fontSize: 16,
                                            ),
                                          ),
                                          leading: Icon(
                                            isSelected
                                                ? Icons.check_circle
                                                : Icons.calendar_today,
                                            color: isSelected
                                                ? Colors.orange[300]
                                                : Colors.white.withAlpha(179),
                                          ),
                                          trailing: IconButton(
                                            icon: Icon(
                                              Icons.delete_outline,
                                              color: Colors.red[300],
                                              size: 22,
                                            ),
                                            tooltip: 'Sil',
                                            onPressed: () => _deleteRosterPeriod(
                                              context,
                                              result,
                                              historyNotifier,
                                            ),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          onTap: () async {
                                            setState(() {
                                              _selectedRoster = result;
                                            });
                                            Navigator.of(context).pop();
                                            await _loadInitialData();
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                );
                        },
                      ),
                    ),

                    // Footer with increased top padding
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 24.0,
                        bottom: 16.0,
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
                          'Kapat',
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

    historyNotifier.dispose();
  }

  // Confirms and deletes a roster period from history and refreshes the
  // selection dialog list via the provided notifier.
  Future<void> _deleteRosterPeriod(
    BuildContext dialogContext,
    PdfResult result,
    ValueNotifier<List<PdfResult>> historyNotifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: dialogContext,
      builder: (BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
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
                    'Silme İşlemi',
                    style: TextStyle(
                      color: Colors.orange[100],
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Bu roster dönemini silmek istediğinizden emin misiniz?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text(
                        'İptal',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text(
                        'Sil',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await DataService().deleteFromRosterHistory(result);

      // Remove the deleted period from the dialog's displayed list
      final updatedList = List<PdfResult>.from(historyNotifier.value);
      updatedList.remove(result);
      historyNotifier.value = updatedList;

      // Clear the selection if the deleted roster was the selected one
      if (_selectedRoster?.date == result.date && mounted) {
        setState(() {
          _selectedRoster = null;
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kayıt başarıyla silindi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('İşlem hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _navigateToBaseSalaryDetermination() async {
    // Load saved role if not already loaded
    _role ??= await _dataService.getRoleSelection();

    // Check if the widget is still mounted before using context
    if (!mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => const BaseSalaryServiceScreen(),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        // Update base salary and role from result
        controllers['base_maas']?.text = result['salary'].toString();
        if (result['role'] != null) {
          _role = result['role'] as String;
        }
      });

      // Reload saved data to ensure everything is in sync
      await loadSavedData();
    }
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
                              'Maaş Hesaplama Yardımı',
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
                              '⚙️ Base Maaş Belirleme',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '"Base Maaş Belirlemek İçin Tıklayınız" butonuna tıklayarak:',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '• Pozisyonunuzu seçin (CCM/SCCM)\n'
                              '• Deneyim yılınızı girin\n'
                              '• Otomatik maaş hesaplaması yapılır\n'
                              '• Güncel euro kuru otomatik alınır',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '📝 Bilgi Girişi',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '• 6. Gün Uçuş Adedi: Aylık 6. gün uçuş sayısı\n'
                              '• Dış Hat Yatı: Uluslararası yatı sayısı\n'
                              '• Euro Kuru: Güncel TL/EUR kuru\n'
                              '• İç Hat Yatı Düzenle: Yerel yatı düzeltmesi',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '📅 Roster Seçimi',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '• "Dönem Seçiniz" butonuna tıklayın\n'
                              '• Analiz edilmiş roster dönemlerinden birini seçin\n'
                              '• Roster verisi otomatik olarak yüklenir\n'
                              '• Komisyon bilgileri dahil edilir',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '🔢 Hesaplama',
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '• Tüm bilgileri doldurun\n'
                              '• "Hesapla" butonuna tıklayın\n'
                              '• Detaylı maaş dökümü görüntülenir\n'
                              '• Sonuç geçmiş maaşlarınıza kaydedilir',
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
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(
            'Bilgileri Giriniz',
            style: TextStyle(
              color: Color(0xFFED6C02),
              fontSize: 24,
              fontWeight: FontWeight.w500,
              fontFamily: 'Poppins',
            ),
          ),
          centerTitle: false,
          elevation: 0,
          automaticallyImplyLeading: false,
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
                Navigator.pushNamedAndRemoveUntil(context, Routes.welcome, (route) => false);
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
                  const SizedBox(height: 100), // Add spacing below AppBar
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [

                            
                            if (fields.first.$2 == 'base_maas') ...[
                              ElevatedButton(
                                onPressed:
                                    _navigateToBaseSalaryDetermination, // Updated this line
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(
                                    92,
                                    79,
                                    172,
                                    254,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                child: const Text(
                                  'Base Maaş Belirlemek İçin Tıklayınız',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            ...fields.map((field) {
                              final isInteger = ['alti_gun', 'off_duty'].contains(field.$2);
                              final isEuroRate = field.$2 == 'euro_rate';

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: TextFormField(
                                  controller: controllers[field.$2],
                                  readOnly: field.$2 == 'base_maas',
                                  enabled: field.$2 != 'base_maas',
                                  keyboardType: TextInputType.text,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) =>
                                      FocusScope.of(context).unfocus(),
                                  inputFormatters: field.$2 == 'base_maas'
                                      ? []
                                      : [
                                          if (isInteger)
                                            FilteringTextInputFormatter
                                                .digitsOnly
                                          else if (isEuroRate)
                                            FilteringTextInputFormatter.allow(
                                              RegExp(r'^\d*\.?\d{0,2}$'),
                                            )
                                          else
                                            FilteringTextInputFormatter.allow(
                                              RegExp(r'^\d*\.?\d*$'),
                                            ),
                                        ],
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: field.$1,
                                    labelStyle: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                    enabledBorder: const OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.white30,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.orange[300]!,
                                      ),
                                    ),
                                    errorBorder: const OutlineInputBorder(
                                      borderSide: BorderSide(color: Colors.red),
                                    ),
                                    focusedErrorBorder:
                                        const OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.red,
                                          ),
                                        ),
                                  ),
                                  validator: (value) => validateNumber(
                                    value,
                                    isInteger: isInteger,
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _showRosterSelectionDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromRGBO(
                                  146,
                                  74,
                                  26,
                                  0.8,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              child: Text(
                                _selectedRoster != null
                                    ? 'Seçili Dönem: ${_selectedRoster!.data['rosterPeriod']}'
                                    : 'Dönem Seçiniz',
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: saveValues,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFED6C02),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              child: const Text(
                                'Hesapla',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

  @override
  void dispose() {
    for (var controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
