import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'data_service.dart';

class DataImportService {
  static final _log = Logger('DataImportService');
  static final DataService _dataService = DataService();

  // Import data from backup file
  static Future<void> importDataFromBackup(BuildContext context) async {
    bool loadingShown = false;
    try {
      // Pick backup file
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (picked == null || picked.path == null) {
        // Ensure dialog is not left open
        return;
      }

      final file = File(picked.path!);

      // Show loading dialog
      if (!context.mounted) return;
      loadingShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Flexible(
                child: Text(
                  'Veri yedekleme dosyası okunuyor...',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      );

      // Read and parse JSON
      final content = await file.readAsString();
      final backupData = json.decode(content) as Map<String, dynamic>;

      // Validate backup file
      if (!_isValidBackupFile(backupData)) {
        if (loadingShown && context.mounted) {
          Navigator.of(context).pop();
        }
        if (context.mounted) {
          _showErrorDialog(context, 'Geçersiz yedekleme dosyası!');
        }
        return;
      }

      // Close loading dialog
      if (loadingShown && context.mounted) {
        Navigator.of(context).pop();
      }

      // Show preview and confirmation dialog
      if (!context.mounted) return;
      final shouldImport = await _showImportPreviewDialog(context, backupData);

      if (shouldImport) {
        if (context.mounted) {
          await _performImport(context, backupData);
        }
      }

    } catch (e) {
      if (loadingShown && context.mounted) {
        Navigator.of(context).pop(); // Close any open dialogs
      }
      _log.severe('Error importing data: $e');
      if (context.mounted) {
        _showErrorDialog(context, 'Veri içe aktarma sırasında hata oluştu: $e');
      }
    }
  }

  // Validate backup file structure
  static bool _isValidBackupFile(Map<String, dynamic> data) {
    return data.containsKey('export_info') &&
           data['export_info'] is Map<String, dynamic> &&
           data['export_info']['data_format_version'] != null;
  }

  // Show import preview dialog
  static Future<bool> _showImportPreviewDialog(
    BuildContext context,
    Map<String, dynamic> backupData,
  ) async {
    final exportInfo = backupData['export_info'] as Map<String, dynamic>;
    final exportDate = DateTime.parse(exportInfo['export_date'] as String);
    final appVersion = exportInfo['app_version'] as String;
    
    final rosterCount = (backupData['roster_history'] as List?)?.length ?? 0;
    final salaryCount = (backupData['salary_history'] as List?)?.length ?? 0;
    final commissionCount = (backupData['commission_history'] as List?)?.length ?? 0;
    
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromRGBO(42, 45, 62, 0.95),
        title: const Text(
          'Veri İçe Aktarma',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Color(0xFFED6C02),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yedekleme Dosyası Bilgileri:',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tarih: ${exportDate.day}/${exportDate.month}/${exportDate.year}',
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Color(0xFFFFA726),
              ),
            ),
            Text(
              'Uygulama Versiyonu: $appVersion',
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Color(0xFFFFA726),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Veriler:',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '• Roster Geçmişi: $rosterCount kayıt',
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Color(0xFFFFA726),
              ),
            ),
            Text(
              '• Maaş Geçmişi: $salaryCount kayıt',
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Color(0xFFFFA726),
              ),
            ),
            Text(
              '• Komisyon Geçmişi: $commissionCount kayıt',
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Color(0xFFFFA726),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFED6C02).withAlpha(51), // 0.2 * 255 ≈ 51
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Uyarı: Bu işlem mevcut verilerinizi değiştirecektir. Devam etmek istediğinizden emin misiniz?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'İptal',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'İçe Aktar',
              style: TextStyle(color: Color(0xFFFFA726)),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  // Perform the actual import
  static Future<void> _performImport(
    BuildContext context,
    Map<String, dynamic> backupData,
  ) async {
    try {
      // Show progress dialog
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Flexible(
                child: Text(
                  'Veriler içe aktarılıyor...',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      );

      // Import roster history
      if (backupData['roster_history'] != null) {
        await _importRosterHistory(backupData['roster_history'] as List);
      }

      // Import salary history
      if (backupData['salary_history'] != null) {
        await _importSalaryHistory(backupData['salary_history'] as List);
      }

      // Import commission history
      if (backupData['commission_history'] != null) {
        await _importCommissionHistory(backupData['commission_history'] as List);
      }

      // Import base salary data
      if (backupData['base_salary_data'] != null) {
        await _importBaseSalaryData(backupData['base_salary_data'] as Map<String, dynamic>);
      }

      // Import other app data
      if (backupData['all_app_data'] != null) {
        await _importAppData(backupData['all_app_data'] as Map<String, dynamic>);
      }

      // Close progress dialog
      if (!context.mounted) return;
      Navigator.of(context).pop();

      // Show success dialog
      if (!context.mounted) return;
      _showSuccessDialog(
        context,
        'Veriler başarıyla içe aktarıldı!\n\n'
        'Roster: ${(backupData['roster_history'] as List?)?.length ?? 0} kayıt\n'
        'Maaş: ${(backupData['salary_history'] as List?)?.length ?? 0} kayıt\n'
        'Komisyon: ${(backupData['commission_history'] as List?)?.length ?? 0} kayıt',
      );

    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close progress dialog
        _log.severe('Error performing import: $e');
        _showErrorDialog(context, 'İçe aktarma sırasında hata oluştu: $e');
      }
    }
  }

  // Import roster history
  static Future<void> _importRosterHistory(List rosterData) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> existingHistory = await _dataService.getRosterHistory()
        .then((history) => history.map((item) => item.toJson()).toList());

    for (final item in rosterData) {
      if (item is Map<String, dynamic>) {
        // Check if this item already exists (avoid duplicates)
        final itemDate = DateTime.parse(item['date'] as String);
        final exists = existingHistory.any((existing) {
          final existingDate = DateTime.parse(existing['date'] as String);
          return existingDate.isAtSameMomentAs(itemDate) && 
                 existing['fileName'] == item['fileName'];
        });

        if (!exists) {
          existingHistory.add(item);
        }
      }
    }

    await prefs.setString('rosterHistory', json.encode(existingHistory));
  }

  // Import salary history
  static Future<void> _importSalaryHistory(List salaryData) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/previous_salaries.json');
    
    List<Map<String, dynamic>> existingSalaries = [];
    if (await file.exists()) {
      final content = await file.readAsString();
      existingSalaries = List<Map<String, dynamic>>.from(json.decode(content));
    }

    for (final item in salaryData) {
      if (item is Map<String, dynamic>) {
        // Create new ID for imported items to avoid conflicts
        final newItem = Map<String, dynamic>.from(item);
        newItem['id'] = DateTime.now().millisecondsSinceEpoch.toString() + 
                        existingSalaries.length.toString();
        existingSalaries.add(newItem);
      }
    }

    await file.writeAsString(json.encode(existingSalaries));
  }

  // Import commission history
  static Future<void> _importCommissionHistory(List commissionData) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/komisyonlar.json');
    
    Map<String, dynamic> existingCommissions = {};
    if (await file.exists()) {
      final content = await file.readAsString();
      existingCommissions = json.decode(content) as Map<String, dynamic>;
    }

    for (final item in commissionData) {
      if (item is Map<String, dynamic>) {
        final date = item['date'] as String;
        final isIcHat = item['is_domestic'] ?? item['isIcHat'] ?? false;
        existingCommissions[date] = {
          'commission': item['commission'] ?? item['amount'] ?? 0.0,
          'amount': item['amount'] ?? item['commission'] ?? 0.0,
          'is_five_person': item['is_five_person'] ?? false,
          'isIcHat': isIcHat,
        };
      }
    }

    await file.writeAsString(json.encode(existingCommissions));
  }

  // Import base salary data
  static Future<void> _importBaseSalaryData(Map<String, dynamic> baseSalaryData) async {
    if (baseSalaryData.isNotEmpty) {
      await _dataService.saveBaseSalaryData(
        baseSalary: (baseSalaryData['baseSalary'] as num?)?.toDouble() ?? 0.0,
        sixthDay: (baseSalaryData['sixthDay'] as num?)?.toInt() ?? 0,
        internationalOvernight: (baseSalaryData['internationalOvernight'] as num?)?.toInt() ?? 0,
        euroRate: (baseSalaryData['euroRate'] as num?)?.toDouble() ?? 0.0,
        employmentType: baseSalaryData['employmentType'] as String?,
        partTimeType: baseSalaryData['partTimeType'] as String?,
        yearsOfService: baseSalaryData['yearsOfService'] as String?,
      );
    }
  }

  // Import other app data
  static Future<void> _importAppData(Map<String, dynamic> appData) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/app_data.json');
    
    // Read existing data
    Map<String, dynamic> existingData = {};
    if (await file.exists()) {
      final content = await file.readAsString();
      existingData = json.decode(content) as Map<String, dynamic>;
    }

    // Merge imported data with existing data
    existingData.addAll(appData);
    
    // Write merged data
    await file.writeAsString(json.encode(existingData));
  }

  // Show success dialog
  static void _showSuccessDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromRGBO(42, 45, 62, 0.95),
        title: const Text(
          'Başarılı',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Color(0xFF4CAF50),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Tamam',
              style: TextStyle(color: Color(0xFFFFA726)),
            ),
          ),
        ],
      ),
    );
  }

  // Show error dialog
  static void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromRGBO(42, 45, 62, 0.95),
        title: const Text(
          'Hata',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Color(0xFFED6C02),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Tamam',
              style: TextStyle(color: Color(0xFFFFA726)),
            ),
          ),
        ],
      ),
    );
  }
}
