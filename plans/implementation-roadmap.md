# Implementation Roadmap & Technical Specifications

## Project Overview
Transform the existing Syncfusion-based PDF parser to an OCR-based system capable of parsing airline crew schedules (Orcun format and new_schedule format) with high accuracy and reliability.

## Technical Architecture

### Core Components

```
keisan/
├── lib/services/
│   ├── pdf_parser_service.dart (enhanced)
│   ├── spatial_table_parser.dart (new)
│   ├── aviation_pattern_parser.dart (new)
│   ├── schedule_validator.dart (new)
│   └── text_block_analyzer.dart (new)
├── lib/models/
│   ├── text_block.dart (new)
│   ├── schedule_event.dart (new)
│   ├── parsing_result.dart (new)
│   └── schedule_day.dart (enhanced)
├── lib/utils/
│   ├── aviation_patterns.dart (new)
│   ├── ocr_text_cleaner.dart (new)
│   └── coordinate_analyzer.dart (new)
└── test/
    ├── pdf_parsing_enhanced_test.dart (new)
    ├── spatial_parser_test.dart (new)
    └── aviation_parser_test.dart (new)
```

## Implementation Phases

### Phase 1: Foundation & Core Models (Week 1)

#### 1.1 Enhanced Data Models

**TextBlock Model** - [`lib/models/text_block.dart`](lib/models/text_block.dart)
```dart
class TextBlock {
  final String text;
  final Rect bounds;
  final double confidence;
  final int pageNumber;
  final List<TextElement> elements;
  
  // Spatial analysis helpers
  double get centerX => bounds.left + bounds.width / 2;
  double get centerY => bounds.top + bounds.height / 2;
  bool overlapsVertically(TextBlock other);
  bool overlapsHorizontally(TextBlock other);
}

class TextElement {
  final String text;
  final Rect bounds;
  final double confidence;
}
```

**ScheduleEvent Model** - [`lib/models/schedule_event.dart`](lib/models/schedule_event.dart)
```dart
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
  
  // Aviation-specific methods
  bool get isFlightEvent => type == EventType.flight;
  bool get isDutyEvent => [EventType.report, EventType.release].contains(type);
  Duration? get duration => startTime != null && endTime != null 
    ? endTime!.difference(startTime!) : null;
}
```

#### 1.2 Enhanced OCR Extraction

**Update PdfParserService** - [`lib/services/pdf_parser_service.dart`](lib/services/pdf_parser_service.dart)
```dart
class PdfParserService {
  Future<List<ScheduleDay>> parsePdf(Uint8List pdfBytes) async {
    try {
      // Enhanced OCR with spatial data
      final textBlocks = await _extractTextBlocks(pdfBytes);
      
      // Try hybrid parsing approach
      final hybridParser = HybridScheduleParser();
      return await hybridParser.parse(textBlocks);
      
    } catch (e) {
      return _handleParsingError(e);
    }
  }
  
  Future<List<TextBlock>> _extractTextBlocks(Uint8List pdfBytes) async {
    final document = await pdf_render.PdfDocument.openData(pdfBytes);
    final textBlocks = <TextBlock>[];
    
    for (int i = 1; i <= document.pageCount; i++) {
      final page = await document.getPage(i);
      final pageImage = await page.render(
        width: (page.width * 2).toInt(), 
        height: (page.height * 2).toInt()
      );
      
      final inputImage = InputImage.fromBytes(
        bytes: pageImage.pixels,
        metadata: InputImageMetadata(
          size: Size(pageImage.width.toDouble(), pageImage.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.bgra8888,
          bytesPerRow: pageImage.width * 4,
        ),
      );
      
      final textRecognizer = TextRecognizer();
      final recognizedText = await textRecognizer.processImage(inputImage);
      
      // Extract blocks with coordinates
      for (final textBlock in recognizedText.blocks) {
        final block = TextBlock(
          text: textBlock.text,
          bounds: textBlock.boundingBox,
          confidence: textBlock.recognizedLanguages.isNotEmpty 
            ? textBlock.recognizedLanguages.first.confidence ?? 0.0 
            : 0.0,
          pageNumber: i,
          elements: textBlock.lines.expand((line) => 
            line.elements.map((element) => TextElement(
              text: element.text,
              bounds: element.boundingBox,
              confidence: element.recognizedLanguages.isNotEmpty 
                ? element.recognizedLanguages.first.confidence ?? 0.0 
                : 0.0,
            ))
          ).toList(),
        );
        textBlocks.add(block);
      }
      
      await textRecognizer.close();
    }
    
    await document.dispose();
    return textBlocks;
  }
}
```

### Phase 2: Spatial Analysis Engine (Week 2)

#### 2.1 Coordinate Analyzer Utility

**CoordinateAnalyzer** - [`lib/utils/coordinate_analyzer.dart`](lib/utils/coordinate_analyzer.dart)
```dart
class CoordinateAnalyzer {
  static List<List<TextBlock>> clusterByRows(List<TextBlock> blocks) {
    // Sort blocks by Y-coordinate
    blocks.sort((a, b) => a.bounds.top.compareTo(b.bounds.top));
    
    final rows = <List<TextBlock>>[];
    var currentRow = <TextBlock>[];
    double? lastY;
    
    for (final block in blocks) {
      if (lastY == null || (block.bounds.top - lastY).abs() < 20) {
        // Same row (within 20 pixels)
        currentRow.add(block);
      } else {
        // New row
        if (currentRow.isNotEmpty) {
          rows.add(List.from(currentRow));
          currentRow.clear();
        }
        currentRow.add(block);
      }
      lastY = block.bounds.top;
    }
    
    if (currentRow.isNotEmpty) {
      rows.add(currentRow);
    }
    
    return rows;
  }
  
  static List<List<TextBlock>> clusterByColumns(List<TextBlock> blocks) {
    // Similar logic for X-coordinate clustering
    // Implementation details...
  }
  
  static bool areAligned(TextBlock a, TextBlock b, {double tolerance = 10}) {
    return (a.centerY - b.centerY).abs() < tolerance;
  }
}
```

#### 2.2 Spatial Table Parser

**SpatialTableParser** - [`lib/services/spatial_table_parser.dart`](lib/services/spatial_table_parser.dart)
```dart
class SpatialTableParser {
  Future<ParseResult> parse(List<TextBlock> blocks) async {
    try {
      // Step 1: Identify table structure
      final tableStructure = _identifyTableStructure(blocks);
      
      // Step 2: Map to schedule days
      final schedule = _mapToSchedule(tableStructure);
      
      // Step 3: Validate spatial consistency
      final confidence = _calculateSpatialConfidence(tableStructure);
      
      return ParseResult(
        schedule: schedule,
        confidence: confidence,
        method: 'spatial',
        metadata: {'rows': tableStructure.rows.length},
      );
      
    } catch (e) {
      throw SpatialParsingException('Spatial parsing failed: $e');
    }
  }
  
  TableStructure _identifyTableStructure(List<TextBlock> blocks) {
    // Clean and filter blocks
    final cleanBlocks = _cleanTextBlocks(blocks);
    
    // Identify rows (days)
    final rows = CoordinateAnalyzer.clusterByRows(cleanBlocks);
    
    // Identify date indicators in each row
    final dateRows = <DateRow>[];
    for (final row in rows) {
      final dateBlock = _findDateBlock(row);
      if (dateBlock != null) {
        final eventBlocks = row.where((b) => b != dateBlock).toList()
          ..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
        
        dateRows.add(DateRow(
          dateBlock: dateBlock,
          eventBlocks: eventBlocks,
        ));
      }
    }
    
    return TableStructure(rows: dateRows);
  }
  
  TextBlock? _findDateBlock(List<TextBlock> row) {
    final datePattern = RegExp(r'^\s*(\d{1,2})\s*$');
    
    for (final block in row) {
      if (datePattern.hasMatch(block.text.trim())) {
        final dayNumber = int.tryParse(block.text.trim());
        if (dayNumber != null && dayNumber >= 1 && dayNumber <= 31) {
          return block;
        }
      }
    }
    return null;
  }
  
  List<ScheduleDay> _mapToSchedule(TableStructure structure) {
    final schedule = <ScheduleDay>[];
    
    for (final dateRow in structure.rows) {
      final dayNumber = int.tryParse(dateRow.dateBlock.text.trim());
      if (dayNumber == null) continue;
      
      // Parse events in this row
      final events = <ScheduleEvent>[];
      for (final eventBlock in dateRow.eventBlocks) {
        final parsedEvents = _parseEventBlock(eventBlock);
        events.addAll(parsedEvents);
      }
      
      if (events.isNotEmpty) {
        final date = DateTime(2025, 12, dayNumber); // TODO: Dynamic year/month
        schedule.add(ScheduleDay(
          date: date,
          dayOfWeek: _getDayOfWeek(date.weekday),
          events: events.map((e) => e.rawText).toList(),
        ));
      }
    }
    
    return schedule;
  }
}

class TableStructure {
  final List<DateRow> rows;
  TableStructure({required this.rows});
}

class DateRow {
  final TextBlock dateBlock;
  final List<TextBlock> eventBlocks;
  DateRow({required this.dateBlock, required this.eventBlocks});
}
```

### Phase 3: Aviation Pattern Engine (Week 3)

#### 3.1 Aviation Patterns Library

**AviationPatterns** - [`lib/utils/aviation_patterns.dart`](lib/utils/aviation_patterns.dart)
```dart
class AviationPatterns {
  // Date and time patterns
  static final dayNumber = RegExp(r'^\s*(\d{1,2})\s*$');
  static final timePattern = RegExp(r'\b(\d{2}):(\d{2})\b');
  static final datePattern = RegExp(r'\b(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})\b');
  
  // Flight patterns
  static final flightPattern = RegExp(r'\b([A-Z]{2}\d+)\b');
  static final routePattern = RegExp(r'\b([A-Z]{3})\s*([A-Z]{3})\b');
  static final connectionPattern = RegExp(r'~\s*(.+?)(?=\s*[A-Z]{2}\d+|\s*$)');
  
  // Airport codes (major ones for validation)
  static final Set<String> knownAirports = {
    'AYT', 'LGW', 'CGN', 'BRU', 'LEJ', 'NUE', 'HAJ', 'IST', 'AUH', 'STR', 
    'TZX', 'BAH', 'JNB', 'CPT', 'DUR', 'LHR', 'CDG', 'FRA', 'AMS', 'MUC'
  };
  
  // Duty patterns
  static final reportPattern = RegExp(r'\b(Report)\s*(\d{2}:\d{2})?\b', caseSensitive: false);
  static final releasePattern = RegExp(r'\b(Release)\s*(\d{2}:\d{2})?\b', caseSensitive: false);
  static final offPattern = RegExp(r'\b(OFF)\b', caseSensitive: false);
  static final standbyPattern = RegExp(r'\b(SB\d+)\b');
  static final reservePattern = RegExp(r'\b(RSV\d+)\b');
  static final avacPattern = RegExp(r'\b(AVAC)\b', caseSensitive: false);
  static final hotelPattern = RegExp(r'\b(Hotel)\b', caseSensitive: false);
  
  // Airline codes
  static final Set<String> knownAirlines = {
    'XQ', 'TK', 'DH', 'SA', 'SB', 'UA', 'LH', 'BA', 'AF', 'KL'
  };
  
  // Complex patterns for flight sequences
  static final flightSequencePattern = RegExp(
    r'([A-Z]{2}\d+)\s+([A-Z]{3})\s*(\d{2}:\d{2})\s*~\s*(\d{2}:\d{2})\s*([A-Z]{3})'
  );
}
```

#### 3.2 Aviation Pattern Parser

**AviationPatternParser** - [`lib/services/aviation_pattern_parser.dart`](lib/services/aviation_pattern_parser.dart)
```dart
class AviationPatternParser {
  Future<ParseResult> parse(String ocrText) async {
    try {
      final cleanText = OcrTextCleaner.clean(ocrText);
      final lines = cleanText.split('\n').where((l) => l.trim().isNotEmpty).toList();
      
      final schedule = <ScheduleDay>[];
      final dayEvents = <int, List<ScheduleEvent>>{};
      
      // Parse line by line
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        
        // Check if this line contains a day number
        final dayMatch = AviationPatterns.dayNumber.firstMatch(line);
        if (dayMatch != null) {
          final dayNumber = int.parse(dayMatch.group(1)!);
          dayEvents[dayNumber] = [];
          
          // Look ahead for events related to this day
          final events = _extractDayEvents(lines, i);
          dayEvents[dayNumber] = events;
        }
      }
      
      // Convert to ScheduleDay objects
      for (final entry in dayEvents.entries) {
        if (entry.value.isNotEmpty) {
          final date = DateTime(2025, 12, entry.key);
          schedule.add(ScheduleDay(
            date: date,
            dayOfWeek: _getDayOfWeek(date.weekday),
            events: entry.value.map((e) => e.rawText).toList(),
          ));
        }
      }
      
      return ParseResult(
        schedule: schedule,
        confidence: _calculatePatternConfidence(schedule),
        method: 'pattern',
        metadata: {'totalEvents': dayEvents.values.expand((e) => e).length},
      );
      
    } catch (e) {
      throw PatternParsingException('Pattern parsing failed: $e');
    }
  }
  
  List<ScheduleEvent> _extractDayEvents(List<String> lines, int startIndex) {
    final events = <ScheduleEvent>[];
    
    // Look at lines following the day number
    for (int i = startIndex + 1; i < lines.length && i < startIndex + 10; i++) {
      final line = lines[i].trim();
      
      // Stop if we hit another day number
      if (AviationPatterns.dayNumber.hasMatch(line)) break;
      
      // Skip calendar headers
      if (_isCalendarHeader(line)) continue;
      
      // Parse aviation events
      final lineEvents = _parseEventLine(line);
      events.addAll(lineEvents);
    }
    
    return events;
  }
  
  List<ScheduleEvent> _parseEventLine(String line) {
    final events = <ScheduleEvent>[];
    
    // Try to parse as flight sequence first
    final flightEvents = _parseFlightSequence(line);
    if (flightEvents.isNotEmpty) {
      events.addAll(flightEvents);
      return events;
    }
    
    // Try to parse as duty event
    final dutyEvent = _parseDutyEvent(line);
    if (dutyEvent != null) {
      events.add(dutyEvent);
      return events;
    }
    
    // Try to parse as OFF/AVAC/Hotel
    final statusEvent = _parseStatusEvent(line);
    if (statusEvent != null) {
      events.add(statusEvent);
      return events;
    }
    
    // Default: treat as unknown event if it has aviation content
    if (_hasAviationContent(line)) {
      events.add(ScheduleEvent(
        type: EventType.unknown,
        rawText: line,
        confidence: 0.3,
      ));
    }
    
    return events;
  }
  
  List<ScheduleEvent> _parseFlightSequence(String line) {
    final events = <ScheduleEvent>[];
    
    // Pattern: "XQ590 AYT 06:37 ~ 11:06 LGW XQ591 LGW 12:35 ~ 16:55 AYT"
    final matches = AviationPatterns.flightSequencePattern.allMatches(line);
    
    for (final match in matches) {
      final flightNumber = match.group(1)!;
      final origin = match.group(2)!;
      final departureTime = match.group(3)!;
      final arrivalTime = match.group(4)!;
      final destination = match.group(5)!;
      
      events.add(ScheduleEvent(
        type: EventType.flight,
        flightNumber: flightNumber,
        origin: origin,
        destination: destination,
        startTime: _parseTime(departureTime),
        endTime: _parseTime(arrivalTime),
        rawText: match.group(0)!,
        confidence: 0.9,
      ));
    }
    
    return events;
  }
  
  ScheduleEvent? _parseDutyEvent(String line) {
    // Parse Report events
    final reportMatch = AviationPatterns.reportPattern.firstMatch(line);
    if (reportMatch != null) {
      return ScheduleEvent(
        type: EventType.report,
        startTime: reportMatch.group(2) != null ? _parseTime(reportMatch.group(2)!) : null,
        rawText: line,
        confidence: 0.95,
      );
    }
    
    // Parse Release events
    final releaseMatch = AviationPatterns.releasePattern.firstMatch(line);
    if (releaseMatch != null) {
      return ScheduleEvent(
        type: EventType.release,
        endTime: releaseMatch.group(2) != null ? _parseTime(releaseMatch.group(2)!) : null,
        rawText: line,
        confidence: 0.95,
      );
    }
    
    // Parse Standby events
    final standbyMatch = AviationPatterns.standbyPattern.firstMatch(line);
    if (standbyMatch != null) {
      return ScheduleEvent(
        type: EventType.standby,
        dutyCode: standbyMatch.group(1)!,
        rawText: line,
        confidence: 0.9,
      );
    }
    
    return null;
  }
  
  DateTime? _parseTime(String timeStr) {
    final match = AviationPatterns.timePattern.firstMatch(timeStr);
    if (match != null) {
      final hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      
      // Use a base date - this will be adjusted later
      return DateTime(2025, 12, 1, hour, minute);
    }
    return null;
  }
}
```

### Phase 4: Integration & Testing (Week 4)

#### 4.1 Hybrid Parser Integration

**HybridScheduleParser** - Update [`lib/services/pdf_parser_service.dart`](lib/services/pdf_parser_service.dart)
```dart
class HybridScheduleParser {
  final SpatialTableParser spatialParser = SpatialTableParser();
  final AviationPatternParser patternParser = AviationPatternParser();
  final ScheduleValidator validator = ScheduleValidator();
  
  Future<List<ScheduleDay>> parse(List<TextBlock> blocks) async {
    ParseResult? bestResult;
    final results = <ParseResult>[];
    
    // Attempt 1: Spatial parsing (if coordinates are reliable)
    if (_hasSpatialData(blocks)) {
      try {
        final spatialResult = await spatialParser.parse(blocks);
        results.add(spatialResult);
      } catch (e) {
        print('Spatial parsing failed: $e');
      }
    }
    
    // Attempt 2: Pattern parsing (always attempt as fallback)
    try {
      final text = blocks.map((b) => b.text).join('\n');
      final patternResult = await patternParser.parse(text);
      results.add(patternResult);
    } catch (e) {
      print('Pattern parsing failed: $e');
    }
    
    // Select best result based on confidence and validation
    if (results.isNotEmpty) {
      bestResult = results.reduce((a, b) => 
        a.confidence > b.confidence ? a : b);
    }
    
    if (bestResult != null && bestResult.confidence > 0.5) {
      // Validate and enhance the result
      final validatedResult = validator.validate(bestResult.schedule);
      return validatedResult.schedule;
    }
    
    // Last resort: return error or minimal fallback
    return _createFallbackSchedule(blocks);
  }
}
```

#### 4.2 Comprehensive Testing Strategy

**Test Structure**:
```
test/
├── unit_tests/
│   ├── aviation_patterns_test.dart
│   ├── coordinate_analyzer_test.dart
│   ├── ocr_text_cleaner_test.dart
│   └── schedule_validator_test.dart
├── integration_tests/
│   ├── spatial_parser_integration_test.dart
│   ├── pattern_parser_integration_test.dart
│   └── hybrid_parser_integration_test.dart
├── pdf_test_samples/
│   ├── orcun_schedule_test.dart
│   ├── new_schedule_test.dart
│   └── generic_crew_schedule_test.dart
└── performance_tests/
    └── large_pdf_parsing_test.dart
```

## Delivery Timeline

| Week | Phase | Deliverables | Success Criteria |
|------|-------|-------------|------------------|
| 1 | Foundation | Core models, Enhanced OCR | Clean architecture, 90% OCR extraction |
| 2 | Spatial Engine | Coordinate analysis, Table detection | 70% accuracy on structured PDFs |
| 3 | Pattern Engine | Aviation patterns, Event parsing | 80% accuracy on Orcun format |
| 4 | Integration | Hybrid parser, Comprehensive testing | 85%+ overall accuracy |

## Quality Gates

- [ ] **Code Quality**: 90%+ test coverage, no critical linting issues
- [ ] **Performance**: <5 second parsing for typical crew schedule PDF  
- [ ] **Accuracy**: 85%+ correct event extraction on test PDFs
- [ ] **Robustness**: Handles 3+ different schedule formats gracefully
- [ ] **Maintainability**: Clear separation of concerns, comprehensive documentation

## Risk Mitigation Plan

1. **OCR Quality Issues**: Multi-resolution rendering, preprocessing filters
2. **Format Variations**: Pluggable parser architecture, format detection
3. **Performance Bottlenecks**: Lazy loading, parallel processing where applicable
4. **Accuracy Problems**: Manual correction UI, confidence thresholds
5. **Maintenance Complexity**: Automated testing, clear documentation

This roadmap provides a structured approach to implementing the enhanced crew schedule parsing system with measurable deliverables and clear success criteria.