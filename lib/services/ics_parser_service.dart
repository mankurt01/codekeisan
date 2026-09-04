import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:icalendar_parser/icalendar_parser.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/schedule_day.dart';
import '../data/turkish_airports.dart';

class IcsParserService {
  // --- ICS timestamp format hardening ---------------------------------------
  // All calculations assume roster times are published in UTC ("Z" suffix).
  // These counters/warnings surface violations instead of letting them
  // silently shift every calculation by the local UTC offset.
  static int _utcTimestampCount = 0;
  static int _convertedTimestampCount = 0;
  static int _ambiguousTimestampCount = 0;
  static final Set<String> _warnedTimeFormats = <String>{};

  /// Türkiye is on permanent UTC+3 (DST abolished in 2016), so a TZID of
  /// Europe/Istanbul can be converted deterministically without pulling in
  /// the heavyweight `timezone` package.
  static const int _istanbulOffsetMinutes = 180;

  void _warnOnce(String message) {
    if (_warnedTimeFormats.add(message)) {
      print('[WARN] IcsParserService: $message');
    }
  }

  // --- Roster ownership (RELCALID) -------------------------------------------
  // Each crew member's exported ICS carries a unique calendar id, e.g.
  // "X-WR-RELCALID:003823". The first successful import binds that id to the
  // device (persisted via SharedPreferences); any later import whose id
  // differs is rejected so a roster can't be processed on someone else's
  // install.
  static const String _relcalIdPrefKey = 'roster_relcal_id';

  /// RELCALID extracted from the most recently parsed ICS (null if absent).
  String? lastRelcalId;

  /// Extracts the calendar owner id from raw ICS content.
  /// Handles both "X-WR-RELCALID:003823" and plain "RELCALID:003823".
  String? extractRelcalId(String icsString) {
    final match = RegExp(r'^X-WR-RELCALID[ \t]*:[ \t]*([^\r\n]+)',
            multiLine: true, caseSensitive: false)
            .firstMatch(icsString) ??
        RegExp(r'^RELCALID[ \t]*:[ \t]*([^\r\n]+)',
                multiLine: true, caseSensitive: false)
            .firstMatch(icsString);
    if (match == null) return null;
    final id = match.group(1)!.trim();
    return id.isEmpty ? null : id;
  }

  /// Compares the RELCALID of the just-parsed ICS with the id saved on this
  /// device.
  ///
  /// - First import ever (nothing saved): stores the id seamlessly → true
  /// - File has no RELCALID: comparison impossible → true (warned in log)
  /// - Id matches the saved id → true
  /// - Id differs → false (caller must abort and show the warning)
  Future<bool> verifyRosterOwnership() async {
    final fileId = lastRelcalId;
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_relcalIdPrefKey);
    print('[DEBUG] verifyRosterOwnership: fileId=$fileId savedId=$savedId');

    if (fileId == null || fileId.isEmpty) {
      _warnOnce('Parsed ICS has no RELCALID — roster ownership check skipped');
      return true;
    }
    if (savedId == null || savedId.isEmpty) {
      await prefs.setString(_relcalIdPrefKey, fileId);
      print('[DEBUG] verifyRosterOwnership: first import — saved RELCALID '
          '$fileId as this device\'s roster id');
      return true;
    }
    return savedId == fileId;
  }

  /// Calculates total duty time in HH:mm for a list of ScheduleDay parsed from ICS.
  ///
  /// Rules:
  /// - Duty days: duty time = Release - Report (check-in to check-out)
  /// - Standby days: duty time = 25% of the standby window
  /// - Other days (OFF, transport-only, hotel-only): 0
  String calculateTotalDutyTime(List<ScheduleDay> schedule) {
    int totalMinutes = 0;
    int dutyDays = 0;
    int standbyDays = 0;

    print('[DEBUG] calculateTotalDutyTime: START - ${schedule.length} days to process');
    for (final day in schedule) {
      final eventStrings = <String>[];
      for (final event in day.events) {
        eventStrings.add(event);
      }

      // Check if this is a standby day
      final isStandby = day.events.any((e) => e.contains('SB'));

      if (isStandby) {
        // Standby: 25% of the standby window
        int standbyMinutes = 0;
        for (final event in day.events) {
          final match = RegExp(r'(\d{2}:\d{2})\s*[-~]\s*(\d{2}:\d{2})').firstMatch(event);
          if (match != null) {
            final start = _timeToMinutes(match.group(1)!);
            final end = _timeToMinutes(match.group(2)!);
            int diff = end - start;
            if (diff < 0) diff += 24 * 60;
            standbyMinutes += diff;
          }
        }
        final standbyDuty = (standbyMinutes * 0.25).round();
        totalMinutes += standbyDuty;
        standbyDays++;
        print('[DEBUG] calculateTotalDutyTime: day=${DateFormat('yyyy-MM-dd').format(day.date)} '
            'STANDBY events=$eventStrings standbyWindow=${standbyMinutes}min '
            'duty25%=${standbyDuty}min');
      } else {
        // Duty day: Report/Check-in -> Release
        String? reportTime;
        String? releaseTime;
        for (final event in day.events) {
          if (event.contains('Report') || event.contains('Check-in')) {
            final m = RegExp(r'(\d{1,2}:\d{2})').firstMatch(event);
            if (m != null) reportTime = m.group(1);
          }
          if (event.contains('Release')) {
            final m = RegExp(r'(\d{1,2}:\d{2})').firstMatch(event);
            if (m != null) releaseTime = m.group(1);
          }
        }

        if (reportTime != null && releaseTime != null) {
          final start = _timeToMinutes(reportTime);
          final end = _timeToMinutes(releaseTime);
          int diff = end - start;
          if (diff < 0) diff += 24 * 60;
          totalMinutes += diff;
          dutyDays++;
          print('[DEBUG] calculateTotalDutyTime: day=${DateFormat('yyyy-MM-dd').format(day.date)} '
              'DUTY report=$reportTime release=$releaseTime diff=${diff}min');
        } else {
          print('[DEBUG] calculateTotalDutyTime: day=${DateFormat('yyyy-MM-dd').format(day.date)} '
              'NO DUTY (report=$reportTime release=$releaseTime) events=$eventStrings');
        }
      }
    }
    print('[DEBUG] calculateTotalDutyTime: totalDays=${schedule.length} dutyDays=$dutyDays '
        'standbyDays=$standbyDays totalMinutes=$totalMinutes '
        '(${totalMinutes ~/ 60}h ${totalMinutes % 60}m)');
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}' ;
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
  /// Parse ICS data from bytes
  Future<List<ScheduleDay>> parseIcs(Uint8List icsBytes) async {
    final icsString = utf8.decode(icsBytes);
    return parseIcsString(icsString);
  }

  /// Splits a multi-day FLY event description into per-day chunks keyed by the
  /// date parsed from each date header (e.g. "Sat, 15 Aug 2026").
  ///
  /// CrewAccess packs whole pairings into a single VEVENT whose DTSTART is day
  /// 1 only. Without this split every pairing day lands on day 1, so per-day
  /// rules (layover counting, duty time) see one giant day whose last leg
  /// arrives back at base and misclassify the whole pairing as a turnaround.
  ///
  /// Returns an empty map when the description has zero or one date header
  /// (single-day event -> the caller keeps the normal grouping path).
  Map<DateTime, List<String>> _splitFlyDescriptionByDay(String description) {
    final decoded = description
        .replaceAll('\\n', '\n')
        .replaceAll('\\N', '\n')
        .replaceAll('\\,', ',')
        .replaceAll('\\;', ';');

    // Only split pairings that actually place the crew away from base: the
    // description must carry layover evidence — a hotel booking or a release
    // at a non-base station. Overnight turnarounds that simply end back at
    // base (e.g. AYT-ERF / ERF-AYT with no hotel and the final release at
    // AYT) must stay merged, otherwise the outbound day is miscounted as a
    // layover instead of a rest stop.
    final hasHotel =
        RegExp(r'Hotel\s+\d{1,2}:\d{2}', caseSensitive: false).hasMatch(decoded);
    final baseMatch = RegExp(r'\(([A-Z]{3})').firstMatch(description);
    final base = (baseMatch != null ? baseMatch.group(1)! : 'AYT').toUpperCase();
    final hasAwayRelease = RegExp(r'Release\s*\d{1,2}:\d{2}\s+([A-Z]{3})')
        .allMatches(decoded)
        .any((m) => m.group(1)!.toUpperCase() != base);
    if (!hasHotel && !hasAwayRelease) return {};

    final headerRe = RegExp(
      r'^(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun),?\s+(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{4})',
      caseSensitive: false,
    );
    const monthMap = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    final result = <DateTime, List<String>>{};
    DateTime? currentDate;
    var headerCount = 0;
    for (final rawLine in decoded.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final m = headerRe.firstMatch(line);
      if (m != null) {
        final day = int.parse(m.group(1)!);
        final month = monthMap[m.group(2)!.toLowerCase()]!;
        final year = int.parse(m.group(3)!);
        currentDate = DateTime(year, month, day);
        result.putIfAbsent(currentDate, () => []);
        headerCount++;
        continue;
      }
      if (currentDate == null) continue;
      if (line.startsWith('- - -')) continue;
      result[currentDate]!.add(line);
    }
    if (headerCount <= 1) return {};
    // Drop chunks that carry neither flight legs nor a Release line: they are
    // hotel/transport tails already covered by the neighbouring VEVENTs
    // (rosters that publish pairings as several VEVENTs repeat the hotel and
    // the next-day check-in inside the outbound event). Keeping them would
    // create phantom leg-less days and inflate the continuity count.
    final legRe = RegExp(
        r'(\d{3,4})\s+(\d{2}:\d{2})\s+(\d{2}:\d{2})\s+[A-Z]{3}\s*-\s*[A-Z]{3}');
    result.removeWhere((_, lines) {
      final joined = lines.join('\n');
      return !legRe.hasMatch(joined) &&
          !RegExp(r'\bRelease\b').hasMatch(joined);
    });
    return result;
  }

  /// Parse ICS string into ScheduleDays
  /// Parse ICS string into ScheduleDays
  List<ScheduleDay> parseIcsString(String icsString) {
    try {
      // Reset per-import timestamp-format statistics.
      _utcTimestampCount = 0;
      _convertedTimestampCount = 0;
      _ambiguousTimestampCount = 0;
      _warnedTimeFormats.clear();
      // Capture the calendar owner id for the ownership check (if present).
      lastRelcalId = extractRelcalId(icsString);
      print('[DEBUG] parseIcsString: RELCALID=$lastRelcalId');
      // RFC 5545 3.1: a CRLF immediately followed by a space or tab is a soft
      // line break and must be removed. Producers fold mid-token (e.g.
      // "7646        \r\n 10:36"); if folds reach the parser untouched, the
      // tokens glue together ("764610:36") and flight legs silently stop
      // matching. Unfold here so the parser sees the original logical lines.
      icsString = icsString.replaceAll(RegExp(r'\r\n[ \t]'), '');
      final iCalendar = ICalendar.fromString(icsString);
      final events = iCalendar.data;
      
      print('[DEBUG] parseIcsString: found ${events.length} total items');
      
      // Group events by Day
      final Map<String, List<Map<String, dynamic>>> eventsByDay = {};
      // Pre-formatted events from multi-day pairing VEVENTs, keyed by the
      // date header each pairing day belongs to.
      final Map<String, List<String>> preFormattedByDay = {};

      for (final event in events) {
        if (event['type'] != 'VEVENT') continue;

        final dtStart = _parseIcsDate(event['dtstart']);
        print('[DEBUG] parseIcsString: VEVENT type=${event['type']} '
            'summary=${event['summary']} dtstart=${event['dtstart']} parsed=$dtStart');
        if (dtStart == null) continue;

        final summary = (event['summary'] ?? '').toString();
        final isFly = summary.contains('FLY') ||
            summary.contains('XQ') ||
            summary.contains('TK') ||
            summary.contains('Flight');

        // New CrewAccess format: whole multi-day pairings are packed into a
        // single VEVENT whose DTSTART is day 1 only. Split the description
        // into one day per date header so per-day rules (layover counting,
        // duty time) see the pairing day by day.
        if (isFly) {
          final dayChunks =
              _splitFlyDescriptionByDay((event['description'] ?? '').toString());
          if (dayChunks.length > 1) {
            final dtEnd = _parseIcsDate(event['dtend']);
            final startTime = DateFormat('HH:mm').format(dtStart);
            final endTime =
                dtEnd != null ? DateFormat('HH:mm').format(dtEnd) : '';
            dayChunks.forEach((chunkDate, chunkLines) {
              final dayKey = DateFormat('yyyy-MM-dd').format(chunkDate);
              final formatted = _parseFlyEvent(
                  chunkLines.join('\n'), startTime, endTime, summary);
              preFormattedByDay.putIfAbsent(dayKey, () => []).addAll(
                  ['📅 Multi-day pairing', ...formatted]);
            });
            continue;
          }
        }

        // Key by YYYY-MM-DD
        final key = DateFormat('yyyy-MM-dd').format(dtStart);
        eventsByDay.putIfAbsent(key, () => []).add(event);
      }
      
      print('[DEBUG] parseIcsString: grouped into ${eventsByDay.length} days');
      
      // Convert to ScheduleDays
      List<ScheduleDay> schedule = [];
      final allDayKeys = <String>{...eventsByDay.keys, ...preFormattedByDay.keys}
          .toList()
        ..sort();

      for (final key in allDayKeys) {
        final date = DateTime.parse(key);
        final dayEventsRaw = eventsByDay[key] ?? [];

        // Multi-day pairing chunks are already in chronological order.
        final formattedEvents = <String>[...preFormattedByDay[key] ?? const []];

        final dayEventsRawSorted = [...dayEventsRaw]..sort((a, b) {
           final tA = _parseIcsDate(a['dtstart']);
           final tB = _parseIcsDate(b['dtstart']);
           return tA!.compareTo(tB!);
        });
        for (final rawEvent in dayEventsRawSorted) {
           formattedEvents.addAll(_formatEventForCompatibility(rawEvent));
        }
        
        print('[DEBUG] parseIcsString: day=$key events=$formattedEvents');
        
        schedule.add(ScheduleDay(
          date: date,
          dayOfWeek: DateFormat('EEEE').format(date),
          events: formattedEvents,
        ));
      }
      
      print('[DEBUG] parseIcsString: timestamp formats -> '
          'UTC(Z)= $_utcTimestampCount, '
          'tzidConverted= $_convertedTimestampCount, '
          'ambiguous= $_ambiguousTimestampCount'
          '${_convertedTimestampCount > 0 || _ambiguousTimestampCount > 0 ? ' ⚠️ NOT PURE UTC' : ''}');

      return schedule;
      
    } catch (e) {
      print('Error parsing ICS: $e');
      return [];
    }
  }
  
  DateTime? _parseIcsDate(dynamic dateField) {
    if (dateField == null) return null;
    try {
      if (dateField is IcsDateTime) {
        return _parseIcsTimestamp(dateField.dt, tzid: dateField.tzid); 
      }
      // Handle simple string (e.g. created by simple parsers)
      // 20251201T100000Z
      // 20251201
      final s = dateField.toString();
      if (s.length == 8) {
         return DateTime.utc(
           int.parse(s.substring(0, 4)),
           int.parse(s.substring(4, 6)),
           int.parse(s.substring(6, 8)),
         );
      }
      if (s.contains('T')) {
          // Naive ISO parser
         // ... typically icalendar_parser handles this, but let's be safe
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Parses an ICS DATE-TIME value while verifying the publication format.
  ///
  /// Expected form: UTC ending in "Z" (e.g. `20260707T014000Z`). Floating
  /// local times or unsupported TZIDs are still parsed (as UTC wall clock,
  /// preserving previous behaviour) but flagged via [WARN] logs so a
  /// publisher-side format change cannot silently shift every calculation.
  DateTime? _parseIcsTimestamp(String raw, {String? tzid}) {
    final trimmed = raw.trim();
    final hasZ = trimmed.toUpperCase().endsWith('Z');
    final naive =
        hasZ ? trimmed.substring(0, trimmed.length - 1) : trimmed;
    final parsed = DateTime.tryParse(naive);
    if (parsed == null) return null;

    // Normalise explicitly to UTC so downstream DateFormat('HH:mm') renders
    // identical digits regardless of the device's timezone setting.
    DateTime asUtc(DateTime wallClock) => DateTime.utc(
        wallClock.year, wallClock.month, wallClock.day,
        wallClock.hour, wallClock.minute, wallClock.second);

    if (hasZ) {
      _utcTimestampCount++;
      return asUtc(parsed); // true UTC publication — expected case
    }

    if (tzid != null && tzid.toUpperCase().contains('ISTANBUL')) {
      _convertedTimestampCount++;
      _warnOnce('ICS uses TZID=$tzid instead of UTC "Z" timestamps. '
          'Converted assuming permanent UTC+3 (Türkiye).');
      return asUtc(
          parsed.subtract(const Duration(minutes: _istanbulOffsetMinutes)));
    }

    _ambiguousTimestampCount++;
    _warnOnce(tzid == null
        ? 'ICS timestamp "$trimmed" lacks the UTC "Z" suffix (floating '
            'local time). Treating the wall clock as UTC — verify the export!'
        : 'ICS uses unsupported TZID=$tzid. Treating the wall clock as UTC!');
    return asUtc(parsed);
  }

  /// Convert ICS event to the string format expected by existing Logic
  List<String> _formatEventForCompatibility(Map<String, dynamic> event) {
    final summary = (event['summary'] ?? '').toString();
    final dtStart = _parseIcsDate(event['dtstart']);
    final dtEnd = _parseIcsDate(event['dtend']);
    
    if (dtStart == null) return [summary];
    
    final startTime = DateFormat('HH:mm').format(dtStart);
    final endTime = dtEnd != null ? DateFormat('HH:mm').format(dtEnd) : '';
    
    // Normalize escaped newlines in the description
    final description = (event['description'] ?? '')
        .toString()
        .replaceAll('\\n', '\n')
        .replaceAll('\\N', '\n')
        .replaceAll('\\r', '');
    
    var output = <String>[];
    
    // 1. Detect Type
    if (summary.contains('Report') || summary.contains('Check-in') || summary.contains('BRIEFING')) {
       output.add('Report $startTime');
       output.addAll(_parseDetailLines(description));
    } else if (summary.contains('Release') || summary.contains('Debrief')) {
       output.add('Release $startTime');
    } else if (summary.contains('OFF')) {
       output.add('OFF');
    } else if (summary.toUpperCase().contains('SB') || summary.toUpperCase().contains('STANDBY')) {
        // "SB1" or "Standby" or "STANDBY"
        // Generate: "SB1 AYT 00:00 ~ 10:00"
        String code = 'SB1'; // Default
        // The standby code (SB1/SB2/SB3) can appear in the summary or in the
        // description (e.g. the "CCMSB3" token in the Standby detail line).
        if (summary.toUpperCase().contains('SB2')) code = 'SB2';
        if (summary.toUpperCase().contains('SB3')) code = 'SB3';
        if (code == 'SB1') {
          final sbMatch = RegExp(r'SB([123])').firstMatch(description.toUpperCase());
          if (sbMatch != null) code = 'SB${sbMatch.group(1)}';
        }
        
        // Try to construct standard standby string
        output.add('$code AYT $startTime ~ $endTime AYT'); 
        // Append any detail lines (check-in/release times)
        output.addAll(_parseDetailLines(description));
    } else if (summary.contains('FLY') || summary.contains('XQ') || summary.contains('TK') || summary.contains('Flight')) {
        // Flight Event — fully parse description (including multi-day layovers)
        output.addAll(_parseFlyEvent(description, startTime, endTime, summary));
    } else {
        // Generic event
        output.add('$summary $startTime - $endTime');
        output.addAll(_parseDetailLines(description));
    }
    
    print('[DEBUG] _formatEventForCompatibility: summary="$summary" start=$startTime end=$endTime '
        'description="$description" => ${output.length} events');
    return output;
  }

  /// Parse generic detail lines from a description, filtering out calendar
  /// metadata noise (date headers, addresses, phone numbers, labels).
  List<String> _parseDetailLines(String description) {
    if (description.isEmpty) return [];
    final lines = description.split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final output = <String>[];
    final dateHeaderRegex = RegExp(r'^\w{3},?\s+\d{1,2}\s+\w{3}\s+\d{4}');
    final ignorePrefixes = [
      'Address', 'Phone', 'Duty', 'From', 'To', 'Date', 'Desig',
      'Standby', 'Stand-by', 'RC', 'AC', 'Block', 'Airport', 'Hotel',
    ];
    for (final line in lines) {
      if (dateHeaderRegex.hasMatch(line)) continue;
      final lower = line.toLowerCase();
      if (ignorePrefixes.any((p) => lower.startsWith(p.toLowerCase()))) continue;
      // Keep only lines that look meaningful (contain a colon or time or code)
      if (line.contains(':') || RegExp(r'\d{2}:\d{2}').hasMatch(line) || RegExp(r'^[A-Z0-9]{2,}').hasMatch(line)) {
        output.add(line);
      }
    }
    return output;
  }

  /// Parse a FLY event description. Handles both simple single-day returns
  /// and multi-day layover pairings where the hotel, transport and all legs
  /// are embedded in a single event's DESCRIPTION.
  ///
  /// Recognized line patterns:
  ///   - `Check-in HH:MM` / `Report HH:MM` / `Briefing HH:MM`
  ///   - `570 02:53 06:44 AYT - CPH`  (flight leg)
  ///   - `Release HH:MM   EZS`         (ends operations; EZS = layover port)
  ///   - `Transport HH:MM HH:MM COMPANY`
  ///   - `Hotel HH:MM HH:MM HOTELNAME` (followed by Address:/Phone: lines)
  List<String> _parseFlyEvent(String description, String startTime, String endTime, String summary) {
    final output = <String>[];
    final lines = description.split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    print('[DEBUG] _parseFlyEvent: START summary=$summary start=$startTime end=$endTime '
        'descriptionLines=${lines.length}');

    // Multiple date headers (e.g. "Mon, 20 Jul 2026" and "Wed, 22 Jul 2026")
    // indicate a multi-day pairing.
    final dateHeaderRegex = RegExp(r'^\w{3},?\s+\d{1,2}\s+\w{3}\s+\d{4}');
    final dateHeaders = lines.where((l) => dateHeaderRegex.hasMatch(l)).toList();
    final isMultiDay = dateHeaders.length > 1;
    if (isMultiDay) {
      output.add('📅 Multi-day pairing');
    }

    // Regexes for recognised line types
    final flightRegex = RegExp(
      r'(?:([A-Z]{2})\s+)?(\d{3,4})\s+(\d{2}:\d{2})\s+(\d{2}:\d{2})\s+([A-Z]{3})\s*-\s*([A-Z]{3})'
    );
    final checkInRegex = RegExp(r'(?:Check-in|Report|Briefing)\s*:?\s*(\d{2}:\d{2})', caseSensitive: false);
    // Tolerate zero or more spaces between "Release" and the time, e.g.
    // "Release01:28" (no space) or "Release 01:28" (with space).
    final releaseRegex = RegExp(r'Release\s*(\d{2}:\d{2})', caseSensitive: false);
    final transportRegex = RegExp(r'Transport\s+(\d{2}:\d{2})\s+(\d{2}:\d{2})', caseSensitive: false);
    final hotelRegex = RegExp(r'Hotel\s+(\d{2}:\d{2})\s+(\d{2}:\d{2})\s*(.*)', caseSensitive: false);
    final ignorePrefixes = [
      'Address', 'Phone', 'Duty', 'From', 'To', 'Date', 'Desig',
      'Standby', 'Stand-by', 'RC', 'AC', 'Block', 'Airport',
    ];

    for (final line in lines) {
      // Skip date headers and metadata noise
      if (dateHeaderRegex.hasMatch(line)) continue;
      final lower = line.toLowerCase();
      if (ignorePrefixes.any((p) => lower.startsWith(p.toLowerCase()))) continue;

      // Check-in / Report
      final checkInMatch = checkInRegex.firstMatch(line);
      if (checkInMatch != null) {
        final t = checkInMatch.group(1)!;
        print('[DEBUG] _parseFlyEvent: line="$line" => CHECKIN $t');
        output.add('Report $t');
        continue;
      }

      // Release (with optional layover airport code)
      final releaseMatch = releaseRegex.firstMatch(line);
      if (releaseMatch != null) {
        final releaseTime = releaseMatch.group(1)!;
        String releaseStr = 'Release $releaseTime';
        final cityMatch = RegExp(r'Release\s*\d{2}:\d{2}\s+([A-Z]{3})').firstMatch(line);
        if (cityMatch != null) {
          final city = cityMatch.group(1)!;
          releaseStr += ' $city';
          // Only treat as a layover if it's not the home base (AYT)
          if (city != 'AYT') {
            output.add('🏨 Layover: $city');
          }
        }
        print('[DEBUG] _parseFlyEvent: line="$line" => RELEASE $releaseTime');
        output.add(releaseStr);
        continue;
      }

      // Transport
      final transportMatch = transportRegex.firstMatch(line);
      if (transportMatch != null) {
        print('[DEBUG] _parseFlyEvent: line="$line" => TRANSPORT');
        output.add('🚌 Transport ${transportMatch.group(1)} ~ ${transportMatch.group(2)}');
        continue;
      }

      // Hotel
      final hotelMatch = hotelRegex.firstMatch(line);
      if (hotelMatch != null) {
        final hotelName = hotelMatch.group(3)?.trim() ?? '';
        print('[DEBUG] _parseFlyEvent: line="$line" => HOTEL $hotelName');
        output.add('🏨 Hotel: $hotelName');
        continue;
      }

      // Flight leg
      final flightMatch = flightRegex.firstMatch(line);
      if (flightMatch != null) {
        final airline = flightMatch.group(1) ?? 'XQ';
        final flt = flightMatch.group(2)!;
        final dep = flightMatch.group(3)!;
        final arr = flightMatch.group(4)!;
        final fromAir = flightMatch.group(5)!;
        final toAir = flightMatch.group(6)!;
        print('[DEBUG] _parseFlyEvent: line="$line" => FLIGHT $airline$flt $dep~$arr $fromAir-$toAir');
        output.add('$airline$flt $dep ~ $arr $fromAir-$toAir');
        continue;
      }

      // Fallback: keep short codes that look like flight numbers/notes
      if (line.length <= 20 && !line.contains(':')) {
        final codeMatch = RegExp(r'^[A-Z0-9]{4,}(?:\s|$)').firstMatch(line);
        if (codeMatch != null) {
          output.add(line);
        }
      }
    }

    // Ensure flight work is wrapped with Report / Release if not present
    final hasFlights = output.any((e) => e.contains('~') && e.contains('-'));
    if (hasFlights) {
      final hasReport = output.any((e) => e.startsWith('Report'));
      final hasRelease = output.any((e) => e.startsWith('Release'));
      if (!hasReport) {
        print('[DEBUG] _parseFlyEvent: no Report found, inserting Report $startTime');
        output.insert(0, 'Report $startTime');
      }
      if (!hasRelease) {
        print('[DEBUG] _parseFlyEvent: no Release found, appending Release $endTime');
        output.add('Release $endTime');
      }
    }

    // Fallback if nothing structured was parsed (old-format safety)
    if (output.isEmpty) {
      final flightNumRegex = RegExp(r'([A-Z]{2}\d+)');
      final m = flightNumRegex.firstMatch(summary);
      final flightNum = m?.group(1) ?? summary;
      output.add('$flightNum $startTime ~ $endTime $summary');
      if (endTime.isNotEmpty) {
        output.add('Release $endTime');
      }
    }

    print('[DEBUG] _parseFlyEvent: DONE output=$output');
    return output;
  }

  /// Extract layover events from a parsed schedule.
  ///
  /// Detects layovers embedded within multi-day FLY events by scanning for the
  /// `🏨 Layover: XXX` marker added during parsing. Each multi-day pairing
  /// contributes one layover.
  List<Map<String, dynamic>> extractLayoversFromSchedule(List<ScheduleDay> schedule) {
    final layovers = <Map<String, dynamic>>[];
    for (final day in schedule) {
      for (final event in day.events) {
        final match = RegExp(r'🏨 Layover: ([A-Z]{3})').firstMatch(event);
        if (match != null) {
          final city = match.group(1)!;
          layovers.add({
            'date': day.date.toIso8601String(),
            'cityCode': city,
            'description': 'Layover in $city',
          });
        }
      }
    }
    return layovers;
  }

  // Istanbul timezone offset from UTC (Turkey = UTC+3)
  static const int _istanbulUtcOffsetMinutes = 3 * 60;

  /// Convert a UTC time string (e.g. "02:00") to Istanbul local time string.
  String _utcToLocal(String utcTime) {
    final mins = _timeToMinutes(utcTime) + _istanbulUtcOffsetMinutes;
    final wrappedMins = mins % (24 * 60);
    final h = wrappedMins ~/ 60;
    final m = wrappedMins % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// Check if an airport code is a Turkish (domestic) airport.
  bool _isDomesticAirport(String code) => isTurkishAirport(code);

  /// Determine the layover count using combined rules:
  ///
  /// 1. **Airport rule**: A layover occurs when the final flight leg's arrival
  ///    airport is NOT the crew's home base. A turnaround (returns to base)
  ///    ends the layover.
  ///
  /// 2. **Time rule (base → layover)**: Based on the local reporting/check-in time:
  ///    - ≤ 13:00 local → 1.0
  ///    - 13:01–20:00 local → 0.5
  ///    - ≥ 20:01 local → 0
  ///
  /// 3. **Time rule (off-base → home)**: Based on the local release/post-duty
  ///    end time:
  ///    - ≤ 11:59 local → 0
  ///    - 12:00–18:59 local → 0.5
  ///    - ≥ 19:00 local → 1
  ///
  /// 4. **Continuity rule**: A day with no flights (OFF/standby day) in between
  ///    duty days does NOT reset the layover streak — the previous day's layover
  ///    status carries forward without adding additional count.
  ///
  /// The daily contribution is the maximum of the airport rule (0 or 1) and the
  /// combined time rule (0, 0.5, or 1). The total is summed across all duty days.
  ///
  /// Returns a map with:
  ///  - `total`: double layover count (sum of daily contributions)
  ///  - `international`: count of layover days at non-Turkish airports
  ///  - `domestic`: count of layover days at Turkish but non-home-base airports
  Map<String, dynamic> computeLayoverCount(
    List<ScheduleDay> schedule,
    String homeBase,
  ) {
    double totalLayovers = 0.0;
    int internationalLayovers = 0;
    int domesticLayovers = 0;
    bool currentlyInLayover = false; // tracks continuity across days off

    final homeBaseUpper = homeBase.toUpperCase();

    print('[DEBUG] computeLayoverCount: START homeBase=$homeBase totalDays=${schedule.length}');

    for (final day in schedule) {
      final events = day.events;

      // Extract flight legs from this day's events
      // Event format: "XQ570 02:53 ~ 06:44 AYT-CPH"
      final flightLegs = <String>[];
      for (final event in events) {
        final m = RegExp(
          r'([A-Z]{2}\d+)\s+(\d{2}:\d{2})\s*~\s*(\d{2}:\d{2})\s+([A-Z]{3})-([A-Z]{3})',
        ).firstMatch(event);
        if (m != null) {
          flightLegs.add('${m.group(4)}-${m.group(5)}');
        }
      }

      // Extract report time
      String? reportTime;
      for (final event in events) {
        if (event.contains('Report') || event.contains('Check-in') || event.contains('Briefing')) {
          final m = RegExp(r'(\d{1,2}:\d{2})').firstMatch(event);
          if (m != null) {
            reportTime = m.group(1);
            break;
          }
        }
      }

      // Extract release time — use the LAST Release line of the day: split
      // pairings legitimately carry an intermediate release (e.g. 00:14 at
      // the layover station) plus the final release back at base, and the
      // return-day rule must apply to the final one.
      String? releaseTime;
      for (final event in events) {
        if (event.contains('Release')) {
          final m = RegExp(r'(\d{1,2}:\d{2})').firstMatch(event);
          if (m != null) {
            releaseTime = m.group(1);
          }
        }
      }

      final hasFlights = flightLegs.isNotEmpty;

      // --- Continuity rule: day with no flights in between ---
      // "if there is a day in between with no duties it counts as 1 layover"
      if (!hasFlights) {
        // A pairing can position crew to the layover station by ground
        // transport (e.g. "Travel ... AYT - KZR"), so the day carries no
        // flight legs but still has an explicit layover marker or hotel.
        final joined = events.join(' ');
        final layoverMatch =
            RegExp(r'Layover:\s*([A-Z]{3})').firstMatch(joined);
        final hasHotel = events.any((e) => e.contains('Hotel:'));
        // Ground-positioned days can also surface as a raw
        // "Release HH:MM XXX" detail line when the positioning sector is
        // published as a TRAVEL event (parsed by the generic branch, which
        // emits no Layover marker), e.g. "TRAVEL (AYT-KZR)".
        final awayReleaseAirport = RegExp(r'Release\s*\d{1,2}:\d{2}\s+([A-Z]{3})')
            .allMatches(joined)
            .map((m) => m.group(1)!.toUpperCase())
            .firstWhere((c) => c != homeBaseUpper, orElse: () => '');
        final layoverAirport = (layoverMatch?.group(1) ?? awayReleaseAirport)
            .toUpperCase();
        if (layoverAirport.isNotEmpty &&
            layoverAirport != homeBaseUpper) {
          currentlyInLayover = true;
          totalLayovers += 1.0;
          if (_isDomesticAirport(layoverAirport)) {
            domesticLayovers++;
          } else {
            internationalLayovers++;
          }
          print('[DEBUG] computeLayoverCount: day=${day.date} no flight legs '
              'but ground-positioned layover at $layoverAirport '
              '→ +1.0 total=$totalLayovers');
        } else if (hasHotel && currentlyInLayover) {
          totalLayovers += 1.0;
          print('[DEBUG] computeLayoverCount: day=${day.date} no flight legs, '
              'hotel day inside layover streak → +1.0 total=$totalLayovers');
        } else if (currentlyInLayover) {
          // A day off while in a layover streak still counts as 1 layover
          totalLayovers += 1.0;
          print('[DEBUG] computeLayoverCount: day=${day.date} no flights '
              'but in layover streak → +1.0 (continuity) total=$totalLayovers');
        }
        continue;
      }

      // --- Determine direction: outbound vs return vs turnaround ---
      final lastLeg = flightLegs.last;
      final arrivalAirport = lastLeg.split('-').last.toUpperCase();
      final isDomesticArrival = _isDomesticAirport(arrivalAirport);
      final isTurnaround = arrivalAirport == homeBaseUpper;
      final isReturning = isTurnaround && currentlyInLayover;
      final isOutbound = !isTurnaround;

      // --- Rule 1: Airport cross-reference (both methods are valid) ---
      // Airport rule detects IF a layover exists and classifies domestic/international
      int airportContribution = 0;
      if (isOutbound) {
        airportContribution = 1;
        currentlyInLayover = true;
        if (isDomesticArrival) {
          domesticLayovers++;
        } else {
          internationalLayovers++;
        }
      } else if (isReturning) {
        // Crew returning to home base — layover ends
        currentlyInLayover = false;
      }

      // --- Rule 2: Time rule for base → layover (report time) ---
      // ≤ 13:00 local → 1.0, 13:01–20:00 local → 0.5, ≥ 20:01 local → 0
      double reportContribution = 0.0;
      if (reportTime != null) {
        final localReport = _utcToLocal(reportTime);
        final reportMinutesLocal = _timeToMinutes(localReport);

        if (reportMinutesLocal <= 13 * 60 + 59) {
          reportContribution = 1.0; // ≤ 13:00
        } else if (reportMinutesLocal <= 20 * 60) {
          reportContribution = 0.5; // 13:01–20:00
        }
        // ≥ 20:01 → 0 (default)
      }

      // --- Rule 3: Time rule for off-base → home (release time) ---
      // ≤ 11:59 local → 0, 12:00–18:59 local → 0.5, ≥ 19:00 local → 1
      double releaseContribution = 0.0;
      if (releaseTime != null) {
        final localRelease = _utcToLocal(releaseTime);
        final releaseMinutesLocal = _timeToMinutes(localRelease);

        if (releaseMinutesLocal <= 11 * 60 + 59) {
          releaseContribution = 0.0; // ≤ 11:59
        } else if (releaseMinutesLocal <= 18 * 60 + 59) {
          releaseContribution = 0.5; // 12:00–18:59
        } else {
          releaseContribution = 1.0; // ≥ 19:00
        }
      }

      // --- Rule 4: Continuity (day off) — handled above ---

      // --- Combine all rules (both methods are valid) ---
      // Outbound days: apply report time rule (from base → layover)
      //   combined with airport rule (both valid → take higher value)
      // Return days: apply release time rule (off-base → home)
      //   combined with airport rule (arrival == base → 0 from airport)
      // Turnaround days: 0
      double dailyContribution;
      if (isOutbound) {
        // Base → layover: both methods are valid, take max
        dailyContribution = math.max(
          airportContribution.toDouble(),
          reportContribution,
        );
      } else if (isReturning) {
        // Off-base → home: release time rule; airport = 0
        dailyContribution = math.max(
          0.0,
          releaseContribution,
        );
        // When the rest/hotel period falls on the SAME calendar day as the
        // return duty (pairing hotel tail merged with the return, e.g. rest
        // at the layover station then a late-evening check-in), the day
        // represents both the rest day and the return — credit the rest half
        // as well, capped at one layover day per calendar day.
        final hasRestMarker = events
            .any((e) => e.contains('Hotel:') || e.contains('Layover:'));
        if (hasRestMarker) {
          dailyContribution = math.min(1.0, dailyContribution + 0.5);
          print('[DEBUG] computeLayoverCount: day=${day.date} return day '
              'also carries the hotel/rest period → +0.5 '
              'daily=$dailyContribution');
        }
      } else {
        // Turnaround (home → home) or return without prior layover: 0
        dailyContribution = 0.0;
      }

      totalLayovers += dailyContribution;

      print('[DEBUG] computeLayoverCount: day=${day.date} arrival=$arrivalAirport '
          'isOutbound=$isOutbound isReturning=$isReturning '
          'report=$reportTime(→$reportContribution) '
          'release=$releaseTime(→$releaseContribution) '
          'airport=$airportContribution daily=$dailyContribution total=$totalLayovers');
    }

    print('[DEBUG] computeLayoverCount: DONE total=$totalLayovers '
        'international=$internationalLayovers domestic=$domesticLayovers');

    return {
      'total': totalLayovers,
      'international': internationalLayovers,
      'domestic': domesticLayovers,
    };
  }
}
