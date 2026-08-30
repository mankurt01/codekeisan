import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/data_service.dart';
import '../models/pdf_result.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late Future<Map<String, dynamic>> _statisticsFuture;

  // Cache of the last loaded statistics. Used to keep the UI showing the
  // previous data while a silent refresh (e.g. after returning to this
  // screen) is in progress.
  Map<String, dynamic>? _lastStats;

  // Route tracking: detects when this screen becomes the top-most route again
  // (e.g. after the salary history screen was popped) so fresh data can be
  // loaded silently.
  bool _routeWasCurrent = false;
  bool _routeTrackingInitialized = false;

  String selectedPeriod = 'year';
  int? selectedYear;
  String? selectedMonth;

  // Card selection state
  final Map<String, bool> breakdownSelections = {
    'dutyTime': false,
    'nightHours': false,
    'commission': false,
    'sectorsFlown': false,
    'offDays': false,
    'avacDays': false,
    'salary': true,
    'euroRate': true,
    'paymentMonth': false,
  };

  final List<String> months = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
  ];

  @override
  void initState() {
    super.initState();
    // Default to current year
    selectedYear = DateTime.now().year;
    _statisticsFuture = _loadStatistics();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
    if (_routeTrackingInitialized && !_routeWasCurrent && isCurrent) {
      // This screen was covered by another screen (e.g. Geçmiş Maaşlarım
      // where a salary may have been deleted) and is visible again ->
      // silently reload so deleted records disappear immediately.
      setState(() {
        _statisticsFuture = _loadStatistics();
      });
    }
    _routeWasCurrent = isCurrent;
    _routeTrackingInitialized = true;
  }

  /// Loads the statistics and caches the result in [_lastStats] so the UI can
  /// keep showing the previous data while a silent refresh is in progress.
  Future<Map<String, dynamic>> _loadStatistics() async {
    final result = await _computeStatistics();
    _lastStats = result;
    return result;
  }

  Future<Map<String, dynamic>> _computeStatistics() async {
    try {
      debugPrint('Loading statistics data...');
      
      // Get salary data
      final salaries = await DataService().getPreviousSalaries();
      debugPrint('Loaded ${salaries.length} salary records');
      
      // Get roster history
      final rosterHistory = await DataService().getRosterHistory();
      debugPrint('Loaded ${rosterHistory.length} roster records');
      
      final result = _calculateStatistics(salaries, rosterHistory);
      debugPrint('Statistics calculation completed');
      
      return result;
    } catch (e) {
      debugPrint('Error loading statistics: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      return {
        'salary': {
          'totalEarnings': {'euro': 0.0, 'tl': 0.0},
          'averageEarnings': {'euro': 0.0, 'tl': 0.0},
          'highestEarning': {'euro': 0.0, 'tl': 0.0, 'date': ''},
          'lowestEarning': {'euro': 0.0, 'tl': 0.0, 'date': ''},
          'totalCommission': 0.0,
          'averageCommission': 0.0,
          'totalDutyHours': 0.0,
          'averageDutyHours': 0.0,
          'totalNightHours': 0.0,
          'averageNightHours': 0.0,
          'monthlyBreakdown': <String, Map<String, double>>{},
          'componentBreakdown': <String, double>{},
          'count': 0,
        },
        'roster': {
          'totalFlightTime': 0.0,
          'averageFlightTime': 0.0,
          'totalDutyTime': 0.0,
          'averageDutyTime': 0.0,
          'totalLayovers': 0,
          'averageLayovers': 0.0,
          'totalOffDutyDays': 0,
          'averageOffDutyDays': 0.0,
          'flightsByType': <String, int>{},
          'sectorBreakdown': <String, int>{'3': 0, '4': 0, '5': 0},
          'count': 0,
        },
        'combined': {
          'totalHoursWorked': 0.0,
          'totalEarnings': 0.0,
          'hourlyRate': 0.0,
          'totalPeriods': 0,
        },
        'totalPeriods': 0,
      };
    }
  }

  Map<String, dynamic> _calculateStatistics(
    List<Map<String, dynamic>> salaries,
    List<PdfResult> rosterHistory,
  ) {
    // Filter data based on selected period
    final filteredSalaries = _filterSalaries(salaries);
    final filteredRoster = _filterRoster(rosterHistory);

    // Deduplicate data - keep only latest analysis for each roster period
    final deduplicatedSalaries = _deduplicateSalaryHistory(filteredSalaries);
    final deduplicatedRoster = _deduplicateRosterHistory(filteredRoster);

    // Calculate salary statistics
    final salaryStats = _calculateSalaryStatistics(deduplicatedSalaries);
    
    // Calculate roster statistics
    final rosterStats = _calculateRosterStatistics(deduplicatedRoster);
    
    // Calculate combined statistics
    final combinedStats = _calculateCombinedStatistics(deduplicatedSalaries, deduplicatedRoster);

    return {
      'salary': salaryStats,
      'roster': rosterStats,
      'combined': combinedStats,
      'totalPeriods': deduplicatedSalaries.length + deduplicatedRoster.length,
    };
  }

  List<Map<String, dynamic>> _filterSalaries(List<Map<String, dynamic>> salaries) {
    // Helper function to extract year from roster period
    int getYearFromRosterPeriod(String rosterPeriod) {
      try {
        // Extract year from roster period like "01Sep24 - 30Sep24" or "01Sep2024 - 30Sep2024"
        final parts = rosterPeriod.split('-');
        if (parts.isNotEmpty) {
          final startDate = parts[0].trim();
          final yearPart = startDate.substring(startDate.length - 2); // Get last 2 characters
          final year = int.tryParse(yearPart);
          if (year != null) {
            // Convert 2-digit year to 4-digit (24 -> 2024, 25 -> 2025, etc.)
            return year < 50 ? 2000 + year : 1900 + year;
          }
        }
        return DateTime.now().year; // Fallback to current year
      } catch (e) {
        return DateTime.now().year; // Fallback to current year
      }
    }

    if (selectedPeriod == 'all') {
      // When 'all' is selected, default to current year based on roster period
      final currentYear = DateTime.now().year;
      return salaries.where((salary) {
        final rosterPeriod = salary['rosterPeriod'] as String? ?? '';
        if (rosterPeriod.isNotEmpty) {
          return getYearFromRosterPeriod(rosterPeriod) == currentYear;
        }
        // Fallback to file date if no roster period
        final date = DateTime.parse(salary['date']);
        return date.year == currentYear;
      }).toList();
    }
    
    return salaries.where((salary) {
      if (selectedPeriod == 'year' && selectedYear != null) {
        final rosterPeriod = salary['rosterPeriod'] as String? ?? '';
        if (rosterPeriod.isNotEmpty) {
          return getYearFromRosterPeriod(rosterPeriod) == selectedYear;
        }
        // Fallback to file date if no roster period
        final date = DateTime.parse(salary['date']);
        return date.year == selectedYear;
      } else if (selectedPeriod == 'month' && selectedMonth != null) {
        final rosterPeriod = salary['rosterPeriod'] as String? ?? '';
        if (rosterPeriod.isNotEmpty) {
          final monthFromPeriod = getMonthFromRosterPeriod(rosterPeriod);
          return monthFromPeriod == selectedMonth;
        }
        // Fallback to file date if no roster period
        final date = DateTime.parse(salary['date']);
        return months[date.month - 1] == selectedMonth;
      }
      return true;
    }).toList();
  }

  String getMonthFromRosterPeriod(String rosterPeriod) {
    try {
      final startDateStr = rosterPeriod.split('-')[0].trim();
      final monthAbbr = startDateStr.substring(2, 5);
      final Map<String, int> monthMap = {
        'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
        'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
      };
      final monthNum = monthMap[monthAbbr] ?? 1;
      return months[monthNum - 1];
    } catch (e) {
      debugPrint('Error parsing roster period: $e');
      return 'Unknown';
    }
  }

  String _getPaymentMonthFromRosterPeriod(String rosterPeriod) {
    try {
      // Extract start date from roster period like "01Sep24 - 30Sep24"
      final startDateStr = rosterPeriod.split('-')[0].trim();
      final monthAbbr = startDateStr.substring(2, 5);
      final yearPart = startDateStr.substring(startDateStr.length - 2);
      
      
      
      // Convert 2-digit year to 4-digit
      final year = int.tryParse(yearPart);
      final fullYear = (year != null && year < 50) ? 2000 + year : 1900 + (year ?? 0);
      
      // Payment is typically in the following month
      final nextMonth = DateTime(fullYear, _getMonthNumber(monthAbbr) + 1);
      final paymentMonthName = months[nextMonth.month - 1];
      
      return '$paymentMonthName ${nextMonth.year}';
    } catch (e) {
      debugPrint('Error calculating payment month from roster period: $e');
      return 'Bilinmiyor';
    }
  }

  int _getMonthNumber(String monthAbbr) {
    final Map<String, int> monthMap = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };
    return monthMap[monthAbbr] ?? 1;
  }

  /// Extracts the month number (1-12) from a roster period like
  /// "01Sep24 - 30Sep24" (used for sorting monthly rows).
  int _getMonthNumberFromRosterPeriod(String rosterPeriod) {
    try {
      final startDateStr = rosterPeriod.split('-')[0].trim();
      final monthAbbr = startDateStr.substring(2, 5);
      return _getMonthNumber(monthAbbr);
    } catch (e) {
      debugPrint('Error parsing roster period for sorting: $e');
      return 1;
    }
  }

  /// Extracts the year from a roster period like "01Sep24 - 30Sep24"
  /// (used for sorting monthly rows).
  int _getYearNumberFromRosterPeriod(String rosterPeriod) {
    try {
      final startDateStr = rosterPeriod.split('-')[0].trim();
      final yearPart = startDateStr.substring(startDateStr.length - 2);
      final year = int.tryParse(yearPart);
      if (year != null) {
        return year < 50 ? 2000 + year : 1900 + year;
      }
      return DateTime.now().year;
    } catch (e) {
      debugPrint('Error parsing roster period year for sorting: $e');
      return DateTime.now().year;
    }
  }

  /// Creates an empty monthly breakdown row for the given period.
  Map<String, dynamic> _createMonthlyRow({
    required String monthLabel,
    required String rosterPeriod,
    required int sortYear,
    required int sortMonth,
  }) {
    return {
      'month': monthLabel,
      'rosterPeriod': rosterPeriod,
      'sortYear': sortYear,
      'sortMonth': sortMonth,
      'dutyHours': 0.0,
      'nightHours': 0.0,
      'layovers': 0,
      'leaveDays': 0,
      'commission': 0.0,
      'salaryTL': 0.0,
      'salaryEUR': 0.0,
      'sectorsFlown': 0.0,
      'euroRate': 0.0,
      'avacDays': 0,
      'paymentMonth': rosterPeriod.isNotEmpty
          ? _getPaymentMonthFromRosterPeriod(rosterPeriod)
          : 'Bilinmiyor',
    };
  }

  /// Fills a monthly breakdown row with the values of a salary record.
  void _applySalaryToMonthlyRow(Map<String, dynamic> row, Map<String, dynamic> salary) {
    final components = Map<String, double>.from(salary['components'] ?? {});
    final commission = components['commission'] ?? 0.0;

    row['dutyHours'] = (salary['dutyHours'] as num?)?.toDouble() ?? 0.0;
    row['nightHours'] = (salary['nightHours'] as num?)?.toDouble() ?? 0.0;
    row['commission'] = commission;
    row['salaryTL'] = (salary['tl'] as num?)?.toDouble() ?? 0.0;
    row['salaryEUR'] = (salary['euro'] as num?)?.toDouble() ?? 0.0;

    // Extract euro rate from salary data - try multiple possible field names
    double euroRate = 0.0;
    if (components.containsKey('euro_rate')) {
      euroRate = components['euro_rate'] ?? 0.0;
    } else if (components.containsKey('euroRate')) {
      euroRate = components['euroRate'] ?? 0.0;
    } else if (components.containsKey('exchangeRate')) {
      euroRate = components['exchangeRate'] ?? 0.0;
    } else if (salary.containsKey('euroRate')) {
      euroRate = (salary['euroRate'] as num?)?.toDouble() ?? 0.0;
    } else if (salary.containsKey('euro_rate')) {
      euroRate = (salary['euro_rate'] as num?)?.toDouble() ?? 0.0;
    } else if (salary.containsKey('exchangeRate')) {
      euroRate = (salary['exchangeRate'] as num?)?.toDouble() ?? 0.0;
    }
    row['euroRate'] = euroRate;
  }

  List<PdfResult> _filterRoster(List<PdfResult> rosterHistory) {
    // Helper function to extract year from roster period
    int getYearFromRosterPeriod(String rosterPeriod) {
      try {
        // Extract year from roster period like "01Sep24 - 30Sep24" or "01Sep2024 - 30Sep2024"
        final parts = rosterPeriod.split('-');
        if (parts.isNotEmpty) {
          final startDate = parts[0].trim();
          final yearPart = startDate.substring(startDate.length - 2); // Get last 2 characters
          final year = int.tryParse(yearPart);
          if (year != null) {
            // Convert 2-digit year to 4-digit (24 -> 2024, 25 -> 2025, etc.)
            return year < 50 ? 2000 + year : 1900 + year;
          }
        }
        return DateTime.now().year; // Fallback to current year
      } catch (e) {
        return DateTime.now().year; // Fallback to current year
      }
    }

    if (selectedPeriod == 'all') {
      // When 'all' is selected, default to current year based on roster period
      final currentYear = DateTime.now().year;
      return rosterHistory.where((roster) {
        final rosterPeriod = roster.data['rosterPeriod'] as String? ?? '';
        if (rosterPeriod.isNotEmpty) {
          return getYearFromRosterPeriod(rosterPeriod) == currentYear;
        }
        // Fallback to file date if no roster period
        return roster.date.year == currentYear;
      }).toList();
    }
    
    return rosterHistory.where((roster) {
      if (selectedPeriod == 'year' && selectedYear != null) {
        final rosterPeriod = roster.data['rosterPeriod'] as String? ?? '';
        if (rosterPeriod.isNotEmpty) {
          return getYearFromRosterPeriod(rosterPeriod) == selectedYear;
        }
        // Fallback to file date if no roster period
        return roster.date.year == selectedYear;
      } else if (selectedPeriod == 'month' && selectedMonth != null) {
        final rosterPeriod = roster.data['rosterPeriod'] as String? ?? '';
        if (rosterPeriod.isNotEmpty) {
          final monthFromPeriod = getMonthFromRosterPeriod(rosterPeriod);
          return monthFromPeriod == selectedMonth;
        }
        // Fallback to file date if no roster period
        return months[roster.date.month - 1] == selectedMonth;
      }
      return true;
    }).toList();
  }

  /// Deduplicates salary history by roster period, keeping the latest analysis for each period
  List<Map<String, dynamic>> _deduplicateSalaryHistory(List<Map<String, dynamic>> salaries) {
    if (salaries.isEmpty) return salaries;
    
    // Group by roster period
    final Map<String, List<Map<String, dynamic>>> groupedByPeriod = {};
    
    for (final salary in salaries) {
      final rosterPeriod = salary['rosterPeriod'] as String? ?? '';
      if (rosterPeriod.isNotEmpty) {
        groupedByPeriod.putIfAbsent(rosterPeriod, () => []).add(salary);
      } else {
        // If no roster period, treat as unique (keep all records without roster period)
        final uniqueKey = 'no_period_${salary['date']}_${salary['id']}';
        groupedByPeriod[uniqueKey] = [salary];
      }
    }
    
    // For each roster period, keep only the latest calculation (by date)
    final List<Map<String, dynamic>> deduplicated = [];
    
    groupedByPeriod.forEach((period, periodSalaries) {
      if (periodSalaries.isNotEmpty) {
        // Sort by date (descending) and take the latest one
        periodSalaries.sort((a, b) {
          final dateA = DateTime.parse(a['date'] as String);
          final dateB = DateTime.parse(b['date'] as String);
          return dateB.compareTo(dateA); // Latest first
        });
        deduplicated.add(periodSalaries.first);
      }
    });
    
    return deduplicated;
  }

  /// Deduplicates roster history by roster period, keeping the latest analysis for each period
  List<PdfResult> _deduplicateRosterHistory(List<PdfResult> rosterHistory) {
    if (rosterHistory.isEmpty) return rosterHistory;
    
    // Group by roster period
    final Map<String, List<PdfResult>> groupedByPeriod = {};
    
    for (final roster in rosterHistory) {
      final rosterPeriod = roster.data['rosterPeriod'] as String? ?? '';
      if (rosterPeriod.isNotEmpty) {
        groupedByPeriod.putIfAbsent(rosterPeriod, () => []).add(roster);
      } else {
        // If no roster period, treat as unique (keep all records without roster period)
        final uniqueKey = 'no_period_${roster.date.toIso8601String()}_${roster.fileName}';
        groupedByPeriod[uniqueKey] = [roster];
      }
    }
    
    // For each roster period, keep only the latest analysis (by date)
    final List<PdfResult> deduplicated = [];
    
    groupedByPeriod.forEach((period, periodRosters) {
      if (periodRosters.isNotEmpty) {
        // Sort by date (descending) and take the latest one
        periodRosters.sort((a, b) => b.date.compareTo(a.date)); // Latest first
        deduplicated.add(periodRosters.first);
      }
    });
    
    return deduplicated;
  }

  Map<String, dynamic> _calculateSalaryStatistics(List<Map<String, dynamic>> salaries) {
    if (salaries.isEmpty) {
      return {
        'totalEarnings': {'euro': 0.0, 'tl': 0.0},
        'averageEarnings': {'euro': 0.0, 'tl': 0.0},
        'highestEarning': {'euro': 0.0, 'tl': 0.0, 'date': ''},
        'lowestEarning': {'euro': 0.0, 'tl': 0.0, 'date': ''},
        'totalCommission': 0.0,
        'averageCommission': 0.0,
        'totalDutyHours': 0.0,
        'averageDutyHours': 0.0,
        'totalNightHours': 0.0,
        'averageNightHours': 0.0,
        'monthlyBreakdown': <String, Map<String, double>>{},
        'componentBreakdown': <String, double>{},
        'count': 0,
      };
    }

    double totalEuro = 0, totalTl = 0, totalCommission = 0;
    double totalDutyHours = 0, totalNightHours = 0;
    double maxEuro = 0, minEuro = double.infinity;
    double maxTl = 0, minTl = double.infinity;
    String maxDate = '', minDate = '';
    
    Map<String, Map<String, double>> monthlyBreakdown = {};
    Map<String, double> componentTotals = {};

    for (final salary in salaries) {
      final euro = (salary['euro'] as num?)?.toDouble() ?? 0.0;
      final tl = (salary['tl'] as num?)?.toDouble() ?? 0.0;
      final date = salary['date'] as String;
      final components = Map<String, double>.from(salary['components'] ?? {});
      
      totalEuro += euro;
      totalTl += tl;
      totalCommission += (components['commission'] ?? 0.0);
      totalDutyHours += (salary['dutyHours'] as num?)?.toDouble() ?? 0.0;
      totalNightHours += (salary['nightHours'] as num?)?.toDouble() ?? 0.0;

      if (euro > maxEuro) {
        maxEuro = euro;
        maxDate = date;
      }
      if (euro < minEuro) {
        minEuro = euro;
        minDate = date;
      }

      // Monthly breakdown
      final monthKey = date.substring(0, 7); // YYYY-MM
      monthlyBreakdown[monthKey] = {
        'euro': (monthlyBreakdown[monthKey]?['euro'] ?? 0) + euro,
        'tl': (monthlyBreakdown[monthKey]?['tl'] ?? 0) + tl,
      };

      // Component breakdown
      components.forEach((key, value) {
        componentTotals[key] = (componentTotals[key] ?? 0) + value;
      });
    }

    return {
      'totalEarnings': {'euro': totalEuro, 'tl': totalTl},
      'averageEarnings': {
        'euro': totalEuro / salaries.length,
        'tl': totalTl / salaries.length,
      },
      'highestEarning': {'euro': maxEuro, 'tl': maxTl, 'date': maxDate},
      'lowestEarning': {'euro': minEuro, 'tl': minTl, 'date': minDate},
      'totalCommission': totalCommission,
      'averageCommission': totalCommission / salaries.length,
      'totalDutyHours': totalDutyHours,
      'averageDutyHours': totalDutyHours / salaries.length,
      'totalNightHours': totalNightHours,
      'averageNightHours': totalNightHours / salaries.length,
      'monthlyBreakdown': monthlyBreakdown,
      'componentBreakdown': componentTotals,
      'count': salaries.length,
    };
  }

  Map<String, dynamic> _calculateRosterStatistics(List<PdfResult> rosterHistory) {
    if (rosterHistory.isEmpty) {
      return {
        'totalFlightTime': 0.0,
        'averageFlightTime': 0.0,
        'totalDutyTime': 0.0,
        'averageDutyTime': 0.0,
        'totalLayovers': 0,
        'averageLayovers': 0.0,
        'totalOffDutyDays': 0,
        'averageOffDutyDays': 0.0,
        'flightsByType': <String, int>{},
        'sectorBreakdown': <String, int>{},
        'count': 0,
      };
    }

    double totalFlightTime = 0, totalDutyTime = 0;
    int totalLayovers = 0, totalOffDutyDays = 0, totalAvacDays = 0;
    Map<String, int> sectorBreakdown = {'3': 0, '4': 0, '5': 0};

    for (final roster in rosterHistory) {
      final data = roster.data;
      
      // Debug: Print available keys for the first few records
      if (rosterHistory.indexOf(roster) < 3) {
        debugPrint('Roster data keys: ${data.keys.toList()}');
        debugPrint('Sample data: $data');
      }
      
      // Parse flight time - comprehensive field name checking
      double flightTime = 0.0;
      final flightTimeFields = [
        'totalFlightTime', 'flightTime', 'flight_time', 'FlightTime',
        'FLIGHT_TIME', 'total_flight_time', 'blockTime', 'block_time',
        'flightHours', 'flight_hours', 'airTime', 'air_time'
      ];
      
      for (final field in flightTimeFields) {
        if (data.containsKey(field) && data[field] != null) {
          final value = data[field].toString();
          if (value.isNotEmpty && value != '0' && value != '0.0' && value != '0h') {
            // Handle various formats: "123.5h", "123.5", "123:30", etc.
            String cleanValue = value.replaceAll(RegExp(r'[hH\s]'), '');
            if (cleanValue.contains(':')) {
              // Handle "123:30" format (hours:minutes)
              final parts = cleanValue.split(':');
              if (parts.length == 2) {
                final hours = double.tryParse(parts[0]) ?? 0.0;
                final minutes = double.tryParse(parts[1]) ?? 0.0;
                flightTime = hours + (minutes / 60.0);
              }
            } else {
              flightTime = double.tryParse(cleanValue) ?? 0.0;
            }
            if (flightTime > 0) {
              debugPrint('Found flight time: $flightTime from field $field with value $value');
              break;
            }
          }
        }
      }
      totalFlightTime += flightTime;

      // Parse duty time - comprehensive field name checking
      double dutyTime = 0.0;
      final dutyTimeFields = [
        'totalDutyTime', 'dutyTime', 'duty_time', 'DutyTime',
        'DUTY_TIME', 'total_duty_time', 'dutyHours', 'duty_hours',
        'workTime', 'work_time', 'serviceTime', 'service_time'
      ];
      
      for (final field in dutyTimeFields) {
        if (data.containsKey(field) && data[field] != null) {
          final value = data[field].toString();
          if (value.isNotEmpty && value != '0' && value != '0.0' && value != '0h') {
            // Handle various formats: "123.5h", "123.5", "123:30", etc.
            String cleanValue = value.replaceAll(RegExp(r'[hH\s]'), '');
            if (cleanValue.contains(':')) {
              // Handle "123:30" format (hours:minutes)
              final parts = cleanValue.split(':');
              if (parts.length == 2) {
                final hours = double.tryParse(parts[0]) ?? 0.0;
                final minutes = double.tryParse(parts[1]) ?? 0.0;
                dutyTime = hours + (minutes / 60.0);
              }
            } else {
              dutyTime = double.tryParse(cleanValue) ?? 0.0;
            }
            if (dutyTime > 0) {
              debugPrint('Found duty time: $dutyTime from field $field with value $value');
              break;
            }
          }
        }
      }
      totalDutyTime += dutyTime;

      // Get layover count - comprehensive field checking
      final layoverFields = ['layoverCount', 'layovers', 'layover_count', 'nightCount', 'night_count', 'overnights'];
      int layoverCount = 0;
      for (final field in layoverFields) {
        if (data.containsKey(field)) {
          layoverCount = (data[field] as num?)?.toInt() ?? 0;
          if (layoverCount > 0) break;
        }
      }
      totalLayovers += layoverCount;

      // Get leave days (İzin Günleri) - comprehensive field checking
      final leaveDaysFields = ['offDays', 'leaveDays', 'izinGunleri'];
      int leaveDaysCount = 0;
      for (final field in leaveDaysFields) {
        if (data.containsKey(field)) {
          final fieldValue = data[field];
          if (fieldValue is List) {
            // Count only real leave days - AVAC/vacation entries are counted
            // separately as AVAC days and must not be double counted here.
            leaveDaysCount = _countLeaveDaysFromOffDaysField(fieldValue);
          } else if (fieldValue is num) {
            leaveDaysCount = fieldValue.toInt();
          } else if (fieldValue is String) {
            leaveDaysCount = int.tryParse(fieldValue) ?? 0;
          }
          if (leaveDaysCount > 0) break;
        }
      }
      totalOffDutyDays += leaveDaysCount;

      // Get AVAC days from offDays list
      int avacDaysCount = 0;
      final offDaysData = data['offDays'];
      if (offDaysData is List) {
        // Count AVAC days from the offDays list
        for (final offDay in offDaysData) {
          if (offDay is Map<String, dynamic>) {
            final type = offDay['type'] as String?;
            if (type == 'AVAC' || type == 'Vac') {
              avacDaysCount++;
            }
          }
        }
      } else {
        // Fallback: check for separate AVAC fields
        final avacDaysFields = ['avacDays', 'AVAC', 'avac', 'vacationDays', 'annualLeave'];
        for (final field in avacDaysFields) {
          if (data.containsKey(field)) {
            final fieldValue = data[field];
            if (fieldValue is List) {
              avacDaysCount = fieldValue.length;
            } else if (fieldValue is num) {
              avacDaysCount = fieldValue.toInt();
            } else if (fieldValue is String) {
              avacDaysCount = int.tryParse(fieldValue) ?? 0;
            }
            if (avacDaysCount > 0) break;
          }
        }
      }
      totalAvacDays += avacDaysCount;

      // Sector breakdown - comprehensive field checking
      final sectorFields = ['flightCounts', 'legCounts', 'sectorCounts', 'leg_counts', 'sector_counts'];
      Map<String, dynamic> flightCounts = {};
      for (final field in sectorFields) {
        if (data.containsKey(field) && data[field] is Map) {
          flightCounts = data[field] as Map<String, dynamic>;
          if (flightCounts.isNotEmpty) break;
        }
      }
      
      // Try different key formats for sectors
      final sectorKeys = [
        ['3', '4', '5'],
        ['leg3', 'leg4', 'leg5'],
        ['sector3', 'sector4', 'sector5'],
        ['3_sector', '4_sector', '5_sector']
      ];
      
      for (final keySet in sectorKeys) {
        final count3 = (flightCounts[keySet[0]] as num?)?.toInt() ?? 0;
        final count4 = (flightCounts[keySet[1]] as num?)?.toInt() ?? 0;
        final count5 = (flightCounts[keySet[2]] as num?)?.toInt() ?? 0;
        
        if (count3 > 0 || count4 > 0 || count5 > 0) {
          sectorBreakdown['3'] = (sectorBreakdown['3'] ?? 0) + count3;
          sectorBreakdown['4'] = (sectorBreakdown['4'] ?? 0) + count4;
          sectorBreakdown['5'] = (sectorBreakdown['5'] ?? 0) + count5;
          break;
        }
      }
    }

    debugPrint('Final totals - Flight Time: $totalFlightTime, Duty Time: $totalDutyTime');

    return {
      'totalFlightTime': totalFlightTime,
      'averageFlightTime': totalFlightTime / rosterHistory.length,
      'totalDutyTime': totalDutyTime,
      'averageDutyTime': totalDutyTime / rosterHistory.length,
      'totalLayovers': totalLayovers,
      'averageLayovers': totalLayovers / rosterHistory.length,
      'totalLeaveDays': totalOffDutyDays,
      'averageLeaveDays': totalOffDutyDays / rosterHistory.length,
      'totalAvacDays': totalAvacDays,
      'averageAvacDays': totalAvacDays / rosterHistory.length,
      'sectorBreakdown': sectorBreakdown,
      'count': rosterHistory.length,
    };
  }

  /// Counts non-AVAC leave days from an `offDays`-like field.
  ///
  /// Entries of type `AVAC`/`Vac` are excluded because they are counted
  /// separately as AVAC days. Previously they were counted in both totals.
  int _countLeaveDaysFromOffDaysField(dynamic offDaysField) {
    if (offDaysField is List) {
      final hasTypedEntries = offDaysField.any((offDay) => offDay is Map);
      if (!hasTypedEntries) return offDaysField.length;
      return offDaysField.where((offDay) {
        if (offDay is! Map) return true;
        final type = offDay['type']?.toString();
        return type != 'AVAC' && type != 'Vac';
      }).length;
    }
    return 0;
  }

  /// Counts AVAC days (`type == 'AVAC' || type == 'Vac'`) from an
  /// `offDays`-like field.
  int _countAvacDaysFromOffDaysField(dynamic offDaysField) {
    if (offDaysField is List) {
      var count = 0;
      for (final offDay in offDaysField) {
        if (offDay is Map<String, dynamic>) {
          final type = offDay['type'] as String?;
          if (type == 'AVAC' || type == 'Vac') {
            count++;
          }
        }
      }
      return count;
    }
    return 0;
  }

  Map<String, dynamic> _calculateCombinedStatistics(
    List<Map<String, dynamic>> salaries,
    List<PdfResult> rosterHistory,
  ) {
    double totalHoursWorked = 0;
    double totalEarnings = 0;
    
    // Salary records are the source of truth: use their duty hours and
    // earnings, and remember which roster periods they already cover.
    final Set<String> salaryPeriods = {};
    for (final salary in salaries) {
      totalHoursWorked += (salary['dutyHours'] as num?)?.toDouble() ?? 0.0;
      totalEarnings += (salary['euro'] as num?)?.toDouble() ?? 0.0;
      final rosterPeriod = salary['rosterPeriod'] as String? ?? '';
      if (rosterPeriod.isNotEmpty) {
        salaryPeriods.add(rosterPeriod);
      }
    }

    // Roster data only supplements periods that have no salary record,
    // otherwise the duty hours of the same period would be counted twice.
    int rosterOnlyPeriods = 0;
    for (final roster in rosterHistory) {
      final rosterPeriod = roster.data['rosterPeriod'] as String? ?? '';
      if (rosterPeriod.isNotEmpty && salaryPeriods.contains(rosterPeriod)) {
        continue;
      }
      rosterOnlyPeriods++;
      final dutyTimeStr = roster.data['totalDutyTime']?.toString() ?? '0h';
      final dutyTime = double.tryParse(dutyTimeStr.replaceAll('h', '')) ?? 0.0;
      totalHoursWorked += dutyTime;
    }

    return {
      'totalHoursWorked': totalHoursWorked,
      'totalEarnings': totalEarnings,
      'hourlyRate': totalHoursWorked > 0 ? totalEarnings / totalHoursWorked : 0.0,
      'totalPeriods': salaries.length + rosterOnlyPeriods,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        title: const Text(
          'İstatistikler',
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
        child: Column(
          children: [
            const SizedBox(height: 100),
            _buildPeriodSelector(),
            _buildBreakdownCards(),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _statisticsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    // Keep showing the previously loaded statistics while a
                    // silent refresh is running (avoids flicker).
                    if (_lastStats != null) {
                      return _buildStatisticsContent(_lastStats!);
                    }
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Hata: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  final stats = snapshot.data ?? {};
                  return _buildStatisticsContent(stats);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildFilterButton(
            text: selectedPeriod == 'year' && selectedYear != null
                ? '$selectedYear'
                : 'Yıla Göre',
            isActive: selectedPeriod == 'year',
            onPressed: () => _selectYear(context),
          ),
          _buildFilterButton(
            text: selectedPeriod == 'month' && selectedMonth != null
                ? selectedMonth!
                : 'Aya Göre',
            isActive: selectedPeriod == 'month',
            onPressed: () => _selectMonth(context),
          ),
          if (selectedPeriod != 'all')
            _buildFilterButton(
              text: 'Tüm ${DateTime.now().year}',
              onPressed: () {
                setState(() {
                  selectedPeriod = 'all';
                  selectedYear = null;
                  selectedMonth = null;
                  _statisticsFuture = _loadStatistics();
                });
              },
            ),
        ],
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsContent(Map<String, dynamic> stats) {
    final salaryStats = stats['salary'] as Map<String, dynamic>? ?? {};
    final rosterStats = stats['roster'] as Map<String, dynamic>? ?? {};
    final combinedStats = stats['combined'] as Map<String, dynamic>? ?? {};

    return RefreshIndicator(
      color: Colors.orange,
      backgroundColor: const Color(0xFF1F1D2B),
      onRefresh: () async {
        setState(() {
          _statisticsFuture = _loadStatistics();
        });
        await _statisticsFuture;
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildOverviewCard(salaryStats, rosterStats, combinedStats),
            const SizedBox(height: 16),
            _buildSalaryStatsCard(salaryStats),
            const SizedBox(height: 16),
            _buildRosterStatsCard(rosterStats),
            const SizedBox(height: 16),
            _buildMonthlyBreakdownTable(salaryStats, rosterStats),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(
    Map<String, dynamic> salaryStats,
    Map<String, dynamic> rosterStats,
    Map<String, dynamic> combinedStats,
  ) {
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
                  colors: [Color(0xFFFF4500), Color(0xFFFF8C00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.analytics, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Genel Özet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildOverviewRow(
              '💰 Toplam Kazanç (EUR)',
              '€${((salaryStats['totalEarnings'] as Map?)?['euro'] ?? 0.0).toStringAsFixed(2)}',
              Colors.orange,
            ),
            _buildOverviewRow(
              '💵 Toplam Kazanç (TL)',
              '₺${((salaryStats['totalEarnings'] as Map?)?['tl'] ?? 0.0).toStringAsFixed(2)}',
              Colors.orange,
            ),
            _buildOverviewRow(
              '💱 Ortalama Saatlik Ücret',
              '€${(combinedStats['hourlyRate'] ?? 0.0).toStringAsFixed(2)}',
              Colors.teal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryStatsCard(Map<String, dynamic> salaryStats) {
    if ((salaryStats['count'] ?? 0) == 0) {
      return Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: const Color(0xFF1F1D2B),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: const Text(
            'Maaş verisi bulunamadı',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    final totalEarnings = salaryStats['totalEarnings'] as Map<String, dynamic>;
    final averageEarnings = salaryStats['averageEarnings'] as Map<String, dynamic>;
    final highestEarning = salaryStats['highestEarning'] as Map<String, dynamic>;
    final lowestEarning = salaryStats['lowestEarning'] as Map<String, dynamic>;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: const Color(0xFF1F1D2B),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00BFFF), Color(0xFF1E90FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Maaş İstatistikleri',
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
            _buildStatRow('💰 Toplam Kazanç (EUR)', '€${totalEarnings['euro'].toStringAsFixed(2)}'),
            _buildStatRow('💵 Toplam Kazanç (TL)', '₺${totalEarnings['tl'].toStringAsFixed(2)}'),
            _buildStatRow('📊 Ortalama Maaş (EUR)', '€${averageEarnings['euro'].toStringAsFixed(2)}'),
            _buildStatRow('📈 En Yüksek Maaş', '€${highestEarning['euro'].toStringAsFixed(2)} (${highestEarning['date']})'),
            _buildStatRow('📉 En Düşük Maaş', '€${lowestEarning['euro'].toStringAsFixed(2)} (${lowestEarning['date']})'),
            _buildStatRow('💸 Toplam Komisyon', '€${salaryStats['totalCommission'].toStringAsFixed(2)}'),
            _buildStatRow('⏱️ Toplam Görev Saati', '${salaryStats['totalDutyHours'].toStringAsFixed(1)}h'),
            _buildStatRow('🌙 Toplam Gece Saati', '${salaryStats['totalNightHours'].toStringAsFixed(1)}h'),
          ],
        ),
      ),
    );
  }

  Widget _buildRosterStatsCard(Map<String, dynamic> rosterStats) {
    if ((rosterStats['count'] ?? 0) == 0) {
      return Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: const Color(0xFF1F1D2B),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: const Text(
            'Roster verisi bulunamadı',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    final sectorBreakdown = rosterStats['sectorBreakdown'] as Map<String, int>;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: const Color(0xFF1F1D2B),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF32CD32), Color(0xFF228B22)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flight_takeoff, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Roster İstatistikleri',
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
            _buildStatRow('✈️ Toplam Uçuş Saati', '${rosterStats['totalFlightTime'].toStringAsFixed(1)}h'),
            _buildStatRow('⏱️ Toplam Görev Saati', '${rosterStats['totalDutyTime'].toStringAsFixed(1)}h'),
            _buildStatRow('📊 Ortalama Uçuş Saati', '${rosterStats['averageFlightTime'].toStringAsFixed(1)}h'),
            _buildStatRow('📈 Ortalama Görev Saati', '${rosterStats['averageDutyTime'].toStringAsFixed(1)}h'),
            _buildStatRow('🏨 Toplam Yatı Sayısı', '${rosterStats['totalLayovers']} gece'),
            _buildStatRow('📅 Toplam İzin Günleri', '${rosterStats['totalLeaveDays']} gün'),
            _buildStatRow('📊 Ortalama İzin Günleri', '${rosterStats['averageLeaveDays'].toStringAsFixed(1)} gün'),
            _buildStatRow('🏖️ Toplam AVAC Günleri', '${rosterStats['totalAvacDays']} gün'),
            _buildStatRow('📊 Ortalama AVAC Günleri', '${rosterStats['averageAvacDays'].toStringAsFixed(1)} gün'),
            _buildStatRow('3️⃣ 3-Sektör Uçuşları', '${sectorBreakdown['3']} adet'),
            _buildStatRow('4️⃣ 4-Sektör Uçuşları', '${sectorBreakdown['4']} adet'),
            _buildStatRow('5️⃣ 5-Sektör Uçuşları', '${sectorBreakdown['5']} adet'),
          ],
        ),
      ),
    );
  }


  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyBreakdownTable(
    Map<String, dynamic> salaryStats,
    Map<String, dynamic> rosterStats,
  ) {
    // Dynamic columns based on breakdownSelections
    final columns = <DataColumn>[
      const DataColumn(
        label: Text(
          'Ay',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      if (breakdownSelections['dutyTime'] ?? false)
        const DataColumn(
          label: Text(
            'DT (hours)',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      if (breakdownSelections['nightHours'] ?? false)
        const DataColumn(
          label: Text(
            'Night Hours',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      if (breakdownSelections['commission'] ?? false)
        const DataColumn(
          label: Text(
            'Commission (€)',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      if (breakdownSelections['sectorsFlown'] ?? false)
        const DataColumn(
          label: Text(
            'Sectors Flown (hours)',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      if (breakdownSelections['offDays'] ?? false)
        const DataColumn(
          label: Text(
            'İzin Günleri',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      if (breakdownSelections['avacDays'] ?? false)
        const DataColumn(
          label: Text(
            'AVAC Günleri',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      if (breakdownSelections['salary'] ?? false)
        const DataColumn(
          label: Text(
            'Salary (€)',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      if (breakdownSelections['salary'] ?? false)
        const DataColumn(
          label: Text(
            'Salary (₺)',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      if (breakdownSelections['euroRate'] ?? false)
        const DataColumn(
          label: Text(
            'Euro Rate (₺)',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      if (breakdownSelections['paymentMonth'] ?? false)
        const DataColumn(
          label: Text(
            'Ödeme Ayı',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
    ];

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getMonthlyBreakdownData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            color: const Color(0xFF1F1D2B),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          );
        }

        final monthlyData = snapshot.data ?? [];
        if (monthlyData.isEmpty) {
          return Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            color: const Color(0xFF1F1D2B),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: const Text(
                'Aylık veri bulunamadı',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
          );
        }

        // Calculate totals for selected columns
        final totals = <String, num>{};
        for (final data in monthlyData) {
          if (breakdownSelections['dutyTime'] ?? false) {
            totals['dutyHours'] = (totals['dutyHours'] ?? 0) + (num.tryParse(data['dutyHours'].toString()) ?? 0);
          }
          if (breakdownSelections['nightHours'] ?? false) {
            totals['nightHours'] = (totals['nightHours'] ?? 0) + (num.tryParse(data['nightHours'].toString()) ?? 0);
          }
          if (breakdownSelections['commission'] ?? false) {
            totals['commission'] = (totals['commission'] ?? 0) + (num.tryParse(data['commission'].toString()) ?? 0);
          }
          if (breakdownSelections['sectorsFlown'] ?? false) {
            totals['sectorsFlown'] = (totals['sectorsFlown'] ?? 0) + (num.tryParse((data['sectorsFlown'] ?? '0').toString()) ?? 0);
          }
          if (breakdownSelections['offDays'] ?? false) {
            int leaveDaysCount = 0;
            final val = data['leaveDays'] ?? data['offDays'];
            if (val is int) {
              leaveDaysCount = val;
            } else if (val is String) {
              leaveDaysCount = int.tryParse(val) ?? 0;
            } else if (val is List) {
              leaveDaysCount = val.length;
            }
            totals['offDays'] = (totals['offDays'] ?? 0) + leaveDaysCount;
          }
          if (breakdownSelections['avacDays'] ?? false) {
            int avacDaysCount = 0;
            final val = data['avacDays'];
            if (val is int) {
              avacDaysCount = val;
            } else if (val is String) {
              avacDaysCount = int.tryParse(val) ?? 0;
            } else if (val is List) {
              avacDaysCount = val.length;
            }
            totals['avacDays'] = (totals['avacDays'] ?? 0) + avacDaysCount;
          }
          if (breakdownSelections['salary'] ?? false) {
            totals['salaryEUR'] = (totals['salaryEUR'] ?? 0) + (num.tryParse((data['salaryEUR'] ?? '0').toString()) ?? 0);
            totals['salaryTL'] = (totals['salaryTL'] ?? 0) + (num.tryParse((data['salaryTL'] ?? '0').toString()) ?? 0);
          }
          if (breakdownSelections['euroRate'] ?? false) {
            // For euro rate, we'll calculate average instead of sum
            final rate = num.tryParse((data['euroRate'] ?? '0').toString()) ?? 0;
            if (rate > 0) {
              totals['euroRateSum'] = (totals['euroRateSum'] ?? 0) + rate;
              totals['euroRateCount'] = (totals['euroRateCount'] ?? 0) + 1;
            }
          }
        }

        return Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          color: const Color(0xFF1F1D2B),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.table_chart, color: Colors.white, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Aylık Detay Tablosu',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withAlpha(77)),
                    ),
                    child: DataTable(
                      columnSpacing: 20,
                      headingRowColor: WidgetStateProperty.all(
                        Colors.orange.withAlpha(77),
                      ),
                      dataRowColor: WidgetStateProperty.all(
                        Colors.white.withAlpha(26),
                      ),
                      columns: columns,
                      rows: [
                        ...monthlyData.map((data) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  data['month'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (breakdownSelections['dutyTime'] ?? false)
                                DataCell(
                                  Text(
                                    data['dutyHours'].toString(),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              if (breakdownSelections['nightHours'] ?? false)
                                DataCell(
                                  Text(
                                    data['nightHours'].toString(),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              if (breakdownSelections['commission'] ?? false)
                                DataCell(
                                  Text(
                                    data['commission'].toString(),
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              if (breakdownSelections['sectorsFlown'] ?? false)
                                DataCell(
                                  Text(
                                    (data['sectorsFlown'] ?? '0').toString(),
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              if (breakdownSelections['offDays'] ?? false)
                                DataCell(
                                  Text(
                                    (data['leaveDays'] ?? data['offDays'] ?? '0').toString(),
                                    style: const TextStyle(
                                      color: Colors.deepPurpleAccent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (breakdownSelections['avacDays'] ?? false)
                                DataCell(
                                  Text(
                                    (data['avacDays'] ?? '0').toString(),
                                    style: const TextStyle(
                                      color: Colors.lightBlueAccent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (breakdownSelections['salary'] ?? false)
                                DataCell(
                                  Text(
                                    (data['salaryEUR'] ?? '0').toString(),
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (breakdownSelections['salary'] ?? false)
                                DataCell(
                                  Text(
                                    (data['salaryTL'] ?? '0').toString(),
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (breakdownSelections['euroRate'] ?? false)
                                DataCell(
                                  Text(
                                    (data['euroRate'] ?? '0').toString(),
                                    style: const TextStyle(
                                      color: Colors.yellow,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              if (breakdownSelections['paymentMonth'] ?? false)
                                DataCell(
                                  Text(
                                    (data['paymentMonth'] ?? '').toString(),
                                    style: const TextStyle(
                                      color: Colors.cyan,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        }),
                        // Total row
                        DataRow(
                          cells: [
                            DataCell(
                              const Text(
                                'Total',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (breakdownSelections['dutyTime'] ?? false)
                              DataCell(
                                Text(
                                  totals['dutyHours']?.toStringAsFixed(0) ?? '0',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (breakdownSelections['nightHours'] ?? false)
                              DataCell(
                                Text(
                                  totals['nightHours']?.toStringAsFixed(0) ?? '0',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (breakdownSelections['commission'] ?? false)
                              DataCell(
                                Text(
                                  totals['commission']?.toStringAsFixed(0) ?? '0',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (breakdownSelections['sectorsFlown'] ?? false)
                              DataCell(
                                Text(
                                  totals['sectorsFlown']?.toStringAsFixed(0) ?? '0',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (breakdownSelections['offDays'] ?? false)
                              DataCell(
                                Text(
                                  totals['offDays']?.toStringAsFixed(0) ?? '0',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (breakdownSelections['avacDays'] ?? false)
                              DataCell(
                                Text(
                                  totals['avacDays']?.toStringAsFixed(0) ?? '0',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (breakdownSelections['salary'] ?? false)
                              DataCell(
                                Text(
                                  totals['salaryEUR']?.toStringAsFixed(0) ?? '0',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (breakdownSelections['salary'] ?? false)
                              DataCell(
                                Text(
                                  totals['salaryTL']?.toStringAsFixed(0) ?? '0',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (breakdownSelections['euroRate'] ?? false)
                              DataCell(
                                Text(
                                  totals['euroRateCount'] != null && totals['euroRateCount']! > 0
                                      ? (totals['euroRateSum']! / totals['euroRateCount']!).toStringAsFixed(2)
                                      : '0.00',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (breakdownSelections['paymentMonth'] ?? false)
                              DataCell(
                                const Text(
                                  '-',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Export Button
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color.fromRGBO(21, 123, 163, 0.8),
                          Color.fromRGBO(146, 74, 26, 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(77),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _exportTableAsExcel(monthlyData),
                      icon: const Icon(Icons.table_view, color: Colors.white),
                      label: const Text(
                        'Tabloyu Excel Olarak Dışa Aktar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getMonthlyBreakdownData() async {
    try {
      debugPrint('Loading monthly breakdown data...');
      
      // Get both salary and roster data
      final salaries = await DataService().getPreviousSalaries();
      final rosterHistory = await DataService().getRosterHistory();
      
      debugPrint('Loaded ${salaries.length} salaries and ${rosterHistory.length} roster entries');

      // Filter and deduplicate data
      final filteredSalaries = _filterSalaries(salaries);
      final filteredRoster = _filterRoster(rosterHistory);
      final deduplicatedSalaries = _deduplicateSalaryHistory(filteredSalaries);
      final deduplicatedRoster = _deduplicateRosterHistory(filteredRoster);
      
      debugPrint('After filtering: ${deduplicatedSalaries.length} salaries, ${deduplicatedRoster.length} roster entries');

      // IMPORTANT: Only salary records create monthly rows. A month whose
      // salary has been deleted must disappear completely from the statistics
      // page, even if roster data for that period still exists.
      final Map<String, String> rosterPeriodToMonthMap = {};

      for (final salary in deduplicatedSalaries) {
        final rosterPeriod = salary['rosterPeriod'] as String? ?? '';
        if (rosterPeriod.isNotEmpty) {
          rosterPeriodToMonthMap[rosterPeriod] = getMonthFromRosterPeriod(rosterPeriod);
        }
      }

      // Create a map to combine salary and roster data by roster period
      Map<String, Map<String, dynamic>> monthlyData = {};

      // Process salary data (one row per roster period)
      for (final salary in deduplicatedSalaries) {
        final rosterPeriod = salary['rosterPeriod'] as String? ?? '';
        if (rosterPeriod.isEmpty) continue;

        final row = monthlyData.putIfAbsent(
          rosterPeriod,
          () => _createMonthlyRow(
            monthLabel: rosterPeriodToMonthMap[rosterPeriod] ?? 'Unknown',
            rosterPeriod: rosterPeriod,
            sortYear: _getYearNumberFromRosterPeriod(rosterPeriod),
            sortMonth: _getMonthNumberFromRosterPeriod(rosterPeriod),
          ),
        );
        _applySalaryToMonthlyRow(row, salary);
      }

      // Salaries saved without a roster period still belong on the page:
      // group them by the calendar month of their save date (latest wins).
      final noPeriodSalaries = deduplicatedSalaries
          .where((salary) => (salary['rosterPeriod'] as String? ?? '').isEmpty)
          .toList()
        ..sort((a, b) {
          final dateA = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(1970);
          final dateB = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(1970);
          return dateB.compareTo(dateA);
        });
      for (final salary in noPeriodSalaries) {
        final date = DateTime.tryParse(salary['date']?.toString() ?? '');
        if (date == null) continue;
        final key = 'date:${date.year}-${date.month.toString().padLeft(2, '0')}';
        if (monthlyData.containsKey(key)) continue;

        final noPeriodRow = _createMonthlyRow(
          monthLabel: '${months[date.month - 1]} ${date.year}',
          rosterPeriod: '',
          sortYear: date.year,
          sortMonth: date.month,
        );
        monthlyData[key] = noPeriodRow;
        _applySalaryToMonthlyRow(noPeriodRow, salary);
      }

      // Enrich the existing salary rows with roster information. Rows are
      // never created here: a roster period without a salary record must not
      // appear on the statistics page.
      for (final roster in deduplicatedRoster) {
        final rosterPeriod = roster.data['rosterPeriod'] as String? ?? '';
        if (rosterPeriod.isEmpty) continue;
        final row = monthlyData[rosterPeriod];
        if (row == null) continue; // No salary for this period -> skip

        final layoverCount = (roster.data['layoverCount'] as num?)?.toInt() ?? 0;
        final dutyTimeStr = roster.data['totalDutyTime']?.toString() ?? '0h';
        final dutyTime = double.tryParse(dutyTimeStr.replaceAll('h', '')) ?? 0.0;
        final sectorHours = double.tryParse(roster.data['sectorHours']?.toString() ?? '0') ?? 0.0;

        row['layovers'] = layoverCount;

        // Get leave days count from roster data (excluding AVAC days, which
        // are counted separately to avoid double counting)
        int leaveDaysCount = 0;
        final leaveDaysField = roster.data['offDays'];
        if (leaveDaysField is List) {
          leaveDaysCount = _countLeaveDaysFromOffDaysField(leaveDaysField);
        } else if (roster.data['leaveDays'] is int) {
          leaveDaysCount = roster.data['leaveDays'];
        } else if (roster.data['izinGunleri'] is int) {
          leaveDaysCount = roster.data['izinGunleri'];
        }
        row['leaveDays'] = leaveDaysCount;

        // Get AVAC days count from roster data
        int avacDaysCount = 0;
        final avacDaysField = roster.data['offDays'];
        if (avacDaysField is List) {
          avacDaysCount = _countAvacDaysFromOffDaysField(avacDaysField);
        } else {
          // Fallback: check for separate AVAC fields
          final avacDaysFields = ['avacDays', 'AVAC', 'avac', 'vacationDays', 'annualLeave'];
          for (final field in avacDaysFields) {
            if (roster.data.containsKey(field)) {
              final fieldValue = roster.data[field];
              if (fieldValue is List) {
                avacDaysCount = fieldValue.length;
              } else if (fieldValue is num) {
                avacDaysCount = fieldValue.toInt();
              } else if (fieldValue is String) {
                avacDaysCount = int.tryParse(fieldValue) ?? 0;
              }
              if (avacDaysCount > 0) break;
            }
          }
        }
        row['avacDays'] = avacDaysCount;

        // Only update dutyHours if it's not already set from salary data
        if (row['dutyHours'] == 0.0) {
          row['dutyHours'] = dutyTime;
        }
        row['sectorsFlown'] = sectorHours;
      }

      // Sort by year first, then by month (January to December)
      final sortedRows = monthlyData.values.toList()
        ..sort((a, b) {
          final yearA = a['sortYear'] as int;
          final yearB = b['sortYear'] as int;
          if (yearA != yearB) {
            return yearA.compareTo(yearB); // Ascending year order
          }
          return (a['sortMonth'] as int).compareTo(b['sortMonth'] as int);
        });

      return sortedRows.map((data) {
        final rosterPeriod = data['rosterPeriod'] as String;
        return {
          'month': rosterPeriod.isNotEmpty
              ? '${data['month']} ($rosterPeriod)' // Show both month and roster period
              : data['month'],
          'dutyHours': (data['dutyHours'] as double).toStringAsFixed(0),
          'nightHours': (data['nightHours'] as double).toStringAsFixed(0),
          'layovers': data['layovers'].toString(),
          'leaveDays': data['leaveDays'].toString(),
          'commission': (data['commission'] as double).toStringAsFixed(0),
          'salaryTL': (data['salaryTL'] as double).toStringAsFixed(0),
          'salaryEUR': (data['salaryEUR'] as double).toStringAsFixed(0),
          'sectorsFlown': (data['sectorsFlown'] as double).toStringAsFixed(0),
          'euroRate': (data['euroRate'] as double).toStringAsFixed(2),
          'avacDays': data['avacDays'].toString(),
          'paymentMonth': data['paymentMonth'].toString(),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting monthly breakdown data: $e');
      return [];
    }
  }

  void _selectYear(BuildContext context) {
    // Create a simple year selector
    final currentYear = DateTime.now().year;
    final years = List.generate(5, (index) => currentYear - index);

    showDialog(
      context: context,
      builder: (context) => _buildYearSelector(years),
    );
  }

  void _selectMonth(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _buildMonthSelector(),
    );
  }

  Widget _buildYearSelector(List<int> years) {
    return Dialog(
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
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 300,
              width: 250,
              child: ListView.builder(
                itemCount: years.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(
                      years[index].toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        selectedPeriod = 'year';
                        selectedYear = years[index];
                        selectedMonth = null;
                        _statisticsFuture = _loadStatistics();
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Dialog(
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
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 400,
              width: 250,
              child: ListView.builder(
                itemCount: months.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(
                      months[index],
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        selectedPeriod = 'month';
                        selectedMonth = months[index];
                        selectedYear = null;
                        _statisticsFuture = _loadStatistics();
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildBreakdownCards() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Compact toggle button
          GestureDetector(
            onTap: () => _showColumnSelector(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color.fromRGBO(21, 123, 163, 0.8),
                    Color.fromRGBO(146, 74, 26, 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(77),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tune, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Tablo Seçenekleri',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${breakdownSelections.values.where((v) => v).length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showColumnSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 350),
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
                    const Icon(Icons.view_column, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Tablo Sütunları',
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
              // Content - wrapped in scrollable container
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildColumnOption('dutyTime', 'Görev Saati', Icons.timer),
                      _buildColumnOption('nightHours', 'Gece Saati', Icons.nightlight_round),
                      _buildColumnOption('commission', 'Komisyon (€)', Icons.euro),
                      _buildColumnOption('sectorsFlown', 'Sektör Saati', Icons.flight),
                      _buildColumnOption('offDays', 'İzin Günleri', Icons.beach_access),
                      _buildColumnOption('avacDays', 'AVAC Günleri', Icons.hotel),
                      _buildColumnOption('salary', 'Maaş', Icons.attach_money),
                      _buildColumnOption('euroRate', 'Euro Kuru (₺)', Icons.currency_exchange),
                      _buildColumnOption('paymentMonth', 'Ödeme Ayı', Icons.calendar_month),
                    ],
                  ),
                ),
              ),
              // Footer
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
                      'Tamam',
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

  Widget _buildColumnOption(String key, String label, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: StatefulBuilder(
        builder: (context, setLocalState) {
          final isSelected = breakdownSelections[key] ?? false;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                setLocalState(() {
                  breakdownSelections[key] = !isSelected;
                });
                setState(() {
                  // Also update the main widget state
                  breakdownSelections[key] = !isSelected;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.orange.withAlpha(77) : Colors.white.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.orange : Colors.white.withAlpha(77),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        icon,
                        key: ValueKey('icon_$isSelected'),
                        color: isSelected ? Colors.orange : Colors.white70,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        child: Text(label),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                        key: ValueKey('checkbox_$isSelected'),
                        color: isSelected ? Colors.orange : Colors.white70,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
                        'İstatistikler Sayfası Nasıl Kullanılır?',
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
                        '📊 Genel Bakış',
                        'İstatistikler sayfası maaş ve roster verilerinizi analiz eder. Sayfa açıldığında sadece temel bilgiler (Ay, Maaş, Euro Kuru) görüntülenir.',
                      ),
                      const SizedBox(height: 16),
                      _buildHelpSection(
                        '🔍 Filtreleme',
                        '• Yıla Göre: Belirli bir yılın verilerini görüntüler\n• Aya Göre: Belirli bir ayın verilerini görüntüler\n• Tüm [Yıl]: O yılın tüm verilerini görüntüler',
                      ),
                      const SizedBox(height: 16),
                      _buildHelpSection(
                        '📋 Sütun Seçimi',
                        'Sayfanın üst kısmındaki kartlara tıklayarak ek sütunları açıp kapatabilirsiniz:\n• Duty Time: Görev saatleri\n• Night Hours: Gece saatleri\n• Commission: Komisyon\n• Sectors Flown: Uçulan sektörler',
                      ),
                      const SizedBox(height: 16),
                      _buildHelpSection(
                        '📈 Veriler',
                        '• Her roster dönemi için en son hesaplanan veriler kullanılır\n• Maaş ve roster verileri otomatik olarak eşleştirilir\n• Euro kuru salary verilerinden otomatik çıkarılır',
                      ),
                      const SizedBox(height: 16),
                      _buildHelpSection(
                        '🔄 Veri Yenileme',
                        'Sayfa her açıldığında veriler otomatik olarak güncellenir. Yeni PDF analizi yaptıktan sonra sayfayı yeniden ziyaret edin.',
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

  Future<void> _exportTableAsExcel(List<Map<String, dynamic>> monthlyData) async {
    try {
      // Generate CSV content (which can be opened by Excel)
      final csvContent = _generateCSVContent(monthlyData);
      
      // Get the device's temporary directory
      final directory = await getTemporaryDirectory();
      
      // Create file name with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final fileName = 'istatistikler_$timestamp.csv';
      final filePath = '${directory.path}/$fileName';
      
      // Write CSV content to file
      final file = File(filePath);
      await file.writeAsString(csvContent, encoding: utf8);
      
      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'İstatistik tablosu Excel formatında dışa aktarıldı',
        subject: 'Keisan İstatistikleri - $fileName',
      );
      
      // Show success dialog
      if (mounted) {
        _showExportSuccessDialog(fileName);
      }
    } catch (e) {
      debugPrint('Excel export error: $e');
      if (mounted) {
        _showExportErrorDialog(e.toString());
      }
    }
  }

  String _generateCSVContent(List<Map<String, dynamic>> monthlyData) {
    final buffer = StringBuffer();
    
    // Add BOM for proper UTF-8 encoding in Excel
    buffer.write('\uFEFF');
    
    // Column headers
    final headers = <String>['Ay'];
    if (breakdownSelections['dutyTime'] ?? false) {
      headers.add('Görev Saati');
    }
    if (breakdownSelections['nightHours'] ?? false) {
      headers.add('Gece Saati');
    }
    if (breakdownSelections['commission'] ?? false) {
      headers.add('Komisyon (€)');
    }
    if (breakdownSelections['sectorsFlown'] ?? false) {
      headers.add('Sektör Saati');
    }
    if (breakdownSelections['offDays'] ?? false) {
      headers.add('İzin Günleri');
    }
    if (breakdownSelections['avacDays'] ?? false) {
      headers.add('AVAC Günleri');
    }
    if (breakdownSelections['salary'] ?? false) {
      headers.add('Maaş (€)');
      headers.add('Maaş (₺)');
    }
    if (breakdownSelections['euroRate'] ?? false) {
      headers.add('Euro Kuru (₺)');
    }
    if (breakdownSelections['paymentMonth'] ?? false) {
      headers.add('Ödeme Ayı');
    }
    
    // Write headers
    buffer.writeln(headers.map((h) => '"$h"').join(','));
    
    // Write data rows
    for (final data in monthlyData) {
      final row = <String>['"${data['month']}"'];
      
      if (breakdownSelections['dutyTime'] ?? false) {
        row.add(data['dutyHours'].toString());
      }
      if (breakdownSelections['nightHours'] ?? false) {
        row.add(data['nightHours'].toString());
      }
      if (breakdownSelections['commission'] ?? false) {
        row.add(data['commission'].toString());
      }
      if (breakdownSelections['sectorsFlown'] ?? false) {
        row.add((data['sectorsFlown'] ?? '0').toString());
      }
      if (breakdownSelections['offDays'] ?? false) {
        row.add((data['offDays'] ?? '0').toString());
      }
      if (breakdownSelections['avacDays'] ?? false) {
        row.add((data['avacDays'] ?? '0').toString());
      }
      if (breakdownSelections['salary'] ?? false) {
        row.add((data['salaryEUR'] ?? '0').toString());
        row.add((data['salaryTL'] ?? '0').toString());
      }
      if (breakdownSelections['euroRate'] ?? false) {
        row.add((data['euroRate'] ?? '0').toString());
      }
      if (breakdownSelections['paymentMonth'] ?? false) {
        row.add('"${data['paymentMonth'] ?? ''}"');
      }
      
      buffer.writeln(row.join(','));
    }
    
    return buffer.toString();
  }

  void _showExportSuccessDialog(String fileName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 350),
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
                  color: Colors.green[700],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Dışa Aktarma Başarılı',
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
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Tablo başarıyla Excel formatında dışa aktarıldı:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(26),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        fileName,
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green[700],
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
                      foregroundColor: Colors.green[700],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Tamam',
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

  void _showExportErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 350),
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
                  color: Colors.red[700],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.error, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Dışa Aktarma Hatası',
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
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Excel dışa aktarımı sırasında hata oluştu:\n\n$error',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red[700],
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
                      foregroundColor: Colors.red[700],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Tamam',
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

}
