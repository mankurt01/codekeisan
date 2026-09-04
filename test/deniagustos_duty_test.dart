import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:keisan/services/ics_parser_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('deniagustos.ics total duty time', () async {
    final ics = File('deniagustos.ics').readAsStringSync();
    final service = IcsParserService();
    final schedule = service.parseIcsString(ics);
    print('Days parsed: ${schedule.length}');
    for (final day in schedule) {
      print('${day.date} -> ${day.events}');
    }
    print('TOTAL DUTY: ${service.calculateTotalDutyTime(schedule)}');
    // Expected: 14 FLY duties at 100% (check-in→release) + standbys at 25%
    // = 8879 min = 147:59 (CrewAccess reference ≈ 148 h).
    expect(service.calculateTotalDutyTime(schedule), '147:59');
  });
}
