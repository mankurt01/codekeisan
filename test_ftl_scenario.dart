// Test script to verify the corrected FTL checker
// This simulates your original scenario:
// - Notification time: 12:00 today
// - Current duty: 12:00-16:00 RZV (Reserve)  
// - New duty: 12:00-18:00 SBY (Standby)
// - Both duties on same day

import 'package:flutter/material.dart';
import 'lib/models/duty_model.dart';
import 'lib/services/ftl_checker_service.dart';

void main() {
  // Set up the scenario
  final today = DateTime.now();
  final notificationTime = DateTime(today.year, today.month, today.day, 12, 0);
  
  // Current duty: RZV 12:00-16:00 today
  final currentDuty = Duty(type: 'RZV');
  currentDuty.date = today;
  currentDuty.checkIn = const TimeOfDay(hour: 12, minute: 0);
  currentDuty.checkOut = const TimeOfDay(hour: 16, minute: 0);
  
  // New duty: SBY 12:00-18:00 today (same day)
  final newDuty = Duty(type: 'SBY');
  newDuty.date = today; // Same day - this should trigger overlap detection
  newDuty.checkIn = const TimeOfDay(hour: 12, minute: 0);
  newDuty.checkOut = const TimeOfDay(hour: 18, minute: 0);
  
  // Test the corrected FTL checker
  print('=== FTL CHECKER TEST ===');
  print('Testing scenario:');
  print('- Notification: ${notificationTime.hour}:${notificationTime.minute.toString().padLeft(2, '0')}');
  print('- Current duty: ${currentDuty.type} ${currentDuty.checkIn!.hour}:${currentDuty.checkIn!.minute.toString().padLeft(2, '0')}-${currentDuty.checkOut!.hour}:${currentDuty.checkOut!.minute.toString().padLeft(2, '0')}');
  print('- New duty: ${newDuty.type} ${newDuty.checkIn!.hour}:${newDuty.checkIn!.minute.toString().padLeft(2, '0')}-${newDuty.checkOut!.hour}:${newDuty.checkOut!.minute.toString().padLeft(2, '0')}');
  print('- Same day: YES (this should be flagged as illegal)');
  print('');
  
  // Test 1: Duty REPLACEMENT (default scenario - new duty replaces current)
  print('=== TEST 1: DUTY REPLACEMENT (Home Base) ===');
  var result = FTLCheckerService.checkDutyChangeLegality(
    notificationTime: notificationTime,
    currentDuty: currentDuty,
    newDuty: newDuty,
    restLocation: 'Home Base',
    isExtension: false, // Replacement - no overlap check
  );
  
  _printResult(result, 1);
  
  // Test 2: Duty EXTENSION (new duty adds to current - should check overlap)
  print('=== TEST 2: DUTY EXTENSION (would check overlap) ===');
  result = FTLCheckerService.checkDutyChangeLegality(
    notificationTime: notificationTime,
    currentDuty: currentDuty,
    newDuty: newDuty,
    restLocation: 'Home Base',
    isExtension: true, // Extension - checks overlap
  );
  
  _printResult(result, 2);
  
  // Test 3: With previous duty checkout (different rest calculation at Layover)
  print('=== TEST 3: With Previous Duty Checkout (Layover) ===');
  final previousCheckOut = DateTime(today.year, today.month, today.day, 8, 0); // 0800 same day
  
  result = FTLCheckerService.checkDutyChangeLegality(
    notificationTime: notificationTime,
    currentDuty: currentDuty,
    newDuty: newDuty,
    previousDutyCheckOut: previousCheckOut,
    restLocation: 'Layover',
    isExtension: false, // Replacement
  );
  
  _printResult(result, 3);
  
  print('=== ALL TESTS COMPLETE ===');
}

void _printResult(result, int testNum) {
  print('=== RESULTS TEST $testNum ===');
  print('Legal: ${result.isLegal}');
  print('Type: ${result.type}');
  print('Summary: ${result.summary}');
  print('');
  print('=== DETAILED CHECKS ===');
  
  for (int i = 0; i < result.checks.length; i++) {
    final check = result.checks[i];
    final status = check.status.toUpperCase();
    final icon = check.status == 'pass' ? '✅' :
                 check.status == 'warning' ? '⚠️' : '❌';
    
    print('${i + 1}. $icon [$status] ${check.rule}');
    print('   ${check.message}');
    print('   Reference: ${check.reference}');
    print('');
  }
  print('');
  
  print('=== EXPECTED BEHAVIOR ===');
  print('This scenario should show "NOT LEGAL" because:');
  print('1. ❌ Duty Overlap: Same-day duties overlap (12:00-16:00 vs 12:00-18:00)');
  print('2. ❌ Zero Rest: No rest period between duties (negative rest hours)');  
  print('3. ❌ Zero Notice: 0 hours between notification and new duty (needs 12h)');
  print('4. ❌ Reserve Notice: RZV needs 10h notice, got 0h');
  print('5. ❌ Time Frame: Exceeds ±2h company rule (4h duration change)');
  print('');
  print('The old buggy code would have shown "LEGAL" by artificially');
  print('adjusting the new duty to tomorrow, creating fake rest periods.');
}