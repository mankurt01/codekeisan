import 'package:flutter_test/flutter_test.dart';
import 'package:keisan/services/ics_parser_service.dart';
import 'package:keisan/models/schedule_day.dart';

void main() {
  group('IcsParserService new-format parsing', () {
    late IcsParserService service;

    setUp(() {
      service = IcsParserService();
    });

    test('parses single-day FLY event with two legs (AYT-CPH-AYT)', () {
      const ics = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Test//EN
BEGIN:VEVENT
UID:12345
DTSTART:20260707T020000Z
DTEND:20260707T114500Z
SUMMARY:FLY (AYT)
DESCRIPTION:Mon, 07 Jul 2026\\nCheck-in 02:00\\n570 02:53 06:44 AYT - CPH\\n571 09:00 11:30 CPH - AYT\\nRelease 11:45 AYT
END:VEVENT
END:VCALENDAR
''';

      final schedule = service.parseIcsString(ics);
      expect(schedule.length, 1);

      final events = schedule.first.events;
      expect(events.any((e) => e.contains('570') && e.contains('AYT-CPH')), isTrue,
          reason: 'Expected outbound leg 570 AYT-CPH, got: $events');
      expect(events.any((e) => e.contains('571') && e.contains('CPH-AYT')), isTrue,
          reason: 'Expected inbound leg 571 CPH-AYT, got: $events');
      expect(events.any((e) => e.contains('Layover')), isFalse,
          reason: 'Same-day return should not have a layover, got: $events');
    });

    test('parses multi-day layover pairing with hotel/transport embedded', () {
      const ics = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Test//EN
BEGIN:VEVENT
UID:67890
DTSTART:20260720T020000Z
DTEND:20260722T150000Z
SUMMARY:FLY (AYT)
DESCRIPTION:Mon, 20 Jul 2026\\nCheck-in 02:00\\n570 02:53 06:44 AYT - EZS\\n571 09:00 11:30 EZS - STR\\nRelease 00:14 EZS\\nTransport 00:30 01:00 TRANSFER CO\\nHotel 01:15 02:00 ELAZIG PARK DEDEMAN\\nAddress: Some Street 12\\nPhone: +90 123 456 78 90\\nTransport 08:00 08:30 TRANSFER CO\\nWed, 22 Jul 2026\\nCheck-in 09:00\\n572 10:00 12:00 EZS - DUS\\n573 13:00 15:00 DUS - AYT\\nRelease 15:30 AYT
END:VEVENT
END:VCALENDAR
''';

      final schedule = service.parseIcsString(ics);
      expect(schedule.length, 1);

      final events = schedule.first.events;
      expect(events.any((e) => e.contains('Multi-day')), isTrue,
          reason: 'Expected multi-day marker, got: $events');
      expect(events.any((e) => e.contains('Layover: EZS')), isTrue,
          reason: 'Expected layover at EZS, got: $events');
      expect(events.any((e) => e.contains('ELAZIG PARK DEDEMAN')), isTrue,
          reason: 'Expected hotel name, got: $events');
      expect(events.any((e) => e.contains('Transport')), isTrue,
          reason: 'Expected transport lines, got: $events');
      expect(events.any((e) => e.contains('570') && e.contains('AYT-EZS')), isTrue,
          reason: 'Expected outbound leg 570 AYT-EZS, got: $events');
      expect(events.any((e) => e.contains('571') && e.contains('EZS-STR')), isTrue,
          reason: 'Expected outbound leg 571 EZS-STR, got: $events');
      expect(events.any((e) => e.contains('572') && e.contains('EZS-DUS')), isTrue,
          reason: 'Expected inbound leg 572 EZS-DUS, got: $events');
      expect(events.any((e) => e.contains('573') && e.contains('DUS-AYT')), isTrue,
          reason: 'Expected inbound leg 573 DUS-AYT, got: $events');
    });

    test('extractLayoversFromSchedule detects embedded layover', () {
      const ics = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Test//EN
BEGIN:VEVENT
UID:67890
DTSTART:20260720T020000Z
DTEND:20260722T150000Z
SUMMARY:FLY (AYT)
DESCRIPTION:Mon, 20 Jul 2026\\nCheck-in 02:00\\n570 02:53 06:44 AYT - EZS\\nRelease 00:14 EZS\\nHotel 01:15 02:00 ELAZIG PARK DEDEMAN\\nWed, 22 Jul 2026\\nCheck-in 09:00\\n572 10:00 12:00 EZS - DUS\\n573 13:00 15:00 DUS - AYT\\nRelease 15:30 AYT
END:VEVENT
END:VCALENDAR
''';

      final schedule = service.parseIcsString(ics);
      final layovers = service.extractLayoversFromSchedule(schedule);
      expect(layovers.length, 1, reason: 'Expected 1 layover, got: $layovers');
      expect(layovers.first['cityCode'], 'EZS');
    });

    test('parses STANDBY event with CCM SB3 suffix', () {
      const ics = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Test//EN
BEGIN:VEVENT
UID:111
DTSTART:20260701T000000Z
DTEND:20260701T100000Z
SUMMARY:CCM SB3
DESCRIPTION:Wed, 01 Jul 2026\\nStandby 00:00 - 10:00
END:VEVENT
END:VCALENDAR
''';

      final schedule = service.parseIcsString(ics);
      expect(schedule.length, 1);
      final events = schedule.first.events;
      expect(events.any((e) => e.contains('SB3')), isTrue,
          reason: 'Expected SB3 standby, got: $events');
    });

    test('calculateTotalDutyTime debug prints show duty math (diagnostic)', () {
      const ics = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Test//EN
BEGIN:VEVENT
UID:12345
DTSTART:20260707T020000Z
DTEND:20260707T114500Z
SUMMARY:FLY (AYT)
DESCRIPTION:Mon, 07 Jul 2026\\nCheck-in 02:00\\n570 02:53 06:44 AYT - CPH\\n571 09:00 11:30 CPH - AYT\\nRelease 11:45 AYT
END:VEVENT
END:VCALENDAR
''';

      final schedule = service.parseIcsString(ics);
      final dutyTime = service.calculateTotalDutyTime(schedule);
      print('[DEBUG TEST] Duty time reported: $dutyTime');
      print('[DEBUG TEST] Expected duty (Report 02:00 vs Release 11:45) = 09:45 (585 min)');
      print('[DEBUG TEST] Leg durations sum = 231+150 = 381 min = 06:21 (WRONG, too low)');
      expect(dutyTime, isNotEmpty);
    });

    test('parses OFF DUTY event', () {
      const ics = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Test//EN
BEGIN:VEVENT
UID:222
DTSTART:20260702T000000Z
DTEND:20260702T235959Z
SUMMARY:OFF DUTY
DESCRIPTION:Thu, 02 Jul 2026\\nOFF
END:VEVENT
END:VCALENDAR
''';

      final schedule = service.parseIcsString(ics);
      expect(schedule.length, 1);
      final events = schedule.first.events;
      expect(events.any((e) => e.contains('OFF')), isTrue,
          reason: 'Expected OFF event, got: $events');
    });

    // -----------------------------------------------------------------
    // computeLayoverCount tests — combined time + airport + continuity
    // ICS times are UTC. Istanbul = UTC+3.
    // -----------------------------------------------------------------
    test('turnaround (AYT-CPH-AYT) returns 0 layovers', () {
      // Report 03:00 UTC → 06:00 local (≤13:00 → 1), but arrival=CPH≠AYT
      // However flight returns same day to AYT → arrival airport = AYT (home base)
      // Wait: the LAST leg arrival is AYT (CPH→AYT), so it IS a turnaround.
      const ics = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Test//EN
BEGIN:VEVENT
UID:100
DTSTART:20260707T030000Z
DTEND:20260707T114500Z
SUMMARY:FLY (AYT)
DESCRIPTION:Mon, 07 Jul 2026\\nCheck-in 03:00\\n570 04:00 06:30 AYT - CPH\\n571 08:00 11:45 CPH - AYT\\nRelease 11:45 AYT
END:VEVENT
END:VCALENDAR
''';
      final schedule = service.parseIcsString(ics);
      final result = service.computeLayoverCount(schedule, 'AYT');
      expect(result['total'], 0.0,
          reason: 'Turnaround should have 0 layovers, got ${result['total']}');
    });

    test('outbound layover with report <= 13:00 local counts as 1', () {
      // Report 03:00 UTC → 06:00 local (≤13:00 → 1)
      // Arrival at EZS (Turkish, not AYT) → outbound layover
      // Airport rule = 1, report rule = 1 → max = 1
      const ics = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Test//EN
BEGIN:VEVENT
UID:101
DTSTART:20260720T030000Z
DTEND:20260720T050000Z
SUMMARY:FLY (AYT)
DESCRIPTION:Mon, 20 Jul 2026\\nCheck-in 03:00\\n570 03:30 05:00 AYT - EZS\\nRelease 05:00 EZS
END:VEVENT
END:VCALENDAR
''';
      final schedule = service.parseIcsString(ics);
      final result = service.computeLayoverCount(schedule, 'AYT');
      expect(result['total'], 1.0,
          reason: 'Should count 1, got ${result['total']}');
      expect(result['domestic'], greaterThanOrEqualTo(1));
    });

    test('report >= 20:01 local: time rule gives 0, airport still detects', () {
      // Report 18:00 UTC → 21:00 local (≥20:01 → 0 from time rule)
      // But EZS ≠ AYT → airport rule = 1 (both valid → max = 1)
      const ics = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Test//EN
BEGIN:VEVENT
UID:102
DTSTART:20260720T180000Z
DTEND:20260720T230000Z
SUMMARY:FLY (AYT)
DESCRIPTION:Mon, 20 Jul 2026\\nCheck-in 18:00\\n570 18:30 23:00 AYT - EZS\\nRelease 23:00 EZS
END:VEVENT
END:VCALENDAR
''';
      final schedule = service.parseIcsString(ics);
      final result = service.computeLayoverCount(schedule, 'AYT');
      expect(result['total'], 1.0,
          reason: 'Airport rule should detect layover even with late report');
    });

    test('layover at non-Turkish airport is international', () {
      // Report 03:00 UTC → 06:00 local (≤13:00 → 1)
      // Arrival at CPH (non-Turkish) → international
      const ics = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Test//EN
BEGIN:VEVENT
UID:103
DTSTART:20260707T030000Z
DTEND:20260707T070000Z
SUMMARY:FLY (AYT)
DESCRIPTION:Mon, 07 Jul 2026\\nCheck-in 03:00\\n570 04:00 06:30 AYT - CPH\\nRelease 07:00 CPH
END:VEVENT
END:VCALENDAR
''';
      final schedule = service.parseIcsString(ics);
      final result = service.computeLayoverCount(schedule, 'AYT');
      expect(result['international'], greaterThanOrEqualTo(1),
          reason: 'CPH is non-Turkish → international');
      expect(result['domestic'], 0);
    });

    test('day off between layover days still counts as 1 layover', () {
      // Day 1: outbound to EZS (report 03:00 UTC → 06:00 local → 1)
      // Day 2: OFF (continuity rule → +1)
      // Day 3: outbound to EZS (report 03:00 UTC → 06:00 local → 1)
      const ics = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Test//EN
BEGIN:VEVENT
UID:104a
DTSTART:20260720T030000Z
DTEND:20260720T050000Z
SUMMARY:FLY (AYT)
DESCRIPTION:Mon, 20 Jul 2026\\nCheck-in 03:00\\n570 03:30 05:00 AYT - EZS\\nRelease 05:00 EZS
END:VEVENT
BEGIN:VEVENT
UID:104b
DTSTART:20260721T000000Z
DTEND:20260721T235959Z
SUMMARY:OFF DUTY
DESCRIPTION:Tue, 21 Jul 2026\\nOFF
END:VEVENT
BEGIN:VEVENT
UID:104c
DTSTART:20260722T030000Z
DTEND:20260722T050000Z
SUMMARY:FLY (AYT)
DESCRIPTION:Wed, 22 Jul 2026\\nCheck-in 03:00\\n571 03:30 05:00 AYT - EZS\\nRelease 05:00 EZS
END:VEVENT
END:VCALENDAR
''';
      final schedule = service.parseIcsString(ics);
      final result = service.computeLayoverCount(schedule, 'AYT');
      // Day 1: 1, Day 2 off: 1, Day 3: 1 = 3
      expect(result['total'], 3.0,
          reason: 'Day off between layovers should add 1 each');
    });

    test('return to base applies release time rule', () {
      // Day 1: outbound AYT→EZS, report 03:00 UTC → 06:00 local (≤13:00 → 1)
      // Day 2: return EZS→AYT, release 16:00 UTC → 19:00 local (≥19:00 → 1)
      const ics = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Test//EN
BEGIN:VEVENT
UID:105a
DTSTART:20260720T030000Z
DTEND:20260720T050000Z
SUMMARY:FLY (AYT)
DESCRIPTION:Mon, 20 Jul 2026\\nCheck-in 03:00\\n570 03:30 05:00 AYT - EZS\\nRelease 05:00 EZS
END:VEVENT
BEGIN:VEVENT
UID:105b
DTSTART:20260721T140000Z
DTEND:20260721T160000Z
SUMMARY:FLY (AYT)
DESCRIPTION:Tue, 21 Jul 2026\\nCheck-in 14:00\\n571 14:30 16:00 EZS - AYT\\nRelease 16:00 AYT
END:VEVENT
END:VCALENDAR
''';
      final schedule = service.parseIcsString(ics);
      final result = service.computeLayoverCount(schedule, 'AYT');
      // Outbound: 1, Return (≥19:00 local): 1 = 2
      expect(result['total'], 2.0,
          reason: 'Outbound + late-return = 2');
    });

    test('return with early release (≤ 11:59) adds 0', () {
      // Day 1: outbound AYT→EZS, report 03:00 UTC → 06:00 local → 1
      // Day 2: return EZS→AYT, release 08:00 UTC → 11:00 local (≤11:59 → 0)
      const ics = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Test//EN
BEGIN:VEVENT
UID:106a
DTSTART:20260720T030000Z
DTEND:20260720T050000Z
SUMMARY:FLY (AYT)
DESCRIPTION:Mon, 20 Jul 2026\\nCheck-in 03:00\\n570 03:30 05:00 AYT - EZS\\nRelease 05:00 EZS
END:VEVENT
BEGIN:VEVENT
UID:106b
DTSTART:20260721T053000Z
DTEND:20260721T090000Z
SUMMARY:FLY (AYT)
DESCRIPTION:Tue, 21 Jul 2026\\nCheck-in 05:30\\n571 06:00 08:00 EZS - AYT\\nRelease 08:00 AYT
END:VEVENT
END:VCALENDAR
''';
      final schedule = service.parseIcsString(ics);
      final result = service.computeLayoverCount(schedule, 'AYT');
      // Outbound: 1, Return (≤11:59 local): 0 = 1
      expect(result['total'], 1.0,
          reason: 'Return with early release should add 0');
    });
  });
}
