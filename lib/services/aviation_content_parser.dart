import 'dart:core';
import '../models/schedule_event.dart';
import '../models/text_block.dart';

/// Parser specialized for aviation crew schedule content
class AviationContentParser {
  // Aviation patterns for content recognition
  static final _flightNumberPattern = RegExp(r'\b([A-Z]{2}\d+)\b');
  static final _airportCodePattern = RegExp(r'\b([A-Z]{3})\b');
  static final _timePattern = RegExp(r'\b(\d{1,2}):(\d{2})\b');
  static final _reportPattern = RegExp(r'\b(Report)\s*(\d{1,2}:\d{2})?\b', caseSensitive: false);
  static final _releasePattern = RegExp(r'\b(Release)\s*(\d{1,2}:\d{2})?\b', caseSensitive: false);
  static final _standbyPattern = RegExp(r'\b(SB\d+)\b');
  static final _reservePattern = RegExp(r'\b(RSV\d+)\b');
  static final _offPattern = RegExp(r'\b(OFF)\b', caseSensitive: false);
  static final _avacPattern = RegExp(r'\b(AVAC)\b', caseSensitive: false);
  static final _hotelPattern = RegExp(r'\b(Hotel)\b', caseSensitive: false);
  static final _connectionPattern = RegExp(r'~');
  
  // Flight sequence pattern: "XQ590 AYT 06:37 ~ 11:06 LGW"
  static final _flightSequencePattern = RegExp(
    r'([A-Z]{2}\d+)\s+([A-Z]{3})\s*(\d{1,2}:\d{2})\s*~\s*(\d{1,2}:\d{2})\s*([A-Z]{3})'
  );
  
  // Known airport codes for validation
  static final _knownAirports = {
    'AYT', 'LGW', 'CGN', 'BRU', 'LEJ', 'NUE', 'HAJ', 'IST', 'AUH', 'STR',
    'TZX', 'BAH', 'JNB', 'CPT', 'DUR', 'LHR', 'CDG', 'FRA', 'AMS', 'MUC',
    'ATL', 'ORD', 'DXB', 'LAS', 'LAX', 'JFK', 'SFO', 'MIA', 'DEN', 'SEA'
  };
  
  /// Parse a list of text blocks from a table row into schedule events
  Future<List<ScheduleEvent>> parseRowEvents(
    List<EnhancedTextBlock> blocks,
    DateTime? associatedDate,
  ) async {
    final events = <ScheduleEvent>[];
    
    for (final block in blocks) {
      // Skip blocks that look like day numbers
      if (block.looksLikeDay) continue;
      
      final blockEvents = await parseTextBlockEvents(block.text, associatedDate);
      events.addAll(blockEvents);
    }
    
    return events;
  }
  
  /// Parse events from a single text block
  Future<List<ScheduleEvent>> parseTextBlockEvents(
    String text,
    DateTime? baseDate,
  ) async {
    final events = <ScheduleEvent>[];
    
    try {
      // 1. Try to parse as flight sequence (most complex)
      final flightEvents = _parseFlightSequence(text, baseDate);
      if (flightEvents.isNotEmpty) {
        events.addAll(flightEvents);
      }
      
      // 2. Try to parse as duty events (report/release)
      // Now collects ALL report/release events in the block
      final dutyEvents = _parseDutyEvents(text, baseDate);
      events.addAll(dutyEvents);
      
      // 3. Try to parse as standby/reserve
      final standbyEvents = _parseStandbyEvents(text, baseDate);
      events.addAll(standbyEvents);
      
      // 4. Try to parse as status events (OFF, AVAC, Hotel)
      final statusEvents = _parseStatusEvents(text, baseDate);
      events.addAll(statusEvents);
      
      // 5. Fallback: If nothing specific found but has aviation content
      if (events.isEmpty && _hasAviationContent(text)) {
        events.add(ScheduleEvent(
          type: EventType.unknown,
          rawText: text,
          confidence: 0.3,
        ));
      }
      
    } catch (e) {
      events.add(ScheduleEvent(
        type: EventType.unknown,
        rawText: text,
        confidence: 0.1,
      ));
    }
    
    return events;
  }
  
  /// Parse flight sequences like "XQ590 AYT 06:37 ~ 11:06 LGW"
  List<ScheduleEvent> _parseFlightSequence(String text, DateTime? baseDate) {
    final events = <ScheduleEvent>[];
    final matches = _flightSequencePattern.allMatches(text);
    
    for (final match in matches) {
      final flightNumber = match.group(1)!;
      final origin = match.group(2)!;
      final departureTime = match.group(3)!;
      final arrivalTime = match.group(4)!;
      final destination = match.group(5)!;
      
      // Validate airport codes
      if (!_knownAirports.contains(origin) || !_knownAirports.contains(destination)) {
        continue; // Skip if airport codes are not recognized
      }
      
      // Parse times
      final depTime = _parseTimeString(departureTime, baseDate);
      final arrTime = _parseTimeString(arrivalTime, baseDate);
      
      events.add(ScheduleEvent(
        type: EventType.flight,
        flightNumber: flightNumber,
        origin: origin,
        destination: destination,
        startTime: depTime,
        endTime: arrTime,
        rawText: match.group(0)!,
        confidence: 0.95,
      ));
    }
    
    // Also try simpler flight patterns if complex pattern didn't match
    if (events.isEmpty) {
      final simpleFlightMatches = _flightNumberPattern.allMatches(text);
      final airportMatches = _airportCodePattern.allMatches(text).toList();
      final timeMatches = _timePattern.allMatches(text).toList();
      
      if (simpleFlightMatches.isNotEmpty && airportMatches.length >= 2) {
        for (final flightMatch in simpleFlightMatches) {
          final flightNumber = flightMatch.group(1)!;
          
          // Try to find corresponding airports and times
          String? origin, destination;
          DateTime? departureTime, arrivalTime;
          
          if (airportMatches.length >= 2) {
            origin = airportMatches[0].group(1);
            destination = airportMatches[1].group(1);
          }
          
          if (timeMatches.length >= 2) {
            departureTime = _parseTimeString(timeMatches[0].group(0)!, baseDate);
            arrivalTime = _parseTimeString(timeMatches[1].group(0)!, baseDate);
          } else if (timeMatches.length == 1) {
            departureTime = _parseTimeString(timeMatches[0].group(0)!, baseDate);
          }
          
          events.add(ScheduleEvent(
            type: EventType.flight,
            flightNumber: flightNumber,
            origin: origin,
            destination: destination,
            startTime: departureTime,
            endTime: arrivalTime,
            rawText: text,
            confidence: 0.7,
          ));
          
          break; // Only process first flight number
        }
      }
    }
    
    return events;
  }

  /// Parse duty events (Report/Release) - Returns multiple
  List<ScheduleEvent> _parseDutyEvents(String text, DateTime? baseDate) {
    final events = <ScheduleEvent>[];

    // Check for Report events
    final reportMatches = _reportPattern.allMatches(text);
    for (final match in reportMatches) {
       final timeString = match.group(2);
       final time = timeString != null ? _parseTimeString(timeString, baseDate) : null;
       events.add(ScheduleEvent(
        type: EventType.report,
        startTime: time,
        rawText: text,
        confidence: 0.9,
      ));
    }
    
    // Check for Release events
    final releaseMatches = _releasePattern.allMatches(text);
    for (final match in releaseMatches) {
      final timeString = match.group(2);
      final time = timeString != null ? _parseTimeString(timeString, baseDate) : null;
      events.add(ScheduleEvent(
        type: EventType.release,
        endTime: time,
        rawText: text,
        confidence: 0.9,
      ));
    }
    
    return events;
  }
  
  /// Parse standby/reserve events
  List<ScheduleEvent> _parseStandbyEvents(String text, DateTime? baseDate) {
    final events = <ScheduleEvent>[];

    final standbyMatches = _standbyPattern.allMatches(text);
    for (final match in standbyMatches) {
       events.add(ScheduleEvent(
        type: EventType.standby,
        dutyCode: match.group(1)!,
        rawText: text,
        confidence: 0.95,
      ));
    }
    
    final reserveMatches = _reservePattern.allMatches(text);
    for (final match in reserveMatches) {
        events.add(ScheduleEvent(
        type: EventType.reserve,
        dutyCode: match.group(1)!,
        rawText: text,
        confidence: 0.95,
      ));
    }
    
    return events;
  }
  
  /// Parse status events (OFF, AVAC, Hotel)
  List<ScheduleEvent> _parseStatusEvents(String text, DateTime? baseDate) {
    final events = <ScheduleEvent>[];

    if (_offPattern.hasMatch(text)) {
      events.add(ScheduleEvent(
        type: EventType.off,
        rawText: text,
        confidence: 0.95,
      ));
    }
    
    if (_avacPattern.hasMatch(text)) {
      events.add(ScheduleEvent(
        type: EventType.avac,
        rawText: text,
        confidence: 0.95,
      ));
    }
    
    if (_hotelPattern.hasMatch(text)) {
      events.add(ScheduleEvent(
        type: EventType.hotel,
        rawText: text,
        confidence: 0.9,
      ));
    }
    
    if (_connectionPattern.hasMatch(text)) {
      events.add(ScheduleEvent(
        type: EventType.transit,
        rawText: text,
        confidence: 0.8,
      ));
    }
    
    return events;
  }
  
  /// Parse time string into DateTime
  DateTime? _parseTimeString(String timeString, DateTime? baseDate) {
    final match = _timePattern.firstMatch(timeString);
    if (match == null) return null;
    
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }
    
    final base = baseDate ?? DateTime.now();
    
    try {
      return DateTime(base.year, base.month, base.day, hour, minute);
    } catch (e) {
      return null;
    }
  }
  
  /// Check if text contains aviation-related content
  bool _hasAviationContent(String text) {
    final upperText = text.toUpperCase();
    
    return _flightNumberPattern.hasMatch(upperText) ||
           _airportCodePattern.hasMatch(upperText) ||
           _reportPattern.hasMatch(text) ||
           _releasePattern.hasMatch(text) ||
           _standbyPattern.hasMatch(text) ||
           _reservePattern.hasMatch(text) ||
           _offPattern.hasMatch(text) ||
           _avacPattern.hasMatch(text) ||
           _hotelPattern.hasMatch(text) ||
           _timePattern.hasMatch(text) ||
           _connectionPattern.hasMatch(text);
  }
  
  /// Get confidence score for aviation content recognition
  double getContentConfidence(String text) {
    double confidence = 0.0;
    
    if (_flightNumberPattern.hasMatch(text)) confidence += 0.3;
    if (_airportCodePattern.hasMatch(text)) confidence += 0.2;
    if (_timePattern.hasMatch(text)) confidence += 0.2;
    if (_reportPattern.hasMatch(text) || _releasePattern.hasMatch(text)) confidence += 0.3;
    if (_standbyPattern.hasMatch(text) || _reservePattern.hasMatch(text)) confidence += 0.3;
    if (_offPattern.hasMatch(text)) confidence += 0.2;
    
    return confidence.clamp(0.0, 1.0);
  }
}