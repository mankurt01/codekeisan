import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keisan/services/ics_parser_service.dart';

void main() {
  late IcsParserService service;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    service = IcsParserService();
  });

  group('extractRelcalId', () {
    test('extracts X-WR-RELCALID from a real SunExpress-style header', () {
      const ics = 'BEGIN:VCALENDAR\r\n'
          'VERSION:2.0\r\n'
          'PRODID:CrewAccess\r\n'
          'X-WR-CALNAME:CrewAccess-events\r\n'
          'X-WR-RELCALID:003823\r\n'
          'NAME:CrewAccess-events\r\n'
          'BEGIN:VEVENT\r\n'
          'UID:2989693-1\r\n';
      expect(service.extractRelcalId(ics), '003823');
    });

    test('falls back to plain RELCALID when X-WR- prefix is absent', () {
      const ics = 'BEGIN:VCALENDAR\nRELCALID:123456\nBEGIN:VEVENT\n';
      expect(service.extractRelcalId(ics), '123456');
    });

    test('is case-insensitive and trims whitespace', () {
      const ics = 'x-wr-relcalid:  009988  \n';
      expect(service.extractRelcalId(ics), '009988');
    });

    test('returns null when the id is missing or empty', () {
      expect(service.extractRelcalId('BEGIN:VCALENDAR\n'), isNull);
      expect(service.extractRelcalId('X-WR-RELCALID:\n'), isNull);
      expect(service.extractRelcalId('X-WR-RELCALID:   \n'), isNull);
    });
  });

  group('verifyRosterOwnership', () {
    test('first import saves the id seamlessly and allows processing',
        () async {
      service.parseIcsString(
          'BEGIN:VCALENDAR\nX-WR-RELCALID:003823\nEND:VCALENDAR\n');
      expect(await service.verifyRosterOwnership(), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('roster_relcal_id'), '003823');
    });

    test('matching id on a later import is allowed', () async {
      SharedPreferences.setMockInitialValues(
          <String, Object>{'roster_relcal_id': '003823'});
      service.parseIcsString(
          'BEGIN:VCALENDAR\nX-WR-RELCALID:003823\nEND:VCALENDAR\n');
      expect(await service.verifyRosterOwnership(), isTrue);
    });

    test('mismatched id on a later import is rejected', () async {
      SharedPreferences.setMockInitialValues(
          <String, Object>{'roster_relcal_id': '003823'});
      service.parseIcsString(
          'BEGIN:VCALENDAR\nX-WR-RELCALID:999999\nEND:VCALENDAR\n');
      expect(await service.verifyRosterOwnership(), isFalse);
    });

    test('file without RELCALID is allowed but flagged (cannot compare)',
        () async {
      SharedPreferences.setMockInitialValues(
          <String, Object>{'roster_relcal_id': '003823'});
      service.parseIcsString('BEGIN:VCALENDAR\nEND:VCALENDAR\n');
      expect(service.lastRelcalId, isNull);
      expect(await service.verifyRosterOwnership(), isTrue);
    });
  });
}
