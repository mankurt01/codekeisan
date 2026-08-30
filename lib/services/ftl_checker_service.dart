import '../models/duty_model.dart';
import '../models/legality_result.dart';

class FTLCheckerService {
  static LegalityResult checkDutyChangeLegality({
    required DateTime notificationTime,
    required Duty currentDuty,
    required Duty newDuty,
    DateTime? previousDutyCheckOut,
    String restLocation = 'Home Base', // 'Home Base' or 'Layover'
    bool isExtension = false, // true for duty extension, false for duty replacement
  }) {
    print('🔍 ===== FTL CHECKER DEBUG START =====');
    print('📅 Notification Time: ${_formatDateTime(notificationTime)}');
    print('🔵 Current Duty: ${currentDuty.type} ${_formatDateTime(currentDuty.checkInDateTime!)} - ${_formatDateTime(currentDuty.checkOutDateTime!)}');
    print('🔴 New Duty: ${newDuty.type} ${_formatDateTime(newDuty.checkInDateTime!)} - ${_formatDateTime(newDuty.checkOutDateTime!)}');
    if (previousDutyCheckOut != null) {
      print('📋 Previous Duty C/O: ${_formatDateTime(previousDutyCheckOut)}');
    }
    print('🏠 Rest Location: $restLocation');
    
    List<LegalityCheck> checks = [];
    bool isLegal = true;
    String legalityType = 'success';

    final currentCheckIn = currentDuty.checkInDateTime!;
    final currentCheckOut = currentDuty.checkOutDateTime!;
    final newCheckIn = newDuty.checkInDateTime!;
    final newCheckOut = newDuty.checkOutDateTime!;

    // Calculate durations - NO AUTOMATIC DAY ADJUSTMENT
    // Use actual previous duty checkout if provided, otherwise use current duty end
    final restStartTime = previousDutyCheckOut ?? currentCheckOut;
    final restHours = newCheckIn.difference(restStartTime).inMinutes / 60.0;
    final notifToNewDuty = newCheckIn.difference(notificationTime).inMinutes / 60.0;
    final newDutyDuration = newCheckOut.difference(newCheckIn).inMinutes / 60.0;
    
    // Calculate time difference for ±2 hour rule (based on start times)
    final timeDiff = (newCheckIn.difference(currentCheckIn).inMinutes / 60.0).abs();
    
    // Calculate duty duration change for company rules
    final currentDutyDuration = currentCheckOut.difference(currentCheckIn).inMinutes / 60.0;
    final dutyDurationChange = newDutyDuration - currentDutyDuration;

    print('⏱️ CALCULATIONS:');
    print('   Rest Start: ${_formatDateTime(restStartTime)} (${previousDutyCheckOut != null ? "actual previous C/O" : "current duty end"})');
    print('   Rest Hours: ${restHours.toStringAsFixed(2)}h (${restHours < 0 ? "NEGATIVE - OVERLAP!" : "positive"})');
    print('   Notice Hours: ${notifToNewDuty.toStringAsFixed(2)}h');
    print('   Current Duration: ${currentDutyDuration.toStringAsFixed(2)}h');
    print('   New Duration: ${newDutyDuration.toStringAsFixed(2)}h');
    print('   Duration Change: ${dutyDurationChange.toStringAsFixed(2)}h');
    print('   Start Time Diff: ${timeDiff.toStringAsFixed(2)}h');

    // Check for duty overlap only if this is an extension, not a replacement
    print('🔍 DUTY TYPE CHECK:');
    print('   Is Extension: $isExtension');
    
    if (isExtension) {
      print('🔍 OVERLAP CHECK (Extension):');
      bool dutiesOverlap = _checkDutyOverlap(currentCheckIn, currentCheckOut, newCheckIn, newCheckOut);
      print('   Same day: ${currentCheckIn.day == newCheckIn.day && currentCheckIn.month == newCheckIn.month && currentCheckIn.year == newCheckIn.year}');
      print('   Duties overlap: $dutiesOverlap');
      
      if (dutiesOverlap) {
        print('❌ OVERLAP DETECTED - Adding fail check');
        checks.add(LegalityCheck(
          rule: 'Duty Extension Overlap Detection',
          status: 'fail',
          message: 'Extension overlaps with existing duty. Current: ${_formatTime(currentCheckIn)}-${_formatTime(currentCheckOut)}, Extension: ${_formatTime(newCheckIn)}-${_formatTime(newCheckOut)}',
          reference: 'SHT-FTL Basic Scheduling Logic',
        ));
        isLegal = false;
      } else {
        print('✅ No duty overlap detected');
      }
    } else {
      print('🔍 REPLACEMENT CHECK:');
      print('   New duty replaces current duty - no overlap check needed');
      print('   Current duty: ${_formatTime(currentCheckIn)}-${_formatTime(currentCheckOut)} will be replaced');
      print('   New duty: ${_formatTime(newCheckIn)}-${_formatTime(newCheckOut)} will take its place');
    }

    // Check 1: SHT-FTL Minimum Rest Period (ORO.FTL.235(a))
    // Minimum rest based on location type per SHT-FTL ORO.FTL.235
    // Home Base: 12 hours, Layover: 10 hours
    final minimumRestHours = restLocation == 'Home Base' ? 12 : 10;
    
    print('🔍 REST PERIOD CHECK:');
    print('   Rest hours: ${restHours.toStringAsFixed(2)}h');
    print('   Required: ≥${minimumRestHours}h at $restLocation');
    print('   Rest from: ${_formatDateTime(restStartTime)} to ${_formatDateTime(newCheckIn)}');
    
    if (restHours < minimumRestHours) {
      print('❌ REST PERIOD FAIL - Adding fail check');
      checks.add(LegalityCheck(
        rule: 'SHT-FTL Minimum Rest Period ($restLocation)',
        status: 'fail',
        message: 'Rest period is ${restHours.toStringAsFixed(1)}h. Minimum ${minimumRestHours}h required at $restLocation.',
        reference: 'SHT-FTL ORO.FTL.235(a)(1)',
      ));
      isLegal = false;
    } else {
      print('✅ REST PERIOD PASS');
      checks.add(LegalityCheck(
        rule: 'SHT-FTL Minimum Rest Period ($restLocation)',
        status: 'pass',
        message: 'Rest period: ${restHours.toStringAsFixed(1)}h (≥${minimumRestHours}h required at $restLocation)',
        reference: 'SHT-FTL ORO.FTL.235(a)(1)',
      ));
    }

    // Check 2: Company Rule - 12h Between Assignment and New Duty
    print('🔍 COMPANY NOTICE CHECK:');
    print('   Notice hours: ${notifToNewDuty.toStringAsFixed(2)}h (required: ≥12h)');
    
    if (notifToNewDuty < 12) {
      print('❌ COMPANY NOTICE FAIL - Adding fail check');
      checks.add(LegalityCheck(
        rule: 'Company 12-Hour Notice Rule',
        status: 'fail',
        message: 'Only ${notifToNewDuty.toStringAsFixed(1)}h between notification and new duty. Company requires minimum 12h.',
        reference: 'Company Procedure 2.h',
      ));
      isLegal = false;
    } else {
      print('✅ COMPANY NOTICE PASS');
      checks.add(LegalityCheck(
        rule: 'Company 12-Hour Notice Rule',
        status: 'pass',
        message: '${notifToNewDuty.toStringAsFixed(1)}h between notification and new duty (≥12h required)',
        reference: 'Company Procedure 2.h',
      ));
    }

    // Check 3: Company Rule - ±2 Hour Time Frame Rule
    print('🔍 COMPANY ±2H TIME FRAME CHECK:');
    print('   Start time diff: ${timeDiff.toStringAsFixed(2)}h (limit: ≤2h)');
    print('   Duration change: ${dutyDurationChange.toStringAsFixed(2)}h (limit: ≤±2h)');
    
    if (timeDiff <= 2 && dutyDurationChange.abs() <= 2) {
      print('✅ COMPANY TIME FRAME PASS');
      checks.add(LegalityCheck(
        rule: 'Company ±2 Hour Time Frame',
        status: 'pass',
        message: 'Time/duration change within ±2h limit. No mutual agreement needed.',
        reference: 'Company Procedure 2.g',
      ));
    } else {
      print('❌ COMPANY TIME FRAME FAIL - Adding fail check');
      String changeType = '';
      if (timeDiff > 2) changeType += 'Start time change: ${timeDiff.toStringAsFixed(1)}h. ';
      if (dutyDurationChange.abs() > 2) changeType += 'Duration change: ${dutyDurationChange.toStringAsFixed(1)}h. ';
      
      checks.add(LegalityCheck(
        rule: 'Company ±2 Hour Time Frame',
        status: 'fail',
        message: '${changeType}Exceeds ±2h limit. Mutual agreement required.',
        reference: 'Company Procedure 2.g',
      ));
      isLegal = false;
    }

    // Check 4: SHT-FTL Reserve (RZV) Specific Rules
    print('🔍 RESERVE CHECK:');
    print('   Current duty type: ${currentDuty.type}, New duty type: ${newDuty.type}');
    
    if (newDuty.type == 'RZV' || currentDuty.type == 'RZV') {
      print('   Reserve detected - checking notice requirement');
      print('   Notice hours: ${notifToNewDuty.toStringAsFixed(2)}h (SHT-FTL required: ≥10h)');
      
      if (notifToNewDuty < 10) {
        print('❌ RESERVE NOTICE FAIL - Adding fail check');
        checks.add(LegalityCheck(
          rule: 'SHT-FTL Reserve Minimum Notice',
          status: 'fail',
          message: 'Reserve requires minimum 10h notice per SHT-FTL. Current: ${notifToNewDuty.toStringAsFixed(1)}h',
          reference: 'SHT-FTL CS FTL.1.230 / IR ORO.FTL.230',
        ));
        isLegal = false;
      } else {
        print('✅ RESERVE NOTICE PASS');
        checks.add(LegalityCheck(
          rule: 'SHT-FTL Reserve Minimum Notice',
          status: 'pass',
          message: 'Reserve notice: ${notifToNewDuty.toStringAsFixed(1)}h (≥10h SHT-FTL requirement)',
          reference: 'SHT-FTL CS FTL.1.230 / IR ORO.FTL.230',
        ));
      }
      
      // Reserve 8h undisturbed period requirement
      checks.add(LegalityCheck(
        rule: 'SHT-FTL Reserve Undisturbed Period',
        status: 'warning',
        message: 'Ensure 8h undisturbed period included in reserve time per SHT-FTL.',
        reference: 'SHT-FTL CS FTL.1.230(d)',
      ));
      if (isLegal) legalityType = 'warning';
    }

    // Check 5: Standby (SBY) Specific Rules
    print('🔍 STANDBY CHECK:');
    print('   Current duty type: ${currentDuty.type}');
    
    if (currentDuty.type == 'SBY') {
      print('   Standby detected - checking duration limits');
      final standbyDuration = newCheckIn.difference(currentCheckIn).inMinutes / 60.0;
      print('   Standby duration: ${standbyDuration.toStringAsFixed(2)}h (SHT-FTL limit: ≤16h)');
      
      if (standbyDuration > 16) {
        print('❌ STANDBY DURATION FAIL - Adding fail check');
        checks.add(LegalityCheck(
          rule: 'SHT-FTL Maximum Standby Duration',
          status: 'fail',
          message: 'Standby duration: ${standbyDuration.toStringAsFixed(1)}h exceeds 16h maximum per SHT-FTL.',
          reference: 'SHT-FTL CS FTL.1.225(b)(1)',
        ));
        isLegal = false;
      } else {
        print('✅ STANDBY DURATION PASS');
        checks.add(LegalityCheck(
          rule: 'SHT-FTL Maximum Standby Duration',
          status: 'pass',
          message: 'Standby duration: ${standbyDuration.toStringAsFixed(1)}h (≤16h SHT-FTL limit)',
          reference: 'SHT-FTL CS FTL.1.225(b)(1)',
        ));
      }

      // FDP reduction after standby (SHT-FTL requirement)
      if (standbyDuration > 6) {
        final fdpReduction = standbyDuration - 6;
        checks.add(LegalityCheck(
          rule: 'SHT-FTL FDP Reduction After Standby',
          status: 'warning',
          message: 'FDP must be reduced by ${fdpReduction.toStringAsFixed(1)}h (standby >6h). Max FDP after standby: ${(13 - fdpReduction).toStringAsFixed(1)}h',
          reference: 'SHT-FTL CS FTL.1.225(a)(2)(i)',
        ));
        if (isLegal) legalityType = 'warning';
      }

      // Check combined standby + FDP (SHT-FTL requirement)
      final combinedDuration = standbyDuration + newDutyDuration;
      if (combinedDuration > 18) {
        checks.add(LegalityCheck(
          rule: 'SHT-FTL Combined Standby + FDP',
          status: 'fail',
          message: 'Combined standby + FDP: ${combinedDuration.toStringAsFixed(1)}h exceeds 18h maximum per SHT-FTL.',
          reference: 'SHT-FTL CS FTL.1.225(b)(2)',
        ));
        isLegal = false;
      }
    }

    // Check 6: Company Rule - Maximum Duty Period with Deadhead
    if (newDutyDuration > 17) {
      checks.add(LegalityCheck(
        rule: 'Company Maximum Duty Period',
        status: 'warning',
        message: 'Duty duration: ${newDutyDuration.toStringAsFixed(1)}h. Company limit is 17h if deadhead involved.',
        reference: 'Company Procedure 1.l',
      ));
      if (isLegal) legalityType = 'warning';
    }

    // Check 7: Company Rule - Maximum 6 Consecutive Duty Days
    // Note: This would require additional context about previous duties
    // For now, add as informational
    checks.add(LegalityCheck(
      rule: 'Company Consecutive Duty Days',
      status: 'warning',
      message: 'Verify this duty does not exceed 6 consecutive duty days (max 20 sectors).',
      reference: 'Company Procedure 1.p',
    ));

    // Generate summary based on regulatory hierarchy
    String summary;
    if (!isLegal) {
      legalityType = 'error'; // Fix: Set proper error type when not legal
      summary = 'NOT LEGAL: Duty change violates SHT-FTL regulations and/or company procedures';
    } else if (legalityType == 'warning') {
      summary = 'LEGAL with conditions: Mutual agreement or special considerations required';
    } else {
      summary = 'LEGAL: Duty change complies with SHT-FTL regulations and company procedures';
    }

    print('🔍 ===== FTL CHECKER DEBUG SUMMARY =====');
    print('📊 FINAL RESULT:');
    print('   Legal: $isLegal');
    print('   Type: $legalityType');
    print('   Summary: $summary');
    print('   Total Checks: ${checks.length}');
    
    int passCount = checks.where((c) => c.status == 'pass').length;
    int failCount = checks.where((c) => c.status == 'fail').length;
    int warnCount = checks.where((c) => c.status == 'warning').length;
    
    print('   ✅ Pass: $passCount, ❌ Fail: $failCount, ⚠️  Warning: $warnCount');
    print('🔍 ===== FTL CHECKER DEBUG END =====');

    return LegalityResult(
      isLegal: isLegal,
      type: legalityType,
      summary: summary,
      checks: checks,
    );
  }

  /// Check if two duty periods overlap on the same day
  static bool _checkDutyOverlap(DateTime currentStart, DateTime currentEnd, 
                                DateTime newStart, DateTime newEnd) {
    // Check if duties are on the same calendar day
    bool sameDay = currentStart.year == newStart.year && 
                   currentStart.month == newStart.month && 
                   currentStart.day == newStart.day;
    
    if (!sameDay) return false;
    
    // Check for time overlap on the same day
    return (newStart.isBefore(currentEnd) && newEnd.isAfter(currentStart));
  }

  /// Format DateTime to HH:mm string
  static String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Format DateTime to full date-time string for debugging
  static String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${_formatTime(dateTime)}';
  }
}