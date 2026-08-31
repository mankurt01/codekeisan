import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:logging/logging.dart';
import '../models/pdf_result.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class DataService {
  static final _log = Logger('DataService');
  static const String _fileName = 'app_data.json';
  static const String _salariesFileName = 'previous_salaries.json';
                                                                                                                              
  // Singleton instance
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _salariesFile async {
    final path = await _localPath;
    return File('$path/$_salariesFileName');
  }
 
  Future<void> saveRosterToHistory(PdfResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> history = await _readRosterHistory();
      
      // Get the roster period of the new result
      final newRosterPeriod = result.data['rosterPeriod'] as String?;
      
      // Remove any existing entries for the same roster period
      // so we keep only one copy per period (new one overwrites the old)
      if (newRosterPeriod != null && newRosterPeriod.isNotEmpty) {
        history.removeWhere((item) {
          final itemData = item['data'];
          if (itemData is! Map) return false;
          return itemData['rosterPeriod'] == newRosterPeriod;
        });
      }
      
      // Convert PdfResult to Map
      final resultData = {
        'fileName': result.fileName,
        'date': result.date.toIso8601String(),
        'data': result.data,
        'rawText': result.rawText,
      };
      
      history.add(resultData);
      await prefs.setString('rosterHistory', json.encode(history));
    } catch (e) {
      _log.severe('Error saving roster history: $e');
      rethrow;
    }
  }

  Future<List<PdfResult>> getRosterHistory() async {
    try {
      final history = await _readRosterHistory();
      return history.map((json) => PdfResult.fromJson(json)).toList();
    } catch (e) {
      _log.severe('Error reading roster history: $e');
      return [];
    }
  }

  Future<void> saveSalaryCalculation({
    required double euroTotal,
    required double tlTotal,
    required Map<String, double> components,
    required bool isSCCM,
    required double dutyHours,
    required double nightHours,
    required Map<String, int> legCounts,
    required int layoverCount,
    required int offDutyCounts,
    String? rosterPeriod,
  }) async {
    try {
      final file = await _salariesFile;
      List<Map<String, dynamic>> salaries = [];
      
      if (await file.exists()) {
        final content = await file.readAsString();
        salaries = List<Map<String, dynamic>>.from(json.decode(content));
      }

      final baseSalaryData = await getBaseSalaryData() ?? {};
      String id = DateTime.now().millisecondsSinceEpoch.toString();
      
      salaries.add({
        'id': id,
        'date': DateTime.now().toIso8601String().split('T')[0],
        'euro': euroTotal,
        'tl': tlTotal,
        'rosterPeriod': rosterPeriod,
        'components': components,
        'isSCCM': isSCCM,
        'dutyHours': dutyHours,
        'nightHours': nightHours,
        'legCounts': legCounts,
        'layoverCount': layoverCount,
        'offDutyCounts': offDutyCounts,
        'baseSalaryData': baseSalaryData,
      });

      await file.writeAsString(json.encode(salaries));
    } catch (e) {
      _log.severe('Error saving salary calculation: $e');
      rethrow;
    }
  }

  // Get previous salaries
  Future<List<Map<String, dynamic>>> getPreviousSalaries() async {
    try {
      final file = await _salariesFile;
      if (!await file.exists()) {
        return [];
      }
      final content = await file.readAsString();
      return List<Map<String, dynamic>>.from(json.decode(content));
    } catch (e) {
      _log.severe('Error reading previous salaries: $e');
      return [];
    }
  }

  /// Deletes a salary record from the history.
  ///
  /// Records saved by [saveSalaryCalculation] always have an `id`, but legacy
  /// records may not. When no `id` is available, the record is matched by its
  /// identity fields (date, euro, tl, roster period) so that the deletion is
  /// always persisted and the record can never reappear on the statistics
  /// page. Returns the number of records that were removed.
  Future<int> deleteSalaryRecord(Map<String, dynamic> record) async {
    try {
      final file = await _salariesFile;
      if (!await file.exists()) return 0;

      final content = await file.readAsString();
      final List<Map<String, dynamic>> salaries = List<Map<String, dynamic>>.from(json.decode(content));

      final recordId = record['id']?.toString();
      final recordDate = record['date']?.toString();
      final recordEuro = (record['euro'] as num?)?.toDouble();
      final recordTl = (record['tl'] as num?)?.toDouble();
      final recordRosterPeriod = record['rosterPeriod']?.toString();

      bool isSameRecord(Map<String, dynamic> salary) {
        if (recordId != null && recordId.isNotEmpty) {
          return salary['id']?.toString() == recordId;
        }
        return salary['date']?.toString() == recordDate &&
            (salary['euro'] as num?)?.toDouble() == recordEuro &&
            (salary['tl'] as num?)?.toDouble() == recordTl &&
            salary['rosterPeriod']?.toString() == recordRosterPeriod;
      }

      final lengthBefore = salaries.length;
      salaries.removeWhere(isSameRecord);
      final removed = lengthBefore - salaries.length;

      if (removed > 0) {
        await file.writeAsString(json.encode(salaries));
      }
      return removed;
    } catch (e) {
      _log.severe('Error deleting salary: $e');
      rethrow;
    }
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/$_fileName');
  }

  Future<Map<String, dynamic>> _readData() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        return {};
      }
      final contents = await file.readAsString();
      return json.decode(contents) as Map<String, dynamic>;
    } catch (e) {
      _log.severe('Error reading data: $e');
      return {};
    }
  }

  Future<void> _writeData(Map<String, dynamic> data) async {
    try {
      final file = await _localFile;
      await file.writeAsString(json.encode(data));
    } catch (e) {
      _log.severe('Error writing data: $e');
    }
  }

  // Save current period commission
  Future<void> saveCommission(double commission) async {
    final data = await _readData();
    data['current_commission'] = {
      'value': commission,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _writeData(data);
  }

  // Save base salary and related data
  Future<void> saveBaseSalaryData({
    required double baseSalary,
    required int sixthDay,
    required int internationalOvernight,
    required double euroRate,
    int? offDutyCounts,
    String? employmentType,
    String? partTimeType,
    String? yearsOfService,
    String? rosterPeriod,
  }) async {
    final data = await _readData();
    final currentData = data['base_salary_data'] as Map<String, dynamic>? ?? {};

    // Preserve the previously saved off-duty count when this method is called
    // without one (e.g. by the base salary service screen or import flow).
    final resolvedOffDuty = offDutyCounts ??
        currentData['offDutyCounts'] as int? ??
        data['off_duty_counts'] as int? ??
        0;

    data['base_salary_data'] = {
      'baseSalary': baseSalary,
      'sixthDay': sixthDay,
      'internationalOvernight': internationalOvernight,
      'euroRate': euroRate,
      'offDutyCounts': resolvedOffDuty,
      'employmentType': employmentType,
      'partTimeType': partTimeType,
      'yearsOfService': yearsOfService,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Save fixes per roster period
    if (rosterPeriod != null && rosterPeriod.isNotEmpty) {
      final fixesMap = data['fixes_per_roster'] as Map<String, dynamic>? ?? {};
      fixesMap[rosterPeriod] = {
        'alti_gun': sixthDay,
        'off_duty': resolvedOffDuty,
      };
      data['fixes_per_roster'] = fixesMap;
    }

    await _writeData(data);
  }

  // Load fixes for a specific roster period
  Future<Map<String, dynamic>> getFixesForRosterPeriod(String rosterPeriod) async {
    final data = await _readData();
    final fixesMap = data['fixes_per_roster'] as Map<String, dynamic>? ?? {};
    return fixesMap[rosterPeriod] as Map<String, dynamic>? ?? {};
  }

  // Add new method to save only persistent values
  Future<void> savePersistentData({
    required double baseSalary,
    required double euroRate,
    required int offDutyCounts,
  }) async {
    final data = await _readData();
    final existingData = data['base_salary_data'] as Map<String, dynamic>? ?? {};
    
    data['base_salary_data'] = {
      ...existingData,
      'baseSalary': baseSalary,
      'euroRate': euroRate,
      'timestamp': DateTime.now().toIso8601String(),
    };
    data['off_duty_counts'] = offDutyCounts;
    await _writeData(data);
  }

  // Add method to get only persistent values
  Future<Map<String, dynamic>> getPersistentData() async {
    final data = await _readData();
    final salaryData = data['base_salary_data'] as Map<String, dynamic>? ?? {};
    
    return {
      'baseSalary': salaryData['baseSalary'] ?? 0.0,
      'euroRate': salaryData['euroRate'] ?? 0.0,
    };
  }

  // Add new method to calculate and save layover data
  Future<void> saveLayoverData({
    required int totalLayovers,
    int? internationalLayovers,
    // Remove domesticLayovers parameter
  }) async {
    final data = await _readData();
    final currentData = data['base_salary_data'] as Map<String, dynamic>? ?? {};

    // No need to calculate domestic layovers anymore
    
    data['base_salary_data'] = {
      ...currentData,
      'totalLayovers': totalLayovers,
      'internationalOvernight': internationalLayovers ?? 0,
      // Remove 'domesticOvernight': domesticLayovers ?? 0,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    await _writeData(data);
  }

  // Add method to get layover data
  Future<Map<String, dynamic>> getLayoverData() async {
    final data = await _readData();
    final salaryData = data['base_salary_data'] as Map<String, dynamic>? ?? {};
    
    return {
      'totalLayovers': salaryData['totalLayovers'] ?? 0,
      'internationalOvernight': salaryData['internationalOvernight'] ?? 0,
    };
  }

  // Get off duty counts (stored in base_salary_data like the 6. Gün field,
  // with a fallback to the legacy off_duty_counts location)
  Future<int> getOffDutyCounts() async {
    final data = await _readData();
    final salaryData = data['base_salary_data'] as Map<String, dynamic>? ?? {};
    return salaryData['offDutyCounts'] as int? ??
        data['off_duty_counts'] as int? ??
        0;
  }

  // Get current commission based on roster period
  (DateTime, DateTime) _getDateRangeForRosterPeriod(String rosterPeriod) {
    final RegExp regExp = RegExp(r'(\d{2})([A-Za-z]{3})(\d{2})', caseSensitive: false);
    final match = regExp.firstMatch(rosterPeriod);
    if (match == null) {
      final now = DateTime.now();
      return (now, now); // Return current date if no match
    }

    final monthAbbr = match.group(2)!.toUpperCase();
    const monthMap = {
      'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
      'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12
    };
    final month = monthMap[monthAbbr] ?? 1;
    final year = 2000 + int.parse(match.group(3)!);
    
    // For selected month (e.g., April), show March 16 - April 15
    return (
      DateTime(year, month - 1, 16), // 16th of previous month
      DateTime(year, month, 15)      // 15th of current month
    );
  }

  Future<double> getCurrentCommission(String? rosterPeriod) async {
    try {
      final file = File('${await _localPath}/komisyonlar.json');
      if (!await file.exists()) return 0.0;
      
      if (rosterPeriod == null || rosterPeriod.isEmpty) return 0.0;

      final content = await file.readAsString();
      final komisyonlar = json.decode(content) as Map<String, dynamic>;
      
      final (startDate, endDate) = _getDateRangeForRosterPeriod(rosterPeriod);
      
      double total = 0;
      komisyonlar.forEach((dateStr, entry) {
        final entryDate = DateTime.parse(dateStr);
        if (entryDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
            entryDate.isBefore(endDate.add(const Duration(days: 1)))) {
          if (entry is Map && entry['commission'] != null) {
            // Exclude İç Hat commissions from main commission total
            final isIcHat = entry['isIcHat'] as bool? ?? false;
            if (!isIcHat) {
              total += (entry['commission'] as num).toDouble();
            }
          }
        }
      });
      
      return total;
    } catch (e) {
      _log.severe('Error getting commission for roster period: $e');
      return 0.0;
    }
  }

  // Get domestic (İç Hat) commission total for a given roster period
  Future<double> getDomesticCommission(String? rosterPeriod) async {
    try {
      final file = File('${await _localPath}/komisyonlar.json');
      if (!await file.exists()) return 0.0;
      
      if (rosterPeriod == null || rosterPeriod.isEmpty) return 0.0;

      final content = await file.readAsString();
      final komisyonlar = json.decode(content) as Map<String, dynamic>;
      
      final (startDate, endDate) = _getDateRangeForRosterPeriod(rosterPeriod);
      
      double total = 0;
      komisyonlar.forEach((dateStr, entry) {
        final entryDate = DateTime.parse(dateStr);
        if (entryDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
            entryDate.isBefore(endDate.add(const Duration(days: 1)))) {
          if (entry is Map && entry['commission'] != null) {
            // Only include İç Hat commissions
            final isIcHat = entry['isIcHat'] as bool? ?? false;
            if (isIcHat) {
              total += (entry['commission'] as num).toDouble();
            }
          }
        }
      });
      
      return total;
    } catch (e) {
      _log.severe('Error getting domestic commission for roster period: $e');
      return 0.0;
    }
  }

  // Get base salary data
  // Save role selection
  Future<void> saveRoleSelection(String role) async {
    final data = await _readData();
    data['role_selection'] = role;
    await _writeData(data);
  }

  // Get role selection
  Future<String?> getRoleSelection() async {
    final data = await _readData();
    return data['role_selection'] as String?;
  }

  // Save base selection
  Future<void> saveBaseSelection(String base) async {
    final data = await _readData();
    data['base_selection'] = base;
    await _writeData(data);
  }

  // Get base selection
  Future<String?> getBaseSelection() async {
    final data = await _readData();
    return data['base_selection'] as String?;
  }

  Future<Map<String, dynamic>?> getBaseSalaryData() async {
    final data = await _readData();
    return data['base_salary_data'] as Map<String, dynamic>?;
  }

  // Get all saved data
  Future<Map<String, dynamic>> getAllData() async {
    return await _readData();
  }

  // Save PDF analysis results
  Future<void> savePdfResult(PdfResult result) async {
    try {
      final file = await _localFile;
      final Map<String, dynamic> data = await _readData();
      
      // Add the PDF result to the data
      data['current_pdf_result'] = result.toJson();
      
      // Write the updated data back to the file
      await file.writeAsString(json.encode(data));
    } catch (e) {
      _log.severe('Error saving PDF result: $e');
      rethrow;
    }
  }

  // Get last PDF analysis results
  Future<PdfResult?> getPdfResult() async {
    try {
      final data = await _readData();
      final resultData = data['current_pdf_result'] as Map<String, dynamic>?;
      if (resultData == null) return null;
      return PdfResult.fromJson(resultData);
    } catch (e) {
      _log.severe('Error getting PDF result: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _readRosterHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('rosterHistory') ?? '[]';
      final List<dynamic> decoded = jsonDecode(historyJson);
      
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error reading roster history: $e');
      return [];
    }
  }

  Future<void> deleteFromRosterHistory(PdfResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> history = await _readRosterHistory();
      
      history.removeWhere((item) {
        final itemDate = DateTime.parse(item['date'] as String);
        return itemDate.isAtSameMomentAs(result.date);
      });
      
      await prefs.setString('rosterHistory', json.encode(history));
    } catch (e) {
      _log.severe('Error deleting from roster history: $e');
      rethrow;
    }
  }
}
