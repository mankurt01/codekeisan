import 'package:flutter/material.dart';
import '../models/pdf_result.dart';
import '../services/data_service.dart';
import 'roster_calendar_screen.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Add this import

// Convert to StatefulWidget to manage state for deletions
class RosterHistoryScreen extends StatefulWidget {
  const RosterHistoryScreen({super.key});

  @override
  State<RosterHistoryScreen> createState() => _RosterHistoryScreenState();
}

class _RosterHistoryScreenState extends State<RosterHistoryScreen> {
  late Future<List<PdfResult>> _resultsFuture;
  int? _selectedYear;
  int? _selectedMonth;

  void calculateTotal() {
    // This method is just for compatibility with the selection methods
    // Roster history screen doesn't need total calculation
  }

  @override
  void initState() {
    super.initState();
    _resultsFuture = DataService().getRosterHistory();
  }

  Future<void> _deleteResult(PdfResult result) async {
    try {
      await DataService().deleteFromRosterHistory(result);
      setState(() {
        _resultsFuture = DataService().getRosterHistory();
      });
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

  // Add this method to extract month from roster period
  int _getMonthFromRosterPeriod(PdfResult result) {
    try {
      // Extract the roster period from result data
      String rosterPeriod = result.data['rosterPeriod'] as String;

      // Parse to get the first part of the date range (e.g., "01Sep24" from "01Sep24-31Sep24")
      String startDateStr = rosterPeriod.split('-')[0].trim();

      // Extract month abbreviation (e.g., "Sep" from "01Sep24")
      String monthAbbr = startDateStr.substring(2, 5);

      // Map month abbreviations to month numbers
      Map<String, int> monthMap = {
        'Jan': 1,
        'Feb': 2,
        'Mar': 3,
        'Apr': 4,
        'May': 5,
        'Jun': 6,
        'Jul': 7,
        'Aug': 8,
        'Sep': 9,
        'Oct': 10,
        'Nov': 11,
        'Dec': 12,
      };

      return monthMap[monthAbbr] ??
          result.date.month; // Fallback to file date if parsing fails
    } catch (e) {
      debugPrint('Error parsing roster period: $e');
      return result.date.month; // Fallback to file date
    }
  }

  // Add this method to extract year from roster period
  int _getYearFromRosterPeriod(PdfResult result) {
    try {
      // Extract the roster period from result data
      String rosterPeriod = result.data['rosterPeriod'] as String;

      // Parse to get the first part of the date range (e.g., "01Sep24" from "01Sep24-31Sep24")
      String startDateStr = rosterPeriod.split('-')[0].trim();

      // Extract year (e.g., "24" from "01Sep24")
      String yearStr = startDateStr.substring(5);

      // Convert to full year (assuming 20xx for simplicity)
      int year = 2000 + int.parse(yearStr);

      return year;
    } catch (e) {
      debugPrint('Error parsing roster period year: $e');
      return result.date.year; // Fallback to file date
    }
  }

  // Method to get off days count from various possible field names
  String _getOffDaysCount(PdfResult result) {
    try {
      // Try multiple possible field names for off days
      final data = result.data;
      
      // Check for direct count fields first
      if (data['offDutyCounts'] != null && data['offDutyCounts'] != 0) {
        return data['offDutyCounts'].toString();
      }
      
      if (data['offDutyDays'] != null && data['offDutyDays'] != 0) {
        return data['offDutyDays'].toString();
      }
      
      if (data['off_duty_days'] != null && data['off_duty_days'] != 0) {
        return data['off_duty_days'].toString();
      }
      
      // Check for off days list (count the items)
      if (data['offDays'] is List) {
        final offDaysList = data['offDays'] as List;
        return offDaysList.length.toString();
      }
      
      // Check for other possible field variations
      if (data['off_days'] is List) {
        final offDaysList = data['off_days'] as List;
        return offDaysList.length.toString();
      }
      
      if (data['restDays'] is List) {
        final restDaysList = data['restDays'] as List;
        return restDaysList.length.toString();
      }
      
      // If numeric value in other fields
      if (data['restDays'] != null && data['restDays'] is num) {
        return data['restDays'].toString();
      }
      
      // Default fallback
      return '0';
    } catch (e) {
      debugPrint('Error getting off days count: $e');
      return '0';
    }
  }

  // Method to get AVAC days count from off days list
  String _getAvacDaysCount(PdfResult result) {
    try {
      final data = result.data;
      
      // Check for off days list and count AVAC days
      if (data['offDays'] is List) {
        final offDaysList = data['offDays'] as List;
        int avacCount = 0;
        
        for (final offDay in offDaysList) {
          if (offDay is Map<String, dynamic>) {
            final type = offDay['type'] as String?;
            if (type == 'AVAC' || type == 'Vac') {
              avacCount++;
            }
          }
        }
        
        return avacCount.toString();
      }
      
      // Fallback: check for separate AVAC fields
      final avacDaysFields = ['avacDays', 'AVAC', 'avac', 'vacationDays', 'annualLeave'];
      for (final field in avacDaysFields) {
        if (data.containsKey(field)) {
          final fieldValue = data[field];
          if (fieldValue is List) {
            return fieldValue.length.toString();
          } else if (fieldValue is num && fieldValue > 0) {
            return fieldValue.toString();
          } else if (fieldValue is String) {
            final parsed = int.tryParse(fieldValue) ?? 0;
            if (parsed > 0) return parsed.toString();
          }
        }
      }
      
      return '0';
    } catch (e) {
      debugPrint('Error getting AVAC days count: $e');
      return '0';
    }
  }

  // Modify the existing methods to use roster period dates
  List<int> _getYears(List<PdfResult> results) {
    return results
        .map((result) => _getYearFromRosterPeriod(result))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
  }

  List<int> _getMonths(List<PdfResult> results, int year) {
    return results
        .where((result) => _getYearFromRosterPeriod(result) == year)
        .map((result) => _getMonthFromRosterPeriod(result))
        .toSet()
        .toList()
      ..sort();
  }

  String _getMonthName(int month) {
    return DateFormat.MMMM('tr_TR').format(DateTime(0, month));
  }

  void _selectYear(BuildContext context, List<int> years) {
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
                    itemCount: years.length + 1,
                    itemBuilder: (context, index) {
                      final isAllYears = index == 0;
                      final year = isAllYears ? null : years[index - 1];

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
                            isAllYears ? 'Tüm Yıllar' : year.toString(),
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
                              _selectedYear = year;
                              _selectedMonth = null;
                              if (year == null) {
                                _selectedMonth = null;
                              }
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

  void _selectMonth(BuildContext context, List<int> months) {
    if (_selectedYear == null) return;

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
                    itemCount: months.length + 1,
                    itemBuilder: (context, index) {
                      final isAllMonths = index == 0;
                      final month = isAllMonths ? null : months[index - 1];

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
                            isAllMonths ? 'Tüm Aylar' : _getMonthName(month!),
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
                              _selectedMonth = month;
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

  @override
  Widget build(BuildContext context) {
    // Initialize the locale data
    initializeDateFormatting('tr_TR', null);
    debugPrint('Building RosterHistoryScreen');
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        title: Text(
          'Roster Geçmişi',
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
            Padding(
              padding: const EdgeInsets.only(
                top: 100,
              ), // Add padding below AppBar
              child: FutureBuilder<List<PdfResult>>(
                future: _resultsFuture,
                builder: (context, snapshot) {
                  debugPrint(
                    'FutureBuilder state: ${snapshot.connectionState}',
                  );

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  if (snapshot.hasError) {
                    debugPrint(
                      'Error in RosterHistoryScreen: ${snapshot.error}',
                    );
                    return Center(
                      child: Text(
                        'Hata: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  final allResults = List<PdfResult>.from(snapshot.data ?? []);

                  if (allResults.isEmpty) {
                    return const Center(
                      child: Text(
                        'Henüz roster analiz geçmişi bulunmamaktadır.',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  // Get all years
                  final years = _getYears(allResults);

                  // Initialize selected year if not set
                  if (_selectedYear == null && years.isNotEmpty) {
                    _selectedYear = years.first;
                  }

                  // Get months for selected year
                  final months = _selectedYear != null
                      ? _getMonths(allResults, _selectedYear!)
                      : <int>[];

                  // Don't auto-initialize month - let user explicitly select "All Months" or a specific month

                  // Filter results based on selection
                  final results = (() {
                    // Filter by year/month as before
                    List<PdfResult> filtered = allResults.where((result) {
                      bool matchesFilter = true;

                      if (_selectedYear != null) {
                        matchesFilter =
                            _getYearFromRosterPeriod(result) == _selectedYear;
                      }

                      if (matchesFilter && _selectedMonth != null) {
                        matchesFilter =
                            _getMonthFromRosterPeriod(result) ==
                            _selectedMonth;
                      }

                      return matchesFilter;
                    }).toList();

                    // If "All Months" is selected, deduplicate by rosterPeriod, keep only latest by date
                    if (_selectedMonth == null) {
                      debugPrint('Deduplicating roster history - found ${filtered.length} entries');
                      final Map<String, PdfResult> latestByPeriod = {};
                      for (final result in filtered) {
                        final period = result.data['rosterPeriod'] as String? ?? '';
                        debugPrint('Processing period: $period, date: ${result.date}, file: ${result.fileName}');
                        if (!latestByPeriod.containsKey(period) ||
                            result.date.isAfter(latestByPeriod[period]!.date)) {
                          latestByPeriod[period] = result;
                          debugPrint('Updated latest for period $period to file: ${result.fileName}');
                        }
                      }
                      filtered = latestByPeriod.values.toList();
                      debugPrint('After deduplication: ${filtered.length} entries');
                    } else {
                      debugPrint('Specific month selected ($_selectedMonth), not deduplicating');
                    }

                    // Sort as before
                    filtered.sort((a, b) {
                      int aYear = _getYearFromRosterPeriod(a);
                      int bYear = _getYearFromRosterPeriod(b);

                      if (aYear != bYear) {
                        return bYear.compareTo(aYear); // Descending year
                      }

                      int aMonth = _getMonthFromRosterPeriod(a);
                      int bMonth = _getMonthFromRosterPeriod(b);

                      if (aMonth != bMonth) {
                        return bMonth.compareTo(aMonth); // Descending month
                      }

                      return b.date.compareTo(a.date); // Finally sort by file date
                    });

                    return filtered;
                  })();

                  return Column(
                    children: [
                      // Year and month selectors
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            // Year dropdown
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors:
                                        _selectedMonth == null &&
                                            _selectedYear != null
                                        ? const [
                                            Color.fromRGBO(239, 108, 0, 0.8),
                                            Color.fromRGBO(239, 108, 0, 0.6),
                                          ]
                                        : const [
                                            Color.fromRGBO(21, 123, 163, 0.9),
                                            Color.fromRGBO(146, 74, 26, 0.9),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: ElevatedButton(
                                  onPressed: () => _selectYear(context, years),
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
                                    _selectedYear != null
                                        ? '$_selectedYear'
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
                            ),
                            const SizedBox(width: 12),
                            // Month dropdown (only enabled if year is selected)
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors:
                                        _selectedYear != null &&
                                            _selectedMonth != null
                                        ? const [
                                            Color.fromRGBO(239, 108, 0, 0.8),
                                            Color.fromRGBO(239, 108, 0, 0.6),
                                          ]
                                        : const [
                                            Color.fromRGBO(21, 123, 163, 0.9),
                                            Color.fromRGBO(146, 74, 26, 0.9),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: ElevatedButton(
                                  onPressed: () =>
                                      _selectMonth(context, months),
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
                                    _selectedMonth != null
                                        ? _getMonthName(_selectedMonth!)
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
                            ),
                          ],
                        ),
                      ),

                      // Results list
                      Expanded(
                        child: results.isEmpty
                            ? const Center(
                                child: Text(
                                  'Seçilen filtrelere uygun veri bulunamadı.',
                                  style: TextStyle(color: Colors.white),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: results.length,
                                itemBuilder: (context, index) {
                                  final result = results[index];
                                  debugPrint(
                                    'Building item $index: ${result.fileName}',
                                  );
                                  return Dismissible(
                                    key: Key(result.date.toIso8601String()),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(
                                        right: 20.0,
                                      ),
                                      color: Colors.red,
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                      ),
                                    ),
                                    onDismissed: (direction) =>
                                        _deleteResult(result),
                                    confirmDismiss: (direction) async {
                                      return await showDialog(
                                        context: context,
                                        builder: (BuildContext context) => Dialog(
                                          backgroundColor: Colors.transparent,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color.fromRGBO(
                                                    21,
                                                    123,
                                                    163,
                                                    1.0,
                                                  ),
                                                  Color.fromRGBO(
                                                    146,
                                                    74,
                                                    26,
                                                    0.8,
                                                  ),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 16.0,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange[800],
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                          topLeft:
                                                              Radius.circular(
                                                                16,
                                                              ),
                                                          topRight:
                                                              Radius.circular(
                                                                16,
                                                              ),
                                                        ),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      'Silme İşlemi',
                                                      style: TextStyle(
                                                        color:
                                                            Colors.orange[100],
                                                        fontSize: 24,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        letterSpacing: 1.2,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const Padding(
                                                  padding: EdgeInsets.all(16.0),
                                                  child: Text(
                                                    'Bu kaydı silmek istediğinizden emin misiniz?',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                    16.0,
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceEvenly,
                                                    children: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              context,
                                                            ).pop(false),
                                                        child: const Text(
                                                          'İptal',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              context,
                                                            ).pop(true),
                                                        style:
                                                            TextButton.styleFrom(
                                                              backgroundColor:
                                                                  Colors.red,
                                                            ),
                                                        child: const Text(
                                                          'Sil',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                          ),
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
                                    },
                                    child: Card(
                                      color: Colors.white.withAlpha(
                                        (0.1 * 255).toInt(),
                                      ),
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 4,
                                        horizontal: 8,
                                      ),
                                      child: ListTile(
                                        title: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Dönem: ${result.data['rosterPeriod']}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              DateFormat(
                                                'dd MMMM HH:mm',
                                                'tr_TR',
                                              ).format(result.date),
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        leading: const Icon(
                                          Icons.history,
                                          color: Colors.white,
                                        ),
                                        trailing: const Icon(
                                          Icons.chevron_right,
                                          color: Colors.white,
                                        ),
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => Dialog(
                                              backgroundColor:
                                                  Colors.transparent,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      const LinearGradient(
                                                        colors: [
                                                          Color.fromRGBO(
                                                            21,
                                                            123,
                                                            163,
                                                            1.0,
                                                          ),
                                                          Color.fromRGBO(
                                                            146,
                                                            74,
                                                            26,
                                                            0.8,
                                                          ),
                                                        ],
                                                        begin:
                                                            Alignment.topLeft,
                                                        end: Alignment
                                                            .bottomRight,
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withAlpha(77),
                                                      spreadRadius: 2,
                                                      blurRadius: 8,
                                                      offset: const Offset(
                                                        0,
                                                        4,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 16.0,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Colors.orange[800],
                                                        borderRadius:
                                                            const BorderRadius.only(
                                                              topLeft:
                                                                  Radius.circular(
                                                                    16,
                                                                  ),
                                                              topRight:
                                                                  Radius.circular(
                                                                    16,
                                                                  ),
                                                            ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          const SizedBox(
                                                              width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              '🛫 Roster Analizi 🛬',
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .orange[100],
                                                                fontSize: 24,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons.open_in_new,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                            tooltip:
                                                                'Tam Takvim Ekranına Git',
                                                            onPressed: () =>
                                                                _openRosterCalendar(
                                                                    result),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            16.0,
                                                          ),
                                                      child: SingleChildScrollView(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            RichText(
                                                              text: TextSpan(
                                                                style: const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize:
                                                                      16.0,
                                                                  height: 1.2,
                                                                ),
                                                                children: [
                                                                  const TextSpan(
                                                                    text:
                                                                        '\n📅 Roster Dönemi: ',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          18,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color: Colors
                                                                          .orange,
                                                                    ),
                                                                  ),
                                                                  TextSpan(
                                                                    text:
                                                                        '${result.data['rosterPeriod']}\n\n',
                                                                  ),
                                                                  const TextSpan(
                                                                    text:
                                                                        '🚀 Uçuş ve Görev Süreleri\n',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          17,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      color: Colors
                                                                          .lightBlueAccent,
                                                                    ),
                                                                  ),
                                                                  TextSpan(
                                                                    text:
                                                                        '''
   ✈️ Toplam Uçuş Süresi: ${result.data['totalFlightTime']}
   ⏳ Toplam Görev Süresi: ${result.data['totalDutyTime']}
   🌙 Gece Saatleri: ${result.data['nightHours']}
   💪 İzin Günleri: ${_getOffDaysCount(result)}${int.parse(_getAvacDaysCount(result)) > 0 ? '\n   🏖️ AVAC Günleri: ${_getAvacDaysCount(result)}' : ''}\n
''',
                                                                  ),
                                                                  const TextSpan(
                                                                    text:
                                                                        '✈️ Uçuş Düzeni\n',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          17,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      color: Colors
                                                                          .lightBlueAccent,
                                                                    ),
                                                                  ),
                                                                  TextSpan(
                                                                    text:
                                                                        '''
   🔄 3-Sektör Uçuşları: ${(result.data['flightCounts'] as Map)['3']}
   🔄 4-Sektör Uçuşları: ${(result.data['flightCounts'] as Map)['4']}
   🔄 5-Sektör Uçuşları: ${(result.data['flightCounts'] as Map)['5']}\n
''',
                                                                  ),
                                                                  const TextSpan(
                                                                    text:
                                                                        '🌍 Evimi Özledim Anları\n',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          17,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      color: Colors
                                                                          .lightBlueAccent,
                                                                    ),
                                                                  ),
                                                                  TextSpan(
                                                                    text:
                                                                        '   🗺 Toplam Yatı Sayısı: ${result.data['layoverCount']}',
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            8.0,
                                                          ),
                                                      child: TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              context,
                                                            ).pop(),
                                                        style: TextButton.styleFrom(
                                                          backgroundColor:
                                                              Colors
                                                                  .orange[800],
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 24,
                                                                vertical: 12,
                                                              ),
                                                        ),
                                                        child: const Text(
                                                          'Kapat',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the full-screen [RosterCalendarScreen] calendar. The screen
  /// self-loads the raw ICS text of the latest imported roster from
  /// roster history, so no schedule rebuild is needed here. Entries
  /// without raw ICS text (imported before this feature) will show the
  /// calendar's empty state.
  void _openRosterCalendar(PdfResult result) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const RosterCalendarScreen(),
      ),
    );
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
                        'Roster Geçmişi Nasıl Kullanılır?',
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
                        '🛫 Genel Bakış',
                        'Bu sayfa tüm roster analiz geçmişinizi gösterir. Her roster dönemi için sadece en son analiz edilen dosya görüntülenir.',
                      ),
                      const SizedBox(height: 16),
                      _buildHelpSection(
                        '📅 Filtreleme',
                        '• Yıla Göre: Belirli bir yılın roster dönemlerini görüntüler\n• Aya Göre: Belirli bir ayın roster dönemlerini görüntüler\n• Otomatik temizleme: Aynı dönem için birden fazla analiz varsa en yenisi tutulur',
                      ),
                      const SizedBox(height: 16),
                      _buildHelpSection(
                        '👆 Etkileşim',
                        '• Kartlara tıklayarak detaylı roster bilgilerini görüntüleyebilirsiniz\n• Sola kaydırarak kayıtları silebilirsiniz\n• Silme işlemi geri alınamaz - onay istenir',
                      ),
                      const SizedBox(height: 16),
                      _buildHelpSection(
                        '📊 Görüntülenen Bilgiler',
                        '• Roster dönemi (örn: 01Sep24 - 30Sep24)\n• Analiz tarihi\n• Uçuş süreleri, görev süreleri\n• Gece saatleri, off duty günleri\n• Sektör dağılımları (3, 4, 5 sektör)\n• Yatı sayısı',
                      ),
                      const SizedBox(height: 16),
                      _buildHelpSection(
                        '🔄 Veri Güncelleme',
                        'Yeni roster PDF\'i yüklediğinizde bu sayfa otomatik olarak güncellenir. Aynı dönem için tekrar analiz yaparsanız eski kayıt silinir.',
                      ),
                    ],
                  ),
                ),
              ),
              
              // Footer with "Anladım" button
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
