import 'package:flutter/material.dart';
import '../services/data_service.dart';
import '../services/calculation_service.dart';
import '../routes.dart';

class QuickCalculationService {
  static Future<void> calculateAndNavigate(
    BuildContext context,
    Map<String, dynamic> analysisData,
  ) async {
    try {
      final dataService = DataService();

      // Get saved role
      final savedRole = await dataService.getRoleSelection();
      if (savedRole == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lütfen önce pozisyonunuzu seçin (CCM/SCCM)'),
            ),
          );
        }
        return;
      }

      // Get saved base salary data
      final baseSalaryData = await dataService.getBaseSalaryData();
      if (baseSalaryData == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Base maaş bilgisi bulunamadı')),
          );
        }
        return;
      }

      // Calculate necessary values from analysis data
      final dutyHours = CalculationService.calculateDutyHours(
        analysisData['totalDutyTime'] as String? ?? "00:00",
      );
      final nightHours = CalculationService.calculateNightHours(
        analysisData['nightHours'] as String? ?? "00:00",
      );
      final flightCounts =
          analysisData['flightCounts'] as Map<String, dynamic>? ?? {};
      final legCounts = CalculationService.calculateLegCounts(flightCounts);
      final layoverCount = analysisData['layoverCount'] as int? ?? 0;
      final offDutyCounts = analysisData['offDutyCounts'] as int? ?? 0;
      final rosterPeriod = analysisData['rosterPeriod'] as String? ?? '';

      // Extract off days data
      final offDays = analysisData['offDays'] as List<Map<String, dynamic>>? ?? [];

      // Get current commission
      final commission = await dataService.getCurrentCommission(rosterPeriod);

      if (context.mounted) {
        await Navigator.pushNamed(
          context,
          Routes.result,
          arguments: {
            'isSCCM': savedRole == 'SCCM',
            'dutyHours': dutyHours,
            'nightHours': nightHours,
            'legCounts': legCounts,
            'commission': commission,
            'include_commission': savedRole != 'SCCM',
            'layoverCount': layoverCount,
            'offDutyCounts': offDutyCounts,
            'sixthDay': baseSalaryData['sixthDay'] ?? 0,
            'internationalOvernight':
                baseSalaryData['internationalOvernight'] ?? 0,
            'rosterPeriod': rosterPeriod,
            'offDays': offDays,
          },
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hesaplama yapılırken hata: $e')),
        );
      }
    }
  }
}
