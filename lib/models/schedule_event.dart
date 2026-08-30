import 'text_block.dart';
import 'schedule_day.dart';

/// Types of events found in crew schedules
enum EventType {
  flight,      // XQ590, TK123, etc.
  report,      // Duty start
  release,     // Duty end  
  standby,     // SB1, SB2, SB3
  reserve,     // RSV1, RSV2, RSV3
  off,         // OFF day
  hotel,       // Hotel accommodation
  transit,     // ~ connections
  avac,        // Annual vacation
  unknown
}

/// Represents a single schedule event (flight, duty, etc.)
class ScheduleEvent {
  final EventType type;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? flightNumber;
  final String? origin;
  final String? destination;
  final String? dutyCode;
  final String rawText;
  final double confidence;

  const ScheduleEvent({
    required this.type,
    this.startTime,
    this.endTime,
    this.flightNumber,
    this.origin,
    this.destination,
    this.dutyCode,
    required this.rawText,
    required this.confidence,
  });

  /// Check if this is a flight event
  bool get isFlightEvent => type == EventType.flight;

  /// Check if this is a duty event (report/release)
  bool get isDutyEvent => [EventType.report, EventType.release].contains(type);

  /// Check if this is a standby or reserve event
  bool get isStandbyOrReserve => [EventType.standby, EventType.reserve].contains(type);

  /// Calculate duration if both start and end times are available
  Duration? get duration {
    if (startTime != null && endTime != null) {
      return endTime!.difference(startTime!);
    }
    return null;
  }

  /// Get a human-readable description of the event
  String get description {
    switch (type) {
      case EventType.flight:
        final route = (origin != null && destination != null) 
          ? '$origin → $destination' : '';
        final time = _formatTimeRange();
        return '${flightNumber ?? 'Flight'} $route $time'.trim();
        
      case EventType.report:
        final time = startTime != null ? _formatTime(startTime!) : '';
        return 'Report $time'.trim();
        
      case EventType.release:
        final time = endTime != null ? _formatTime(endTime!) : '';
        return 'Release $time'.trim();
        
      case EventType.standby:
        return dutyCode ?? 'Standby';
        
      case EventType.reserve:
        return dutyCode ?? 'Reserve';
        
      case EventType.off:
        return 'OFF';
        
      case EventType.hotel:
        return 'Hotel';
        
      case EventType.transit:
        return 'Transit';
        
      case EventType.avac:
        return 'AVAC';
        
      case EventType.unknown:
        return rawText.length > 20 ? '${rawText.substring(0, 20)}...' : rawText;
    }
  }

  /// Format time range for display
  String _formatTimeRange() {
    if (startTime != null && endTime != null) {
      return '${_formatTime(startTime!)} - ${_formatTime(endTime!)}';
    } else if (startTime != null) {
      return _formatTime(startTime!);
    } else if (endTime != null) {
      return _formatTime(endTime!);
    }
    return '';
  }

  /// Format individual time for display
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Create a copy with updated values
  ScheduleEvent copyWith({
    EventType? type,
    DateTime? startTime,
    DateTime? endTime,
    String? flightNumber,
    String? origin,
    String? destination,
    String? dutyCode,
    String? rawText,
    double? confidence,
  }) {
    return ScheduleEvent(
      type: type ?? this.type,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      flightNumber: flightNumber ?? this.flightNumber,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      dutyCode: dutyCode ?? this.dutyCode,
      rawText: rawText ?? this.rawText,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  String toString() {
    return 'ScheduleEvent(type: $type, description: "$description", confidence: $confidence)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScheduleEvent &&
        other.type == type &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.flightNumber == flightNumber &&
        other.origin == origin &&
        other.destination == destination &&
        other.dutyCode == dutyCode &&
        other.rawText == rawText;
  }

  @override
  int get hashCode {
    return Object.hash(
      type,
      startTime,
      endTime,
      flightNumber,
      origin,
      destination,
      dutyCode,
      rawText,
    );
  }
}

/// Result of parsing operation with metadata
class ParseResult {
  final List<ScheduleDay> schedule;
  final double confidence;
  final String method;
  final Map<String, dynamic> metadata;

  const ParseResult({
    required this.schedule,
    required this.confidence,
    required this.method,
    this.metadata = const {},
  });

  /// Check if the parsing result is considered successful
  bool get isSuccessful => confidence >= 0.5 && schedule.isNotEmpty;

  @override
  String toString() {
    return 'ParseResult(schedule: ${schedule.length} days, confidence: $confidence, method: $method)';
  }
}

/// Represents table structure detected in the PDF
class TableStructure {
  final List<TableRow> rows;
  final List<TableColumn> columns;
  final double confidence;

  const TableStructure({
    required this.rows,
    this.columns = const [],
    required this.confidence,
  });

  /// Get the number of rows in the table
  int get rowCount => rows.length;

  /// Get the number of columns (if detected)
  int get columnCount => columns.isNotEmpty ? columns.length : 0;

  @override
  String toString() {
    return 'TableStructure(rows: $rowCount, columns: $columnCount, confidence: $confidence)';
  }
}

/// Represents a row in the detected table
class TableRow {
  final List<EnhancedTextBlock> blocks;
  final double averageY;
  final DateTime? associatedDate;

  const TableRow({
    required this.blocks,
    required this.averageY,
    this.associatedDate,
  });

  /// Check if this row contains a date indicator
  bool get hasDateIndicator {
    return blocks.any((block) => block.looksLikeDay);
  }

  /// Get the date block if present
  EnhancedTextBlock? get dateBlock {
    return blocks.firstWhere(
      (block) => block.looksLikeDay,
      orElse: () => blocks.first,
    );
  }

  /// Get all non-date blocks (event blocks)
  List<EnhancedTextBlock> get eventBlocks {
    return blocks.where((block) => !block.looksLikeDay).toList();
  }

  @override
  String toString() {
    return 'TableRow(blocks: ${blocks.length}, y: $averageY, date: $associatedDate)';
  }
}

/// Represents a column in the detected table
class TableColumn {
  final List<EnhancedTextBlock> blocks;
  final double averageX;
  final String? header;

  const TableColumn({
    required this.blocks,
    required this.averageX,
    this.header,
  });

  @override
  String toString() {
    return 'TableColumn(blocks: ${blocks.length}, x: $averageX, header: $header)';
  }
}