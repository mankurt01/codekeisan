import 'package:flutter_test/flutter_test.dart';
import 'package:keisan/services/merak_calculation_service.dart';

void main() {
  group('MerakCalculationService (updated semantics)', () {
    test('uses provided base salary instead of experience lookup', () {
      // CCM base salary 0-2 is 530. Target 800 euro.
      // Fixed base only = 530. Remaining 270 <= 100*2.75 -> regular duty only:
      // requiredDutyHours = 270/2.75 ≈ 98.18h
      final result = MerakCalculationService.calculateRequiredDutyHours(
        targetSalaryEuro: 800,
        baseSalary: 530,
        isSCCM: false,
      );
      expect(result.isAchievable, isTrue);
      expect(result.requiredDutyHours, closeTo(270 / 2.75, 0.01));
      expect(result.breakdown['baseSalary'], 530);
    });

    test('respects the new 180h duty cap', () {
      // CCM: maxAchievable with 180h should = base + 100*duty + 80*overtime
      final result = MerakCalculationService.calculateRequiredDutyHours(
        targetSalaryEuro: 999999,
        baseSalary: 530,
        isSCCM: false,
      );
      expect(result.isAchievable, isFalse);
      expect(result.requiredDutyHours, 180.0);
      final expectedMax = 530 + (100 * 2.75) + (80 * 7.15);
      expect(result.maxAchievableSalary, closeTo(expectedMax, 0.01));
    });

    test('calculateForDuty computes salary for a provided duty time', () {
      // SCCM with 100h duty, 40 night, base 830
      final result = MerakCalculationService.calculateForDuty(
        targetSalaryEuro: 2000,
        baseSalary: 830,
        isSCCM: true,
        dutyHours: 100,
        nightHours: 40,
      );
      final expected = 830 + (100 * 5.5) + (40 * 29.7);
      expect(result.breakdown['total']!, closeTo(expected, 0.01));
      expect(result.isAchievable, isTrue); // 2628 > 2000
    });

    test('calculateForDuty splits overtime above 100h', () {
      final result = MerakCalculationService.calculateForDuty(
        targetSalaryEuro: 0,
        baseSalary: 0,
        isSCCM: false,
        dutyHours: 120,
      );
      // 100h * 2.75 + 20h * 7.15
      expect(result.breakdown['dutyPay']!, closeTo(275.0, 0.01));
      expect(result.breakdown['overtimePay']!, closeTo(143.0, 0.01));
    });

    test('randomizer caps supported by constants', () {
      expect(MerakCalculationService.maxReasonableDutyHours, 180.0);
      expect(MerakCalculationService.regularDutyHoursLimit, 100.0);
    });
  });
}