import 'package:logging/logging.dart';
import '../models/layover_event.dart';

class LayoverService {
  static final _logger = Logger('LayoverService');

  /// Crew home base (IATA). A duty that releases here ends with the crew
  /// going home, which must NOT be treated as a layover (no hotel, no
  /// transport, no allowance). Fixes phantom layovers on same-day round
  /// trips such as AYT-BTS-AYT followed by another AYT duty.
  static const String homeBase = 'AYT';

  /// Parse layover events from ICS roster data
  static List<LayoverEvent> parseLayoversFromICSData(
    String icsString,
    String userId,
  ) {
    try {
      // This would typically parse the ICS data, but for now we'll work with the processed events
      // In your existing roster parsing logic, you would call this after parsing the ICS
      return [];
    } catch (e) {
      _logger.severe('Error parsing layovers from ICS data: $e');
      return [];
    }
  }

  /// Extract layover events embedded inside a single FLY event description.
  /// This handles the NEW CrewAccess format where multi-day pairings are
  /// packed into one VEVENT (no separate NON-FLY events).
  ///
  /// Parses patterns like:
  ///   Release     00:14               EZS
  ///   Transport   ...
  ///   Hotel       00:34  23:10        ELAZIG PARK DEDEMAN HOTEL
  ///   ...
  ///   Check-in    23:30               EZS
  static List<LayoverEvent> extractLayoversFromSingleFlyEvent(
    Map<String, dynamic> event,
    String userId,
  ) {
    final List<LayoverEvent> layovers = [];

    try {
      final summary = event['summary'] as String? ?? '';
      if (!summary.startsWith('FLY')) return layovers;

      final rawDesc = event['description'] as String? ?? '';
      // Unescape the description exactly as the rest of the app does
      final description = rawDesc.replaceAll('\\n', '\n');
      final lines = description.split('\n');

      // We'll scan line by line collecting "segments" separated by date headers
      // A date header looks like: "Mon, 20 Jul 2026" or similar
      final dateHeaderRegex = RegExp(
        r'^(Mon|Tue|Wed|Thu|Fri|Sat|Sun),\s+\d+\s+\w+\s+\d{4}',
        caseSensitive: false,
      );
      final releaseRegex = RegExp(r'^Release\s+(\d{2}:\d{2})\s+(\w{3})');
      final checkinRegex = RegExp(r'^Check-in\s+(\d{2}:\d{2})\s+(\w{3})');
      final hotelRegex = RegExp(
        r'^Hotel\s+(\d{2}:\d{2})\s+(\d{2}:\d{2})\s+(.+)',
      );
      final transportRegex = RegExp(
        r'^Transport\s+(\d{2}:\d{2})\s+(\d{2}:\d{2})\s+(.+)',
      );

      // Collect segments per date (list of line groups)
      final List<Map<String, dynamic>> segments = [];
      Map<String, dynamic>? currentSegment;
      DateTime? currentSegmentDate;

      // We need the event base date to anchor times
      final baseDate = _extractEventDateTime(event);

      // Track which "day offset" we're on as we pass date headers
      int dayOffset = 0;
      DateTime? firstDateSeen;

      for (final rawLine in lines) {
        final trimmed = rawLine.trim();
        if (trimmed.isEmpty || trimmed.startsWith('- - -')) continue;

        // Detect date header → start new segment
        if (dateHeaderRegex.hasMatch(trimmed)) {
          if (currentSegment != null) {
            segments.add(currentSegment!);
          }
          // Try to parse the actual date from the header
          try {
            // e.g. "Mon, 20 Jul 2026"
            final dateParts = trimmed
                .replaceAll(',', '')
                .split(RegExp(r'\s+'));
            // dateParts: [Mon, 20, Jul, 2026]
            final monthMap = {
              'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
              'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
            };
            if (dateParts.length >= 4) {
              final day = int.tryParse(dateParts[1]);
              final month = monthMap[dateParts[2]];
              final year = int.tryParse(dateParts[3]);
              if (day != null && month != null && year != null) {
                currentSegmentDate = DateTime.utc(year, month, day);
                if (firstDateSeen == null) {
                  firstDateSeen = currentSegmentDate;
                  dayOffset = 0;
                } else {
                  dayOffset = currentSegmentDate!
                      .difference(firstDateSeen!)
                      .inDays;
                }
              }
            }
          } catch (_) {}
          currentSegment = {
            'date': currentSegmentDate ?? baseDate.add(Duration(days: dayOffset)),
            'dayOffset': dayOffset,
            'lines': <String>[],
          };
          continue;
        }

        if (currentSegment != null) {
          (currentSegment!['lines'] as List<String>).add(trimmed);
        }
      }
      if (currentSegment != null) segments.add(currentSegment!);

      // Only meaningful if we have 2+ date segments (multi-day pairing)
      if (segments.length < 2) return layovers;

      // Walk segments looking for Release (end of outbound) → hotel → Check-in (next day)
      // We look at each segment for a "Release" that ends away from base,
      // and the next segment that has a "Check-in" (return leg start)
      String? releaseTimeStr;
      String? releaseAirport;
      DateTime? releaseDateUtc;
      String? hotelName;
      String? hotelAddress;
      String? hotelPhone;
      String? checkinTimeStr;
      String? checkinAirport;
      DateTime? checkinDateUtc;

      for (int si = 0; si < segments.length; si++) {
        final seg = segments[si];
        final segDate = seg['date'] as DateTime;
        final segLines = seg['lines'] as List<String>;

        for (final line in segLines) {
          // Look for Release away from base airport (layover location)
          final rMatch = releaseRegex.firstMatch(line);
          if (rMatch != null && releaseTimeStr == null) {
            final airport = rMatch.group(2)!.trim().toUpperCase();
            // Only count as a layover release if the airport is NOT the base.
            // Heuristic 1: if the event LOCATION field == airport, it's a
            // home-base return. Heuristic 2: the LOCATION field is often
            // empty in real ICS data, so also compare with [homeBase].
            final eventLocation =
                (event['location'] as String? ?? '').toUpperCase().trim();
            if (airport != eventLocation && airport != homeBase) {
              releaseTimeStr = rMatch.group(1);
              releaseAirport = airport;
              final timeParts = releaseTimeStr!.split(':');
              releaseDateUtc = DateTime.utc(
                segDate.year,
                segDate.month,
                segDate.day,
                int.parse(timeParts[0]),
                int.parse(timeParts[1]),
              );
              _logger.info(
                  '🛬 Found release at $releaseAirport @ $releaseTimeStr on $segDate');
            }
          }

          // Look for hotel info (occurs after release)
          if (releaseTimeStr != null && hotelName == null) {
            final hMatch = hotelRegex.firstMatch(line);
            if (hMatch != null) {
              hotelName = hMatch.group(3)!.trim();
              _logger.info('🏨 Hotel: $hotelName');
            }
            if (line.startsWith('Address:')) {
              hotelAddress = line.substring(8).trim();
            }
            if (line.startsWith('N/A | Phone:') || line.startsWith('Phone:')) {
              final phoneMatch =
                  RegExp(r'Phone:\s*([+\d\s\(\)-]+)').firstMatch(line);
              if (phoneMatch != null && hotelPhone == null) {
                hotelPhone = phoneMatch.group(1)!.trim();
              }
            }
          }

          // Look for Check-in at the layover airport (confirms it's a real layover)
          if (releaseTimeStr != null && checkinTimeStr == null) {
            final cMatch = checkinRegex.firstMatch(line);
            if (cMatch != null) {
              final airport = cMatch.group(2)!.trim().toUpperCase();
              if (airport == releaseAirport) {
                checkinTimeStr = cMatch.group(1);
                checkinAirport = airport;
                final timeParts = checkinTimeStr!.split(':');
                checkinDateUtc = DateTime.utc(
                  segDate.year,
                  segDate.month,
                  segDate.day,
                  int.parse(timeParts[0]),
                  int.parse(timeParts[1]),
                );
                // If checkin time < release time on same day, it's actually the next day
                if (checkinDateUtc!.isBefore(releaseDateUtc!)) {
                  checkinDateUtc =
                      checkinDateUtc!.add(const Duration(days: 1));
                }
                _logger.info(
                    '🛫 Found check-in at $checkinAirport @ $checkinTimeStr on $segDate');
              }
            }
          }
        }
      }

      // If we found a release+checkin pair, create a LayoverEvent
      if (releaseTimeStr != null &&
          checkinTimeStr != null &&
          releaseDateUtc != null &&
          checkinDateUtc != null &&
          releaseAirport != null) {
        final duration = checkinDateUtc!.difference(releaseDateUtc!);
        if (duration.inMinutes >= 30) {
          final layover = LayoverEvent.createFromTimes(
            id: 'layover_embedded_${event['uid']}',
            checkOutTime: releaseDateUtc!,
            reportingTime: checkinDateUtc!,
            isInternational: _isInternationalLocation(releaseAirport!),
            location: releaseAirport!,
            userId: userId,
          );
          layovers.add(layover);
          _logger.info(
              '✅ Created embedded layover at $releaseAirport, duration: ${duration.inHours}h');
        }
      }
    } catch (e, st) {
      _logger.warning('Error extracting embedded layover: $e\n$st');
    }

    return layovers;
  }

  /// Extract layover location from FLY event description (new CrewAccess format).
  /// Looks for the airport code on the Release line, e.g. "Release     00:14               EZS"
  static String? extractLayoverLocationFromDescription(
      Map<String, dynamic> event) {
    try {
      final rawDesc = event['description'] as String? ?? '';
      final description = rawDesc.replaceAll('\\n', '\n');
      final eventLocation =
          (event['location'] as String? ?? '').toUpperCase().trim();
      final lines = description.split('\n');
      final releaseRegex = RegExp(r'^Release\s+\d{2}:\d{2}\s+(\w{3})');
      for (final rawLine in lines) {
        final trimmed = rawLine.trim();
        final m = releaseRegex.firstMatch(trimmed);
        if (m != null) {
          final airport = m.group(1)!.trim().toUpperCase();
          if (airport != eventLocation) {
            return airport;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Extract layover events from parsed calendar events
  static List<LayoverEvent> extractLayoversFromEvents(
    List<Map<String, dynamic>> events,
    String userId,
  ) {
    try {
      _logger.info('🔍 Starting layover extraction from ${events.length} events');
      
      // Group events by UID to handle multi-part events (like FLY + NON-FLY + FLY sequences)
      final eventGroups = <String, List<Map<String, dynamic>>>{};
      
      for (final event in events) {
        final uid = event['uid'] as String? ?? '';
        final summary = (event['summary'] as String? ?? '');
        
        // Only process FLY, STANDBY, and NON-FLY events
        if (summary.startsWith('FLY') || 
            summary.startsWith('STANDBY') || 
            summary.startsWith('NON-FLY')) {
          
          // Extract base UID (remove the -1, -2, -3 suffix for multi-part events)
          final baseUid = uid.contains('-') ? uid.split('-')[0] : uid;
          
          if (eventGroups[baseUid] == null) {
            eventGroups[baseUid] = [];
          }
          eventGroups[baseUid]!.add(event);
          _logger.info('📋 Added to group $baseUid: $summary ($uid)');
        }
      }

      _logger.info('📊 Found ${eventGroups.length} event groups');
      for (final entry in eventGroups.entries) {
        _logger.info('   Group ${entry.key}: ${entry.value.length} events');
        for (final event in entry.value) {
          _logger.info('     - ${event['summary']} (${event['uid']})');
        }
      }

      final layovers = <LayoverEvent>[];

      // Process each event group to find layovers
      for (final group in eventGroups.values) {
        if (group.length >= 2) {
          // Sort events within group by start time
          group.sort((a, b) {
            final aTime = _extractEventDateTime(a);
            final bTime = _extractEventDateTime(b);
            return aTime.compareTo(bTime);
          });

          // Look for FLY -> NON-FLY -> FLY patterns or similar layover sequences
          final layover = _extractLayoverFromEventGroup(group, userId);
          if (layover != null) {
            layovers.add(layover);
            _logger.info('✅ Created layover from event group: ${layover.toString()}');
          } else {
            _logger.warning('❌ No layover created from group with ${group.length} events');
          }
        } else {
          _logger.info('⚠️ Skipping group with only ${group.length} events');
        }
      }

      // Also check for layovers between separate duty events (original logic)
      final dutyEvents = events.where((event) {
        final summary = (event['summary'] as String? ?? '');
        return summary.startsWith('FLY') || summary.startsWith('STANDBY');
      }).toList();

      _logger.info('🔍 Checking layovers between ${dutyEvents.length} duty events');

      // Sort events by date/time
      dutyEvents.sort((a, b) {
        final aTime = _extractEventDateTime(a);
        final bTime = _extractEventDateTime(b);
        return aTime.compareTo(bTime);
      });

      for (int i = 0; i < dutyEvents.length - 1; i++) {
        final currentEvent = dutyEvents[i];
        final nextEvent = dutyEvents[i + 1];

        // Skip if these events are part of the same multi-part event
        final currentUid = (currentEvent['uid'] as String? ?? '').split('-')[0];
        final nextUid = (nextEvent['uid'] as String? ?? '').split('-')[0];
        
        _logger.info('🔗 Checking between ${currentEvent['summary']} ($currentUid) and ${nextEvent['summary']} ($nextUid)');
        
        if (currentUid != nextUid) {
          final layover = _createLayoverBetweenEvents(
            currentEvent,
            nextEvent,
            userId,
            '$i-${i + 1}',
          );

          if (layover != null) {
            layovers.add(layover);
            _logger.info('✅ Created layover between separate events: ${layover.toString()}');
          } else {
            _logger.info('❌ No layover created between separate events');
          }
        } else {
          _logger.info('⏭️ Skipping - same multi-part event');
        }
      }

      _logger.info('🏁 Phase 1+2 layover extraction: ${layovers.length} layovers found');

      // ── Phase 3: New CrewAccess format ─────────────────────────────────────
      // Scan every FLY event for layover data embedded inside its description.
      // This handles the case where a multi-day pairing is a single VEVENT.
      final existingLayoverIds = layovers.map((l) => l.id).toSet();
      for (final event in events) {
        final summary = (event['summary'] as String? ?? '');
        if (!summary.startsWith('FLY')) continue;
        final embeddedLayovers =
            extractLayoversFromSingleFlyEvent(event, userId);
        for (final el in embeddedLayovers) {
          if (!existingLayoverIds.contains(el.id)) {
            layovers.add(el);
            existingLayoverIds.add(el.id);
            _logger.info(
                '✅ Phase 3 embedded layover added: ${el.location}');
          }
        }
      }

      _logger.info('🏁 Layover extraction completed: ${layovers.length} layovers found');
      return layovers;

    } catch (e, stackTrace) {
      _logger.severe('❌ Error extracting layovers from events: $e');
      _logger.severe('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Extract layover from a multi-part event group (e.g., FLY -> NON-FLY -> FLY)
  static LayoverEvent? _extractLayoverFromEventGroup(
    List<Map<String, dynamic>> eventGroup,
    String userId,
  ) {
    try {
      _logger.info('🔍 Analyzing event group with ${eventGroup.length} events:');
      for (final event in eventGroup) {
        _logger.info('   - ${event['summary']} (${event['uid']})');
      }
      
      // Look for patterns like: FLY -> NON-FLY -> FLY or similar
      Map<String, dynamic>? firstFlyEvent;
      Map<String, dynamic>? nonFlyEvent;
      Map<String, dynamic>? lastFlyEvent;

      for (final event in eventGroup) {
        final summary = (event['summary'] as String? ?? '');
        
        if (summary.startsWith('FLY') && firstFlyEvent == null) {
          firstFlyEvent = event;
          _logger.info('   ✈️ First FLY event: $summary');
        } else if (summary.startsWith('NON-FLY')) {
          nonFlyEvent = event;
          _logger.info('   🏨 NON-FLY event: $summary');
        } else if (summary.startsWith('FLY') && firstFlyEvent != null) {
          lastFlyEvent = event;
          _logger.info('   ✈️ Last FLY event: $summary');
        }
      }

      _logger.info('📊 Pattern analysis:');
      _logger.info('   First FLY: ${firstFlyEvent != null ? firstFlyEvent!['summary'] : 'null'}');
      _logger.info('   NON-FLY: ${nonFlyEvent != null ? nonFlyEvent!['summary'] : 'null'}');
      _logger.info('   Last FLY: ${lastFlyEvent != null ? lastFlyEvent!['summary'] : 'null'}');

      // If we have the pattern FLY -> NON-FLY -> FLY, create a layover
      if (firstFlyEvent != null && nonFlyEvent != null && lastFlyEvent != null) {
        _logger.info('✅ Found FLY -> NON-FLY -> FLY pattern, extracting times...');
        
        final firstReleaseTime = _extractReleaseTime(firstFlyEvent);
        final lastReportingTime = _extractReportingTime(lastFlyEvent);
        // For layovers, use the destination of the first flight or location from NON-FLY event
        final location = _extractLayoverLocation(firstFlyEvent, nonFlyEvent) ?? 
                        _extractDestinationLocation(firstFlyEvent) ?? 
                        _extractLocation(firstFlyEvent);

        _logger.info('🕒 Release time from first FLY: $firstReleaseTime');
        _logger.info('🕒 Reporting time for last FLY: $lastReportingTime');
        _logger.info('📍 Location: $location');

        // A first duty releasing at the home base means the crew went home;
        // do not create a layover for it.
        final firstReleaseAirport = _extractReleaseAirport(firstFlyEvent);
        if (firstReleaseAirport != null && firstReleaseAirport == homeBase) {
          _logger.info(
              'Skipping group layover: released at home base $homeBase');
          return null;
        }

        if (firstReleaseTime != null && lastReportingTime != null && location != null) {
          // Parse hotel information from NON-FLY event
          final hotelInfo = _extractHotelInfo(nonFlyEvent);
          _logger.info('🏨 Hotel info: ${hotelInfo['name']} at ${hotelInfo['address']}');
          
          final layover = LayoverEvent.createFromTimes(
            id: 'layover_${firstFlyEvent['uid']}_group',
            checkOutTime: firstReleaseTime,
            reportingTime: lastReportingTime,
            isInternational: _isInternationalLocation(location),
            location: location,
            userId: userId,
          );

          _logger.info('🎉 Successfully created layover: ${layover.toString()}');
          return layover;
        } else {
          _logger.warning('❌ Missing required times or location:');
          _logger.warning('   Release time: $firstReleaseTime');
          _logger.warning('   Reporting time: $lastReportingTime');
          _logger.warning('   Location: $location');
        }
      } else {
        _logger.warning('❌ Pattern not found for layover creation');
        if (firstFlyEvent == null) _logger.warning('   Missing first FLY event');
        if (nonFlyEvent == null) _logger.warning('   Missing NON-FLY event');
        if (lastFlyEvent == null) _logger.warning('   Missing last FLY event');
      }

      return null;
    } catch (e, stackTrace) {
      _logger.warning('❌ Error extracting layover from event group: $e');
      _logger.warning('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Extract hotel information from NON-FLY event
  static Map<String, String?> _extractHotelInfo(Map<String, dynamic> event) {
    try {
      final description = (event['description'] as String? ?? '').replaceAll('\\n', '\n');
      final lines = description.split('\n');
      
      String? hotelName;
      String? hotelAddress;
      
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('Hotel')) {
          // Extract hotel name: "Hotel       19:28  05:17        DIVAN HOTEL"
          final hotelMatch = RegExp(r'Hotel\s+\d{2}:\d{2}\s+\d{2}:\d{2}\s+(.+)').firstMatch(trimmed);
          if (hotelMatch != null) {
            hotelName = hotelMatch.group(1)!.trim();
          }
        } else if (trimmed.startsWith('Address:')) {
          hotelAddress = trimmed.substring(9).trim();
        }
      }

      return {
        'name': hotelName,
        'address': hotelAddress,
      };
    } catch (e) {
      _logger.warning('Error extracting hotel info: $e');
      return {'name': null, 'address': null};
    }
  }

  /// Create a layover event between two duty events
  static LayoverEvent? _createLayoverBetweenEvents(
    Map<String, dynamic> currentEvent,
    Map<String, dynamic> nextEvent,
    String userId,
    String idSuffix,
  ) {
    try {
      final currentReleaseTime = _extractReleaseTime(currentEvent);
      final nextReportingTime = _extractReportingTime(nextEvent);
      final currentReleaseAirport = _extractReleaseAirport(currentEvent);
      final nextLocation = _extractLocation(nextEvent);

      if (currentReleaseTime == null || nextReportingTime == null) {
        return null;
      }

      // A duty that releases at the home base means the crew went home —
      // that is NOT a layover (e.g. an AYT-BTS-AYT round trip followed by
      // another duty departing from AYT the next day).
      if (currentReleaseAirport != null && currentReleaseAirport == homeBase) {
        _logger.info('Skipping layover: released at home base $homeBase');
        return null;
      }

      // Prefer the airport where the duty actually ended (release station) —
      // that is where the crew stays overnight. Fall back to the next event's
      // summary location when the release line carries no airport code.
      final location = currentReleaseAirport ?? nextLocation;
      if (location == null) {
        return null;
      }

      // Check if there's enough time for a layover (more than 30 minutes)
      final timeDifference = nextReportingTime.difference(currentReleaseTime);
      if (timeDifference.inMinutes <= 30) {
        return null;
      }

      // Check if layover spans to next day (likely an actual layover)
      final layoverStartTime = currentReleaseTime.add(const Duration(minutes: 30));
      final isMinimumLayover = timeDifference.inHours >= 8; // Minimum rest time

      if (!isMinimumLayover) {
        _logger.info('Skipping short layover: ${timeDifference.inHours} hours');
        return null;
      }

      final layover = LayoverEvent.createFromTimes(
        id: 'layover_$idSuffix',
        checkOutTime: currentReleaseTime,
        reportingTime: nextReportingTime,
        isInternational: _isInternationalLocation(location),
        location: location,
        userId: userId,
      );

      return layover;
    } catch (e) {
      _logger.warning('Error creating layover between events: $e');
      return null;
    }
  }

  /// Extract event datetime from calendar event
  static DateTime _extractEventDateTime(Map<String, dynamic> event) {
    try {
      final dtstart = event['dtstart'];
      if (dtstart != null) {
        if (dtstart.dt is DateTime) {
          return dtstart.dt;
        } else if (dtstart.dt is String) {
          return DateTime.parse(dtstart.dt);
        }
      }
    } catch (e) {
      _logger.warning('Error extracting event datetime: $e');
    }
    return DateTime.now();
  }

  /// Extract release time from event description
  static DateTime? _extractReleaseTime(Map<String, dynamic> event) {
    try {
      final description = (event['description'] as String? ?? '').replaceAll('\\n', '\n');
      final lines = description.split('\n');

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('Release')) {
          final timeMatch = RegExp(r'Release\s*(\d{2}:\d{2})').firstMatch(trimmed);
          if (timeMatch != null) {
            final timeStr = timeMatch.group(1)!;
            final eventDate = _extractEventDateTime(event);
            return _parseTimeOnDate(timeStr, eventDate);
          }
        }
      }
    } catch (e) {
      _logger.warning('Error extracting release time: $e');
    }
    return null;
  }

  /// Extract the airport code from the Release line, e.g. "Release 00:14 EZS"
  /// returns EZS. Returns null when the release line carries no airport code.
  static String? _extractReleaseAirport(Map<String, dynamic> event) {
    try {
      final description =
          (event['description'] as String? ?? '').replaceAll('\\n', '\n');
      for (final rawLine in description.split('\n')) {
        final trimmed = rawLine.trim();
        if (!trimmed.startsWith('Release')) continue;
        final m = RegExp(r'Release\s*(\d{2}:\d{2})\s*([A-Za-z]{3})')
            .firstMatch(trimmed);
        if (m != null) {
          return m.group(2)!.trim().toUpperCase();
        }
      }
    } catch (e) {
      _logger.warning('Error extracting release airport: $e');
    }
    return null;
  }

  /// Extract reporting (check-in) time from event description
  static DateTime? _extractReportingTime(Map<String, dynamic> event) {
    try {
      final description = (event['description'] as String? ?? '').replaceAll('\\n', '\n');
      final lines = description.split('\n');

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('Check-in')) {
          final timeMatch = RegExp(r'Check-in\s*(\d{2}:\d{2})').firstMatch(trimmed);
          if (timeMatch != null) {
            final timeStr = timeMatch.group(1)!;
            final eventDate = _extractEventDateTime(event);
            return _parseTimeOnDate(timeStr, eventDate);
          }
        }
      }
    } catch (e) {
      _logger.warning('Error extracting reporting time: $e');
    }
    return null;
  }

  /// Extract location from event summary
  static String? _extractLocation(Map<String, dynamic> event) {
    try {
      final summary = event['summary'] as String? ?? '';

      // Extract location from FLY events
      final flyMatch = RegExp(r'FLY \(([^)]+)\)').firstMatch(summary);
      if (flyMatch != null) {
        final route = flyMatch.group(1)!;
        final airports = route.split('-');
        return airports.last.trim(); // Return destination airport
      }

      // Extract location from STANDBY events
      final standbyMatch = RegExp(r'STANDBY \(([^)]+)\)').firstMatch(summary);
      if (standbyMatch != null) {
        return standbyMatch.group(1)!;
      }
    } catch (e) {
      _logger.warning('Error extracting location: $e');
    }
    return null;
  }

  /// Extract destination location from FLY event (where layover occurs)
  static String? _extractDestinationLocation(Map<String, dynamic> event) {
    try {
      final summary = event['summary'] as String? ?? '';

      // Extract destination from FLY events
      final flyMatch = RegExp(r'FLY \(([^)]+)\)').firstMatch(summary);
      if (flyMatch != null) {
        final route = flyMatch.group(1)!;
        final airports = route.split('-');
        return airports.last.trim(); // Return destination airport where layover occurs
      }
    } catch (e) {
      _logger.warning('Error extracting destination location: $e');
    }
    return null;
  }

  /// Extract the correct layover location from FLY and NON-FLY events
  static String? _extractLayoverLocation(Map<String, dynamic> firstFlyEvent, Map<String, dynamic> nonFlyEvent) {
    try {
      // First try to get location from NON-FLY event summary: "NON-FLY (COV)"
      final nonFlySummary = nonFlyEvent['summary'] as String? ?? '';
      final nonFlyLocationMatch = RegExp(r'NON-FLY \(([^)]+)\)').firstMatch(nonFlySummary);
      if (nonFlyLocationMatch != null) {
        final location = nonFlyLocationMatch.group(1)!;
        _logger.info('📍 Layover location from NON-FLY event: $location');
        return location;
      }

      // Fallback: Get destination from first FLY event: "FLY (AYT-COV)" -> COV
      final flySummary = firstFlyEvent['summary'] as String? ?? '';
      final flyMatch = RegExp(r'FLY \(([^)]+)\)').firstMatch(flySummary);
      if (flyMatch != null) {
        final route = flyMatch.group(1)!;
        final airports = route.split('-');
        if (airports.length >= 2) {
          final destination = airports.last.trim();
          _logger.info('📍 Layover location from first FLY destination: $destination');
          return destination;
        }
      }

      _logger.warning('❌ Could not determine layover location from events');
      return null;
    } catch (e) {
      _logger.warning('Error extracting layover location: $e');
      return null;
    }
  }

  /// Check if location is international
  static bool _isInternationalLocation(String location) {
    // List of Turkish domestic airports
    const domesticAirports = [
      'IST', 'ESB', 'AYT', 'ADB', 'DLM', 'BJV', 'GZT', 'TZX', 'MLX', 'ASR',
      'EZS', 'KYA', 'SZF', 'VAS', 'BAL', 'DNZ', 'ERC', 'KFS', 'MZH', 'SIC',
      'TEQ', 'USQ', 'YKO', 'AFY', 'ISE', 'KCM', 'SFQ', 'NOP'
    ];

    return !domesticAirports.contains(location.toUpperCase());
  }

  /// Parse time on specific date
  static DateTime _parseTimeOnDate(String timeStr, DateTime date) {
    final parts = timeStr.split(':');
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);

    return DateTime(date.year, date.month, date.day, hours, minutes);
  }

  /// Calculate summary statistics for layovers
  static Map<String, dynamic> calculateLayoverSummary(List<LayoverEvent> layovers) {
    if (layovers.isEmpty) {
      return {
        'totalCount': 0,
        'totalPayment': 0.0,
        'domesticCount': 0,
        'internationalCount': 0,
        'fullDayCount': 0,
        'halfDayCount': 0,
        'noAllowanceCount': 0,
        'averageDuration': Duration.zero,
        'totalDuration': Duration.zero,
      };
    }

    int domesticCount = 0;
    int internationalCount = 0;
    int fullDayCount = 0;
    int halfDayCount = 0;
    int noAllowanceCount = 0;
    double totalPayment = 0.0;
    Duration totalDuration = Duration.zero;

    for (final layover in layovers) {
      if (layover.isInternational) {
        internationalCount++;
      } else {
        domesticCount++;
      }

      if (layover.allowanceMultiplier == 1.0) {
        fullDayCount++;
      } else if (layover.allowanceMultiplier == 0.5) {
        halfDayCount++;
      } else {
        noAllowanceCount++;
      }

      totalPayment += layover.paymentAmount;
      totalDuration += layover.layoverDuration;
    }

    final averageDuration = Duration(
      milliseconds: (totalDuration.inMilliseconds / layovers.length).round(),
    );

    return {
      'totalCount': layovers.length,
      'totalPayment': totalPayment,
      'domesticCount': domesticCount,
      'internationalCount': internationalCount,
      'fullDayCount': fullDayCount,
      'halfDayCount': halfDayCount,
      'noAllowanceCount': noAllowanceCount,
      'averageDuration': averageDuration,
      'totalDuration': totalDuration,
    };
  }

  /// Format duration for display
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  /// Get layovers for a specific date range
  static List<LayoverEvent> getLayoversInDateRange(
    List<LayoverEvent> layovers,
    DateTime startDate,
    DateTime endDate,
  ) {
    return layovers.where((layover) {
      final layoverDate = layover.date;
      return layoverDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
             layoverDate.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }
}