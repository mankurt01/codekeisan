# OCR Table Detection Strategy for Crew Schedule PDFs

## Current Situation
- **PDF Format**: Airline crew schedules with calendar-style table layout
- **OCR Tool**: Google ML Kit Text Recognition
- **Challenge**: Extract structured schedule data from unstructured OCR text

## OCR Capabilities Analysis

### ❌ What OCR Cannot Do
- Detect physical table lines/borders
- Identify visual grid structures
- Determine column boundaries automatically
- Separate rows based on visual layout

### ✅ What OCR Can Provide
- Text content with basic positioning
- Spatial coordinates of text blocks (if we enhance our implementation)
- Reading order of text elements
- Font size and style detection (limited)

## Proposed Solutions

### Option 1: Enhanced OCR with Spatial Analysis
**Approach**: Use OCR text block coordinates to infer table structure
- Extract `TextElement` positions from Google ML Kit
- Analyze spatial clustering to group related content
- Use consistent spacing patterns to identify columns/rows

**Pros**: 
- Leverages available spatial data
- More accurate than pure text parsing
- Can handle irregular layouts

**Cons**: 
- Complex implementation
- Requires coordinate analysis logic
- May still struggle with merged cells

### Option 2: Pattern-Based Text Parsing  
**Approach**: Use text patterns and keywords to structure data
- Identify day markers (dates, day names)
- Group content between day markers
- Parse flight codes, times, and duty types
- Use regex patterns for different event types

**Pros**: 
- Simpler to implement
- Works with current OCR output
- Robust against formatting variations

**Cons**: 
- Less accurate for complex layouts
- May miss context without spatial info
- Requires extensive pattern definitions

### Option 3: Hybrid Approach (Recommended)
**Combine both methods**:
1. Use spatial analysis where possible
2. Fall back to pattern-based parsing
3. Cross-validate results between methods

## Implementation Plan

### Phase 1: Enhanced OCR Extraction
```dart
// Extract text blocks with coordinates
class TextBlock {
  final String text;
  final Rect bounds;
  final double confidence;
}

Future<List<TextBlock>> extractTextBlocks(Uint8List pdfBytes) {
  // Enhanced OCR with spatial data
}
```

### Phase 2: Spatial Clustering
```dart
class TableAnalyzer {
  List<List<TextBlock>> identifyRows(List<TextBlock> blocks);
  List<List<TextBlock>> identifyColumns(List<TextBlock> blocks);
  Map<DateTime, List<String>> mapToSchedule(List<List<TextBlock>> grid);
}
```

### Phase 3: Pattern-Based Fallback
```dart
class PatternParser {
  List<ScheduleDay> parseByPatterns(String ocrText);
  // Existing logic enhanced with better regex patterns
}
```

## Crew Schedule Specific Patterns

### Day Identification
- Date patterns: `\d{1,2}` (1-31)
- Day names: Monday, Tuesday, etc.
- Month indicators: December 2025

### Event Types
- **Flight Operations**: `XQ\d+`, `DH\d+`, `TK\d+`
- **Airports**: `AYT`, `LGW`, `CGN`, etc.
- **Times**: `\d{2}:\d{2}`
- **Duties**: `Report`, `Release`, `OFF`, `SB\d`, `RSV\d`
- **Connections**: `~` indicates flight segments

### Data Structure Mapping
```
Day 1:
  - Report 17:30
  - XQ234 AYT→HAJ 18:50
  - ~ 22:45 HAJ
  - XQ235 HAJ→AYT 23:40
  - Release 03:10+1
```

## Technical Implementation

### Enhanced OCR Service
- Modify `_extractTextWithOCR()` to capture spatial data
- Implement text block clustering algorithms
- Add coordinate-based sorting and grouping

### New Parser Components
- `SpatialTableAnalyzer` - for coordinate-based parsing
- `CrewSchedulePatternParser` - for aviation-specific patterns  
- `ScheduleValidator` - to cross-check results

### Error Handling
- Multiple parsing attempts (spatial → pattern → fallback)
- Confidence scoring for parsed results
- Manual correction suggestions for ambiguous cases

## Expected Outcomes
- **Accuracy**: 80-90% for well-formatted schedules
- **Robustness**: Handles variations in PDF quality/format
- **Maintainability**: Clear separation of concerns
- **Extensibility**: Easy to add new schedule formats

## Next Steps
1. Implement enhanced OCR with spatial data capture
2. Build spatial clustering algorithms
3. Create aviation-specific pattern library
4. Test with real crew schedule PDFs
5. Iterate based on accuracy results