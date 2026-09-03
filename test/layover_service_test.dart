import 'package:flutter_test/flutter_test.dart';
import 'package:keisan/models/layover_event.dart';
import 'package:keisan/services/layover_service.dart';

/// Minimal stand-in for icalendar_parser's dtstart object: the service
/// accesses it dynamically as `dtstart.dt`.
class _FakeDtStart {
  final DateTime dt;
  _FakeDtStart(this.dt);
}

Map<String, dynamic> _event({
  required String uid,
  required String summary,
  required DateTime dtStart,
  required String description,
  String location = '',
}) {
  return {
    'uid': uid,
    'summary': summary,
    'dtstart': _FakeDtStart(dtStart),
    'description': description,
    'location': location,
  };
}

void main() {
  group('LayoverService.extractLayoversFromEvents', () {
    test('same-day round trip AYT-BTS-AYT (multi-day VEVENT, next duty from AYT) creates NO layover', () {
      final events = [
        _event(
          uid: 'fly-8',
          summary: 'FLY (AYT-BTS-AYT)',
          dtStart: DateTime(2026, 9, 8, 6, 0),
          description: [
            'Mon, 8 Sep 2026',
            'Check-in    06:00               AYT',
            'XQ 502    08:10  10:20   AYT-BTS',
            'XQ 503    11:30  13:40   BTS-AYT',
            'Release     18:30               AYT',
            'Tue, 9 Sep 2026',
            'Check-in    06:00               AYT',
            'XQ 510    08:00  09:30   AYT-IST',
            'Release     20:00               AYT',
          ].join('\n'),
        ),
      ];

      final layovers = LayoverService.extractLayoversFromEvents(events, 'u');
      expect(layovers, isEmpty, reason: 'Duty released at home base AYT — crew went home, not a layover');
    });

    test('consecutive AYT duties as separate VEVENTs (>=8h gap) create NO layover', () {
      final events = [
        _event(
          uid: 'a',
          summary: 'FLY (AYT-BTS-AYT)',
          dtStart: DateTime(2026, 9, 8, 6, 0),
          description: [
            'Mon, 8 Sep 2026',
            'Check-in    06:00               AYT',
            'XQ 502    08:10  10:20   AYT-BTS',
            'XQ 503    11:30  13:40   BTS-AYT',
            'Release     18:30               AYT',
          ].join('\n'),
        ),
        _event(
          uid: 'b',
          summary: 'FLY (AYT-IST-AYT)',
          dtStart: DateTime(2026, 9, 9, 6, 0),
          description: [
            'Tue, 9 Sep 2026',
            'Check-in    06:00               AYT',
            'XQ 510    08:00  09:30   AYT-IST',
            'Release     20:00               AYT',
          ].join('\n'),
        ),
      ];

      final layovers = LayoverService.extractLayoversFromEvents(events, 'u');
      expect(layovers, isEmpty, reason: 'Both duties end at home base AYT — a long ground gap is just rest at home');
    });

    test('real overnight layover away from base is detected (embedded format)', () {
      final events = [
        _event(
          uid: 'fly-20',
          summary: 'FLY (AYT-EZS-AYT)',
          dtStart: DateTime(2026, 7, 20, 9, 0),
          description: [
            'Mon, 20 Jul 2026',
            'Check-in    09:00               AYT',
            'XQ 7715   11:30  13:10   AYT-EZS',
            'Release     00:14               EZS',
            'Hotel       00:34  23:10        ELAZIG PARK DEDEMAN HOTEL',
            'Tue, 21 Jul 2026',
            'Check-in    23:30               EZS',
            'XQ 7716   01:10  02:50   EZS-AYT',
            'Release     04:00               AYT',
          ].join('\n'),
        ),
      ];

      final layovers = LayoverService.extractLayoversFromEvents(events, 'u');
      expect(layovers.length, 1);
      expect(layovers.first.location, 'EZS');
      expect(layovers.first.isInternational, isFalse, reason: 'EZS is a Turkish domestic airport');
      expect(layovers.first.date, DateTime(2026, 7, 20));
    });
    test('real layover between separate VEVENTs uses the release airport as location', () {
      final events = [
        _event(
          uid: 'p1',
          summary: 'FLY (AYT-EZS)',
          dtStart: DateTime(2026, 7, 20, 9, 0),
          description: [
            'Mon, 20 Jul 2026',
            'Check-in    09:00               AYT',
            'XQ 7715   11:30  13:10   AYT-EZS',
            'Release     00:14               EZS',
          ].join('\n'),
        ),
        _event(
          uid: 'p2',
          summary: 'FLY (EZS-AYT)',
          dtStart: DateTime(2026, 7, 21, 23, 0),
          description: [
            'Tue, 21 Jul 2026',
            'Check-in    23:30               EZS',
            'XQ 7716   01:10  02:50   EZS-AYT',
            'Release     04:00               AYT',
          ].join('\n'),
        ),
      ];

      final layovers = LayoverService.extractLayoversFromEvents(events, 'u');
      expect(layovers.length, 1);
      expect(layovers.first.location, 'EZS',
          reason: 'Location must be the release station, not the return flight destination');
      expect(layovers.first.isInternational, isFalse);
    });

    test('FLY -> NON-FLY -> FLY group creates a layover at the NON-FLY station', () {
      final events = [
        _event(
          uid: 'g-1',
          summary: 'FLY (AYT-COV)',
          dtStart: DateTime(2026, 9, 10, 9, 0),
          description: [
            'Thu, 10 Sep 2026',
            'Check-in    09:00               AYT',
            'XQ 301    11:00  12:30   AYT-COV',
            'Release     19:28               COV',
            'Hotel       19:58  05:17        DIVAN HOTEL',
          ].join('\n'),
        ),
        _event(
          uid: 'g-2',
          summary: 'NON-FLY (COV)',
          dtStart: DateTime(2026, 9, 11, 0, 0),
          description: 'Fri, 11 Sep 2026\nHotel       19:28  05:17        DIVAN HOTEL\nAddress: Corfu',
        ),
        _event(
          uid: 'g-3',
          summary: 'FLY (COV-AYT)',
          dtStart: DateTime(2026, 9, 12, 5, 0),
          description: [
            'Sat, 12 Sep 2026',
            'Check-in    05:00               COV',
            'XQ 302    07:00  10:00   COV-AYT',
            'Release     11:00               AYT',
          ].join('\n'),
        ),
      ];

      final layovers = LayoverService.extractLayoversFromEvents(events, 'u');
      expect(layovers.length, 1);
      expect(layovers.first.location, 'COV');
      expect(layovers.first.isInternational, isTrue, reason: 'COV (Corfu) is not in the domestic list');
      expect(layovers.first.date, DateTime(2026, 9, 10));
    });

    test('allowance types are derived from next reporting time', () {
      final events = [
        _event(
          uid: 'q1',
          summary: 'FLY (AYT-EZS)',
          dtStart: DateTime(2026, 7, 20, 9, 0),
          description: 'Mon, 20 Jul 2026\nCheck-in    09:00               AYT\nRelease     20:00               EZS',
        ),
        _event(
          uid: 'q2',
          summary: 'FLY (EZS-AYT)',
          dtStart: DateTime(2026, 7, 21, 6, 0),
          description: 'Tue, 21 Jul 2026\nCheck-in    09:30               EZS\nRelease     14:00               AYT',
        ),
      ];

      final layovers = LayoverService.extractLayoversFromEvents(events, 'u');
      expect(layovers.length, 1);
      // Reporting at 09:30 (<= 10:00) → full allowance, domestic €30.
      expect(layovers.first.allowanceMultiplier, 1.0);
      expect(layovers.first.paymentAmount, 30.0);
      expect(layovers.first.layoverType, 'Full Day');
    });
  });

  group('LayoverEvent.createFromTimes', () {
    test('date is anchored to the layover start (check-out + 30 min)', () {
      final layover = LayoverEvent.createFromTimes(
        id: 'x',
        checkOutTime: DateTime(2026, 9, 8, 23, 50),
        reportingTime: DateTime(2026, 9, 10, 6, 0),
        isInternational: false,
        location: 'EZS',
        userId: 'u',
      );
      expect(layover.date, DateTime(2026, 9, 9), reason: '23:50 + 30 min crosses midnight to the 9th');
      expect(layover.layoverStartTime, DateTime(2026, 9, 9, 0, 20));
    });
  });
  group('LayoverService multi-night pairing in one VEVENT', () {
    test('two nights in a single FLY event produce two layovers', () {
      final events = [
        _event(
          uid: 'multi-1',
          summary: 'FLY (AYT-EZS-BTS-AYT)',
          dtStart: DateTime(2026, 8, 10, 9, 0),
          description: [
            'Mon, 10 Aug 2026',
            'Check-in    09:00               AYT',
            'XQ 501    11:00  12:30   AYT-EZS',
            'Release     20:00               EZS',
            'Hotel       20:30  06:00        ELAZIG PARK HOTEL',
            'Tue, 11 Aug 2026',
            'Check-in    07:00               EZS',
            'XQ 502    09:00  10:30   EZS-BTS',
            'Release     19:00               BTS',
            'Hotel       19:30  05:00        BURSA HOTEL',
            'Wed, 12 Aug 2026',
            'Check-in    06:00               BTS',
            'XQ 503    08:00  09:30   BTS-AYT',
            'Release     12:00               AYT',
          ].join('\n'),
        ),
      ];

      final layovers = LayoverService.extractLayoversFromEvents(events, 'u');
      expect(layovers.length, 2,
          reason: 'One layover per night: EZS (Mon) and BTS (Tue)');
      expect(layovers[0].location, 'EZS');
      expect(layovers[1].location, 'BTS');
    });
  });
}
