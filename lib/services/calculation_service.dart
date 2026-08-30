import 'package:logging/logging.dart';
import '../constants/salary_rates.dart';

class CalculationResult {
  final Map<String, dynamic> components;
  final double totalEuro;
  final double totalTL;
  final Map<String, String> formattedValues;

  CalculationResult({
    required this.components,
    required this.totalEuro,
    required this.totalTL,
    required this.formattedValues,
  });
}

class CalculationService {
  static final _logger = Logger('CalculationService');

  // Layover calculation methods
  static double calculateLayoverAllowance(DateTime reportingTime) {
    final hour = reportingTime.hour;
    final minute = reportingTime.minute;

    // Convert to 24-hour decimal time for comparison (e.g., 10:30 = 10.5)
    final decimalTime = hour + (minute / 60);

    if (decimalTime <= 10.0) {
      return 1.0; // Full allowance
    } else if (decimalTime <= 17.0) {
      return 0.5; // Half allowance
    } else {
      return 0.0; // No allowance
    }
  }

  /// Calculates when a layover period ends
  /// The end time is 30 minutes after the check-out time from either:
  /// - A duty flight
  /// - A dead-head flight
  /// - Ground transport
  static DateTime calculateLayoverEnd(DateTime checkOutTime) {
    // Layover ends 30 minutes after check-out time
    return checkOutTime.add(const Duration(minutes: 30));
  }

  /// Calculates layover allowance based on reporting time:
  /// - Returns 1.0 (full day) if reporting time is before or at 10:00
  /// - Returns 0.5 (half day) if reporting time is between 10:01 and 17:00
  /// - Returns 0.0 (no allowance) if reporting time is after 17:00
  ///
  /// A layover starts with a duty flight, dead-head flight, or ground transport check-in time

  // Time calculation methods
  static double calculateDutyHours(String totalDutyTime) {
    if (totalDutyTime.isEmpty) return 0.0;

    final parts = totalDutyTime.split(':');
    if (parts.length == 2) {
      try {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        return hours + (minutes / 60);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }

  static double calculateNightHours(String totalNightTime) {
    if (totalNightTime.isEmpty) return 0.0;

    final parts = totalNightTime.split(':');
    if (parts.length == 2) {
      try {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        return hours + (minutes / 60);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }

  static Map<String, int> calculateLegCounts(
      Map<String, dynamic> flightCounts) {
    try {
      return {
        'leg3': (flightCounts['3'] as num?)?.toInt() ?? 0,
        'leg4': (flightCounts['4'] as num?)?.toInt() ?? 0,
        'leg5': (flightCounts['5'] as num?)?.toInt() ?? 0,
      };
    } catch (e) {
      _logger.warning('Error parsing leg counts: $e');
      return {'leg3': 0, 'leg4': 0, 'leg5': 0};
    }
  }

  // Salary calculation methods
  static Map<String, double> calculateComponents({
    required bool isSCCM,
    required double dutyHours,
    required double nightHours,
    required Map<String, int> legCounts,
    required double commission,
    required Map<String, dynamic> baseSalaryData,
    required int layoverCount,
    required int offDutyCounts,
    double domesticCommission = 0.0,
  }) {
    if (baseSalaryData.isEmpty) return {};

    final result = calculate(
      isSCCM: isSCCM,
      dutyHours: dutyHours,
      nightHours: nightHours,
      legCounts: legCounts,
      commission: commission,
      baseSalaryData: baseSalaryData,
      layoverCount: layoverCount,
      offDutyCounts: offDutyCounts,
      domesticCommission: domesticCommission,
    );

    final components = Map<String, double>.from(result.components);
    components['total_euro'] = result.totalEuro;
    components['total_tl'] = result.totalTL;
    components['euro_rate'] = baseSalaryData['euroRate'] ?? 0.0;

    return components;
  }

  static CalculationResult calculate({
    required bool isSCCM,
    required double dutyHours,
    required double nightHours,
    required Map<String, int> legCounts,
    required double commission,
    required Map<String, dynamic> baseSalaryData,
    required int layoverCount,
    required int offDutyCounts,
    double domesticCommission = 0.0,
  }) {
    final rates = isSCCM ? SalaryRates.sccmRates : SalaryRates.ccmRates;
    final regularDutyHours = dutyHours.clamp(0, 100);
    final overtimeHours = dutyHours > 100 ? dutyHours - 100 : 0;

    // Get the overnight values and ensure they're numbers
    final internationalOvernight =
        (baseSalaryData['internationalOvernight'] ?? 0) as num;
    final duzeltme = (baseSalaryData['duzeltme'] ?? 0) as num;

    // Calculate the components
    final components = <String, double>{
      'base_pay': baseSalaryData['baseSalary'] ?? 0.0,
      'commission': commission,
      'duty_pay': regularDutyHours * (rates['duty'] ?? 0.0),
      'overtime_pay': overtimeHours * (rates['overtime'] ?? 0.0),
      'leg3_pay': legCounts['leg3']! * (rates['leg3'] ?? 0.0),
      'leg4_pay': legCounts['leg4']! * (rates['leg4'] ?? 0.0),
      'leg5_pay': legCounts['leg5']! * (rates['leg5'] ?? 0.0),
      'sixth_day_pay':
          (baseSalaryData['sixthDay'] ?? 0) * (rates['sixthDay'] ?? 0.0),
      'off_duty_pay': offDutyCounts * (rates['offDuty'] ?? 0.0),
      'night_hours_pay': nightHours * (rates['nightHour'] ?? 0.0),

      // Store layover counts for reference
      'total_layovers': layoverCount.toDouble(),
      'raw_layovers': layoverCount.toDouble(),
      'duzeltme': duzeltme.toDouble(),
      'adjusted_layovers': (layoverCount + duzeltme.toInt()).toDouble(),

      // Calculate overnight pay components
      'domestic_overnight_count':
          ((layoverCount + duzeltme.toInt()) - internationalOvernight)
              .toDouble(),
      'domestic_overnight_pay':
          ((layoverCount + duzeltme.toInt()) - internationalOvernight) *
              SalaryRates.domesticOvernightRate,
      'international_overnight_pay':
          internationalOvernight * SalaryRates.internationalOvernightRate,
      
      // Add domestic commission (İç Hat) - already in TL
      'ic_hat_komisyon': domesticCommission,
    };

    // Only sum actual pay components for Euro calculation
    const payComponentKeys = [
      'base_pay',
      'commission',
      'duty_pay',
      'overtime_pay',
      'leg3_pay',
      'leg4_pay',
      'leg5_pay',
      'sixth_day_pay',
      'off_duty_pay',
      'night_hours_pay',
      'domestic_overnight_pay',
      'international_overnight_pay',
    ];
    final totalEuro = payComponentKeys.fold<double>(0, (sum, key) => sum + (components[key] ?? 0.0));
    
    // Convert Euro salary to TL and add domestic commission (TL)
    final euroToTL = totalEuro * (baseSalaryData['euroRate'] ?? 0.0);
    final totalTL = euroToTL + domesticCommission;

    final formattedValues = {
      'regular_duty_hours': regularDutyHours.toStringAsFixed(1),
      'overtime_hours': overtimeHours.toStringAsFixed(1),
      'night_hours': nightHours.toStringAsFixed(1),
    };

    components.forEach((key, value) {
      formattedValues[key] = value.toStringAsFixed(2);
    });

    return CalculationResult(
      components: components,
      totalEuro: totalEuro,
      totalTL: totalTL,
      formattedValues: formattedValues,
    );
  }
}
