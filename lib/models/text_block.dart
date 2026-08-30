import 'dart:ui';
import 'dart:math' as math;

/// Enhanced text block with spatial information for table detection
class EnhancedTextBlock {
  final String text;
  final Rect bounds;
  final double confidence;
  final int pageNumber;
  final List<TextLine> lines;
  final EnhancedTextBlock? parent;
  final Size pageSize;

  const EnhancedTextBlock({
    required this.text,
    required this.bounds,
    required this.confidence,
    required this.pageNumber,
    required this.lines,
    this.parent,
    this.pageSize = const Size(1000, 1000), // Default for backward compatibility
  });

  /// Center X coordinate
  double get centerX => bounds.left + bounds.width / 2;

  /// Center Y coordinate  
  double get centerY => bounds.top + bounds.height / 2;

  /// Check if this block overlaps vertically with another (same row)
  bool overlapsVertically(EnhancedTextBlock other, {double tolerance = 10.0}) {
    final thisTop = bounds.top;
    final thisBottom = bounds.bottom;
    final otherTop = other.bounds.top;
    final otherBottom = other.bounds.bottom;
    
    return (thisTop - tolerance <= otherBottom) && (otherTop - tolerance <= thisBottom);
  }

  /// Check if this block overlaps horizontally with another (same column)
  bool overlapsHorizontally(EnhancedTextBlock other, {double tolerance = 10.0}) {
    final thisLeft = bounds.left;
    final thisRight = bounds.right;
    final otherLeft = other.bounds.left;
    final otherRight = other.bounds.right;
    
    return (thisLeft - tolerance <= otherRight) && (otherLeft - tolerance <= thisRight);
  }

  /// Check if blocks are vertically aligned (same column)
  bool isVerticallyAligned(EnhancedTextBlock other, {double tolerance = 10.0}) {
    return (centerX - other.centerX).abs() < tolerance;
  }

  /// Check if blocks are horizontally aligned (same row)
  bool isHorizontallyAligned(EnhancedTextBlock other, {double tolerance = 10.0}) {
    return (centerY - other.centerY).abs() < tolerance;
  }

  /// Distance to another text block
  double distanceTo(EnhancedTextBlock other) {
    final dx = centerX - other.centerX;
    final dy = centerY - other.centerY;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Check if this looks like a date/day number (1-31)
  bool get looksLikeDay {
    final trimmed = text.trim();
    final dayPattern = RegExp(r'^\d{1,2}$');
    if (dayPattern.hasMatch(trimmed)) {
      final dayNumber = int.tryParse(trimmed);
      return dayNumber != null && dayNumber >= 1 && dayNumber <= 31;
    }
    return false;
  }

  /// Check if this contains aviation-related content
  bool get hasAviationContent {
    final upperText = text.toUpperCase();
    return upperText.contains(RegExp(r'\b[A-Z]{2}\d+\b')) || // Flight numbers
           upperText.contains(RegExp(r'\b[A-Z]{3}\b')) ||     // Airport codes
           upperText.contains('REPORT') ||
           upperText.contains('RELEASE') ||
           upperText.contains('OFF') ||
           upperText.contains(RegExp(r'SB\d+')) ||            // Standby
           upperText.contains(RegExp(r'RSV\d+')) ||           // Reserve
           upperText.contains('AVAC') ||
           upperText.contains('HOTEL') ||
           upperText.contains('~') ||                         // Flight connections
           RegExp(r'\d{2}:\d{2}').hasMatch(text);            // Times
  }

  @override
  String toString() {
    return 'EnhancedTextBlock(text: "$text", bounds: $bounds, confidence: $confidence)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EnhancedTextBlock &&
        other.text == text &&
        other.bounds == bounds &&
        other.confidence == confidence &&
        other.pageNumber == pageNumber;
  }

  @override
  int get hashCode {
    return Object.hash(text, bounds, confidence, pageNumber);
  }
}

/// Represents a line of text within a text block
class TextLine {
  final String text;
  final Rect bounds;
  final List<TextElement> elements;
  final double confidence;

  const TextLine({
    required this.text,
    required this.bounds,
    required this.elements,
    required this.confidence,
  });

  @override
  String toString() {
    return 'TextLine(text: "$text", elements: ${elements.length})';
  }
}

/// Represents an individual text element (word/character)
class TextElement {
  final String text;
  final Rect bounds;
  final double confidence;

  const TextElement({
    required this.text,
    required this.bounds,
    required this.confidence,
  });

  @override
  String toString() {
    return 'TextElement(text: "$text", bounds: $bounds)';
  }
}