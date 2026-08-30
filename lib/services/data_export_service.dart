import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:logging/logging.dart';
import 'package:intl/intl.dart';
import 'data_service.dart';

class DataExportService {
  static final _log = Logger('DataExportService');
  static final DataService _dataService = DataService();

  // Export all user data to JSON
  static Future<void> exportAllData(BuildContext context) async {
    final navigatorContext = context;
    bool isLoading = true;
    
    try {
      // Show loading dialog
      showDialog(
        context: navigatorContext,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Veriler dışa aktarılıyor...'),
            ],
          ),
        ),
      );

      // Collect all data
      final exportData = await _collectAllData();
      
      // Create JSON file
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      final file = await _createExportFile('keisan_backup', 'json', jsonString);
      
      // Close loading dialog if mounted
      if (navigatorContext.mounted) {
        Navigator.of(navigatorContext).pop();
        isLoading = false;
        
        // Share file
        await _shareFile(file, 'Keisan Veri Yedekleme');
        
        // Show success message if still mounted
        if (navigatorContext.mounted) {
          _showSuccessDialog(navigatorContext, 'Tüm verileriniz başarıyla dışa aktarıldı!');
        }
      }
      
    } catch (e) {
      if (isLoading && navigatorContext.mounted) {
        Navigator.of(navigatorContext).pop(); // Close loading dialog
      }
      _log.severe('Error exporting data: $e');
      if (navigatorContext.mounted) {
        _showErrorDialog(navigatorContext, 'Veri dışa aktarma sırasında hata oluştu: $e');
      }
    }
  }

  // Export salary history to CSV
  static Future<void> exportSalaryHistory(BuildContext context) async {
    final navigatorContext = context;
    bool isLoading = true;
    
    try {
      showDialog(
        context: navigatorContext,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Maaş geçmişi dışa aktarılıyor...'),
            ],
          ),
        ),
      );

      final salaries = await _dataService.getPreviousSalaries();
      final csvContent = _salariesToCsv(salaries);
      final file = await _createExportFile('maas_gecmisi', 'csv', csvContent);
      
      if (navigatorContext.mounted) {
        Navigator.of(navigatorContext).pop();
        isLoading = false;
        
        await _shareFile(file, 'Maaş Geçmişi');
        
        if (navigatorContext.mounted) {
          _showSuccessDialog(navigatorContext, 'Maaş geçmişiniz CSV formatında dışa aktarıldı!');
        }
      }
      
    } catch (e) {
      if (isLoading && navigatorContext.mounted) {
        Navigator.of(navigatorContext).pop();
      }
      _log.severe('Error exporting salary history: $e');
      if (navigatorContext.mounted) {
        _showErrorDialog(navigatorContext, 'Maaş geçmişi dışa aktarma hatası: $e');
      }
    }
  }

  // Export commission history to CSV
  static Future<void> exportCommissionHistory(BuildContext context) async {
    final navigatorContext = context;
    bool isLoading = true;
    
    try {
      showDialog(
        context: navigatorContext,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Komisyon geçmişi dışa aktarılıyor...'),
            ],
          ),
        ),
      );

      final commissions = await _getCommissionHistory();
      final csvContent = _commissionsToCsv(commissions);
      final file = await _createExportFile('komisyon_gecmisi', 'csv', csvContent);
      
      if (navigatorContext.mounted) {
        Navigator.of(navigatorContext).pop();
        isLoading = false;
        
        await _shareFile(file, 'Komisyon Geçmişi');
        
        if (navigatorContext.mounted) {
          _showSuccessDialog(navigatorContext, 'Komisyon geçmişiniz CSV formatında dışa aktarıldı!');
        }
      }
      
    } catch (e) {
      if (isLoading && navigatorContext.mounted) {
        Navigator.of(navigatorContext).pop();
      }
      _log.severe('Error exporting commission history: $e');
      if (navigatorContext.mounted) {
        _showErrorDialog(navigatorContext, 'Komisyon geçmişi dışa aktarma hatası: $e');
      }
    }
  }

  // Export roster history to CSV
  static Future<void> exportRosterHistory(BuildContext context) async {
    final navigatorContext = context;
    bool isLoading = true;
    
    try {
      showDialog(
        context: navigatorContext,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Roster geçmişi dışa aktarılıyor...'),
            ],
          ),
        ),
      );

      final rosterHistory = await _dataService.getRosterHistory();
      final csvContent = _rosterToCsv(rosterHistory);
      final file = await _createExportFile('roster_gecmisi', 'csv', csvContent);
      
      if (navigatorContext.mounted) {
        Navigator.of(navigatorContext).pop();
        isLoading = false;
        
        await _shareFile(file, 'Roster Geçmişi');
        
        if (navigatorContext.mounted) {
          _showSuccessDialog(navigatorContext, 'Roster geçmişiniz CSV formatında dışa aktarıldı!');
        }
      }
      
    } catch (e) {
      if (isLoading && navigatorContext.mounted) {
        Navigator.of(navigatorContext).pop();
      }
      _log.severe('Error exporting roster history: $e');
      if (navigatorContext.mounted) {
        _showErrorDialog(navigatorContext, 'Roster geçmişi dışa aktarma hatası: $e');
      }
    }
  }

  // Collect all user data
  static Future<Map<String, dynamic>> _collectAllData() async {
    final now = DateTime.now();
    
    return {
      'export_info': {
        'export_date': now.toIso8601String(),
        'app_version': '0.2.0', // Get from package info
        'data_format_version': '1.0',
      },
      'roster_history': await _dataService.getRosterHistory().then(
        (history) => history.map((item) => item.toJson()).toList(),
      ),
      'salary_history': await _dataService.getPreviousSalaries(),
      'commission_history': await _getCommissionHistory(),
      'base_salary_data': await _dataService.getBaseSalaryData(),
      'all_app_data': await _dataService.getAllData(),
      'off_duty_counts': await _dataService.getOffDutyCounts(),
      'role_selection': await _dataService.getRoleSelection(),
      'layover_data': await _dataService.getLayoverData(),
    };
  }

  // Get commission history
  static Future<List<Map<String, dynamic>>> _getCommissionHistory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/komisyonlar.json');
      
      if (!await file.exists()) {
        return [];
      }
      
      final content = await file.readAsString();
      final komisyonlar = json.decode(content) as Map<String, dynamic>;
      
      return komisyonlar.entries.map((entry) => {
        'date': entry.key,
        'commission': entry.value['commission'] ?? entry.value['amount'] ?? 0.0,
        'amount': entry.value['amount'] ?? entry.value['commission'] ?? 0.0,
        'is_five_person': entry.value['is_five_person'] ?? false,
        'is_domestic': entry.value['isIcHat'] ?? false,
      }).toList()
        ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
      
    } catch (e) {
      _log.severe('Error getting commission history: $e');
      return [];
    }
  }

  // Convert salaries to CSV
  static String _salariesToCsv(List<Map<String, dynamic>> salaries) {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('Tarih,Dönem,Euro,TL,Görev Saati,Gece Saati,Yatı Sayısı,SCCM');
    
    // Data rows
    for (final salary in salaries) {
      buffer.writeln([
        salary['date'] ?? '',
        salary['rosterPeriod'] ?? '',
        salary['euro']?.toString() ?? '0',
        salary['tl']?.toString() ?? '0',
        salary['dutyHours']?.toString() ?? '0',
        salary['nightHours']?.toString() ?? '0',
        salary['layoverCount']?.toString() ?? '0',
        salary['isSCCM'] == true ? 'Evet' : 'Hayır',
      ].join(','));
    }
    
    return buffer.toString();
  }

  // Convert commissions to CSV
  static String _commissionsToCsv(List<Map<String, dynamic>> commissions) {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('Tarih,Komisyon,5 Kişi,İç Hat');
    
    // Data rows
    for (final commission in commissions) {
      buffer.writeln([
        commission['date'] ?? '',
        commission['commission']?.toString() ?? '0',
        commission['is_five_person'] == true ? 'Evet' : 'Hayır',
        commission['is_domestic'] == true ? 'Evet' : 'Hayır',
      ].join(','));
    }
    
    return buffer.toString();
  }

  // Convert roster to CSV
  static String _rosterToCsv(List rosterHistory) {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('Dosya Adı,Tarih,Veri');
    
    // Data rows
    for (final roster in rosterHistory) {
      buffer.writeln([
        roster.fileName ?? '',
        roster.date?.toString() ?? '',
        '"${roster.data?.toString().replaceAll('"', '""') ?? ''}"',
      ].join(','));
    }
    
    return buffer.toString();
  }

  // Create export file
  static Future<File> _createExportFile(String baseName, String extension, String content) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = '${baseName}_$timestamp.$extension';
    final file = File('${directory.path}/$fileName');
    
    await file.writeAsString(content);
    return file;
  }

  // Share file
  static Future<void> _shareFile(File file, String subject) async {
    try {
      final extension = file.path.split('.').last;
      final mimeType = extension == 'json' ? 'application/json' : 'text/csv';
      final shareText = extension == 'json'
          ? 'Keisan uygulaması tam veri yedekleme dosyası'
          : 'Keisan uygulaması $subject verisi';
          
      final xFile = XFile(
        file.path,
        mimeType: mimeType,
        name: file.path.split('/').last
      );

      final result = await Share.shareXFiles(
        [xFile],
        subject: subject,
        text: shareText,
      );

      switch (result.status) {
        case ShareResultStatus.success:
          _log.info('File shared successfully via ${result.raw}');
          break;
        case ShareResultStatus.dismissed:
          _log.info('Share sheet dismissed by user');
          break;
        default:
          _log.warning('Share completed with status: ${result.status}');
      }
    } catch (e) {
      _log.severe('Error sharing file: $e');
      rethrow; // Let the caller handle the error
    }
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
