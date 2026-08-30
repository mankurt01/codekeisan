import '../constants/salary_rates.dart';

class MerakCalculationResult {
  final double requiredDutyHours;
  final bool isAchievable;
  final double maxAchievableSalary;
  final Map<String, double> breakdown;

  MerakCalculationResult({
    required this.requiredDutyHours,
    required this.isAchievable,
    required this.maxAchievableSalary,
    required this.breakdown,
  });
}

class MerakCalculationService {
  // Maximum allowed duty hours per month (the "Görev Saati" cap)
  static const double maxReasonableDutyHours = 180.0;
  static const double regularDutyHoursLimit = 100.0;

  /// Calculates the required duty hours to achieve a target salary
  /// This is the reverse of the normal salary calculation
  static MerakCalculationResult calculateRequiredDutyHours({
    required double targetSalaryEuro,
    required double baseSalary,
    required bool isSCCM,
    double nightHours = 0.0,
    double commission = 0.0,
    double domesticLayovers = 0.0,
    double internationalLayovers = 0.0,
  }) {
    // Get salary rates for the selected role
    final rates = isSCCM ? SalaryRates.sccmRates : SalaryRates.ccmRates;

    // Fixed components that don't depend on duty hours
    final nightPay = nightHours * (rates['nightHour'] ?? 0.0);
    final domesticLayoverPay =
        domesticLayovers * SalaryRates.domesticOvernightRate;
    final internationalLayoverPay =
        internationalLayovers * SalaryRates.internationalOvernightRate;
    final layoverPay = domesticLayoverPay + internationalLayoverPay;

    final fixedComponents = baseSalary + nightPay + layoverPay + commission;

    // Calculate the maximum achievable salary (with max reasonable duty hours)
    final maxRegularDutyPay = regularDutyHoursLimit * (rates['duty'] ?? 0.0);
    final maxOvertimeHours = maxReasonableDutyHours - regularDutyHoursLimit;
    final maxOvertimePay = maxOvertimeHours > 0
        ? maxOvertimeHours * (rates['overtime'] ?? 0.0)
        : 0.0;
    final maxAchievableSalary =
        fixedComponents + maxRegularDutyPay + maxOvertimePay;

    // Check if target is achievable
    final isAchievable = targetSalaryEuro <= maxAchievableSalary;

    // Calculate required duty hours
    double requiredDutyHours = 0.0;
    double dutyPay = 0.0;
    double overtimePay = 0.0;

    if (isAchievable) {
      final remainingSalary = targetSalaryEuro - fixedComponents;

      if (remainingSalary <= 0) {
        // Target is achievable with zero duty hours
        requiredDutyHours = 0.0;
      } else {
        // Calculate required duty hours
        final regularDutyRate = rates['duty'] ?? 0.0;
        final overtimeRate = rates['overtime'] ?? 0.0;

        if (remainingSalary <= regularDutyHoursLimit * regularDutyRate) {
          // Can be achieved with regular duty hours only
          requiredDutyHours = remainingSalary / regularDutyRate;
          dutyPay = requiredDutyHours * regularDutyRate;
        } else {
          // Need overtime hours
          dutyPay = regularDutyHoursLimit * regularDutyRate;
          final remainingAfterRegular = remainingSalary - dutyPay;
          final overtimeHours = remainingAfterRegular / overtimeRate;
          requiredDutyHours = regularDutyHoursLimit + overtimeHours;
          overtimePay = overtimeHours * overtimeRate;
        }
      }
    } else {
      // Target is not achievable, show maximum
      requiredDutyHours = maxReasonableDutyHours;
      dutyPay = maxRegularDutyPay;
      overtimePay = maxOvertimePay;
    }

    // Create breakdown
    final breakdown = <String, double>{
      'baseSalary': baseSalary,
      'dutyPay': dutyPay,
      'overtimePay': overtimePay,
      'nightPay': nightPay,
      'layoverPay': layoverPay,
      'commission': commission,
      'total': fixedComponents + dutyPay + overtimePay,
    };

    return MerakCalculationResult(
      requiredDutyHours: requiredDutyHours,
      isAchievable: isAchievable,
      maxAchievableSalary: maxAchievableSalary,
      breakdown: breakdown,
    );
  }

  /// Computes the achieved salary for a fixed duty time (used when the user
  /// provides their own duty hours instead of letting the app fill it).
  static MerakCalculationResult calculateForDuty({
    required double targetSalaryEuro,
    required double baseSalary,
    required bool isSCCM,
    required double dutyHours,
    double nightHours = 0.0,
    double commission = 0.0,
    double domesticLayovers = 0.0,
    double internationalLayovers = 0.0,
  }) {
    final rates = isSCCM ? SalaryRates.sccmRates : SalaryRates.ccmRates;
    final regularDutyRate = rates['duty'] ?? 0.0;
    final overtimeRate = rates['overtime'] ?? 0.0;
    final nightRate = rates['nightHour'] ?? 0.0;

    final regularHours = dutyHours > regularDutyHoursLimit
        ? regularDutyHoursLimit
        : dutyHours;
    final overtimeHours = dutyHours > regularDutyHoursLimit
        ? dutyHours - regularDutyHoursLimit
        : 0.0;

    final dutyPay = regularHours * regularDutyRate;
    final overtimePay = overtimeHours * overtimeRate;
    final nightPay = nightHours * nightRate;
    final domesticLayoverPay =
        domesticLayovers * SalaryRates.domesticOvernightRate;
    final internationalLayoverPay =
        internationalLayovers * SalaryRates.internationalOvernightRate;
    final layoverPay = domesticLayoverPay + internationalLayoverPay;
    final total =
        baseSalary + dutyPay + overtimePay + nightPay + layoverPay + commission;

    final breakdown = <String, double>{
      'baseSalary': baseSalary,
      'dutyPay': dutyPay,
      'overtimePay': overtimePay,
      'nightPay': nightPay,
      'layoverPay': layoverPay,
      'commission': commission,
      'total': total,
    };

    return MerakCalculationResult(
      requiredDutyHours: dutyHours,
      isAchievable: total >= targetSalaryEuro,
      maxAchievableSalary: total,
      breakdown: breakdown,
    );
  }

  /// Get base salary for a given role and experience
  static double getBaseSalary(bool isSCCM, String experience) {
    final baseSalaryMap = isSCCM
        ? SalaryRates.sccmBaseSalary
        : SalaryRates.ccmBaseSalary;
    return baseSalaryMap[experience] ?? baseSalaryMap['0-2']!;
  }

  /// Calculate the theoretical maximum salary for a role
  static double calculateMaximumSalary({
    required bool isSCCM,
    required String experience,
    double nightHours = 40.0, // Maximum reasonable night hours
    double commission = 300.0, // High commission estimate
    double layovers = 10.0, // Maximum layovers
  }) {
    final rates = isSCCM ? SalaryRates.sccmRates : SalaryRates.ccmRates;
    final baseSalary = getBaseSalary(isSCCM, experience);

    final regularDutyPay = regularDutyHoursLimit * (rates['duty'] ?? 0.0);
    final overtimeHours = maxReasonableDutyHours - regularDutyHoursLimit;
    final overtimePay = overtimeHours * (rates['overtime'] ?? 0.0);
    final nightPay = nightHours * (rates['nightHour'] ?? 0.0);
    final layoverPay = layovers * SalaryRates.domesticOvernightRate;

    return baseSalary +
        regularDutyPay +
        overtimePay +
        nightPay +
        layoverPay +
        commission;
  }
}
