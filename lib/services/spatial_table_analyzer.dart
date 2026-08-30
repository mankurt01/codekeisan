import '../models/text_block.dart';
import '../models/schedule_event.dart';

/// Analyzes spatial relationships using a Fixed Grid (A4 Canvas) strategy
class SpatialTableAnalyzer {
  // Configurable Grid Parameters (Normalized 0.0 - 1.0)
  static const double _calendarLeft = 0.02;
  static const double _calendarRight = 0.98;
  static const double _calendarTop = 0.12; // Moved up slightly to catch headers if needed
  static const double _calendarBottom = 0.95;
  static const int _gridCols = 7;
  
  // Vertical tolerance for overflow (5% of cell height)
  // static const double _overflowTolerance = 0.05;

  /// Analyze text blocks to identify table structure using Fixed Grid
  Future<TableStructure> analyzeLayout(List<EnhancedTextBlock> blocks) async {
    List<TableRow> dayEntries = []; // Each TableRow represents a single Day Cell
    
    try {
      // 1. Group blocks by page
      final blocksByPage = <int, List<EnhancedTextBlock>>{};
      for (final block in blocks) {
        blocksByPage.putIfAbsent(block.pageNumber, () => []).add(block);
      }

      // 2. Process each page separately
      for (final pageNum in blocksByPage.keys) {
        final pageBlocks = blocksByPage[pageNum]!;
        if (pageBlocks.isEmpty) continue;

        // Extract context (Year/Month) from this page
        final (pageYear, pageMonth) = _extractPageContext(pageBlocks);
        
        // Process the grid for this page
        final pageDays = _processPageGrid(pageBlocks, pageYear, pageMonth);
        dayEntries.addAll(pageDays);
      }
      
      // 3. Sort by Date
      dayEntries.sort((a, b) {
          if (a.associatedDate == null && b.associatedDate == null) return 0;
          if (a.associatedDate == null) return 1;
          if (b.associatedDate == null) return -1;
          return a.associatedDate!.compareTo(b.associatedDate!);
      });

      return TableStructure(
        rows: dayEntries,
        columns: [], // Not needed for this strategy
        confidence: dayEntries.isNotEmpty ? 0.9 : 0.0,
      );
      
    } catch (e) {
      print('Grid analysis failed: $e');
      return TableStructure(rows: [], columns: [], confidence: 0.0);
    }
  }

  /// Extract Year and Month context from page header blocks
  (int, int) _extractPageContext(List<EnhancedTextBlock> blocks) {
    int year = DateTime.now().year;
    int month = DateTime.now().month;
    
    final headerRegex = RegExp(r'(JANUARY|FEBRUARY|MARCH|APRIL|MAY|JUNE|JULY|AUGUST|SEPTEMBER|OCTOBER|NOVEMBER|DECEMBER|JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[a-z]*\s+(\d{4})', caseSensitive: false);
    final monthMap = {
      'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
      'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12
    };

    // Check blocks in the top 20% of the page
    for (final block in blocks) {
       // Normalize Y
       double normalizedY = block.centerY / block.pageSize.height;
       if (normalizedY > 0.2) {
         continue; 
       } 
       
       final match = headerRegex.firstMatch(block.text);
       if (match != null) {
          String monthStr = match.group(1)!.toUpperCase().substring(0, 3);
          year = int.parse(match.group(2)!);
          month = monthMap[monthStr] ?? month;
          print('Context Found: $monthStr $year');
          return (year, month);
       }
    }
    return (year, month);
  }

  /// Core Grid Logic: Assign blocks to Day Cells
  List<TableRow> _processPageGrid(List<EnhancedTextBlock> blocks, int year, int month) {
      print('Processing Grid for ${blocks.length} blocks. Context: $month/$year');
      final days = <TableRow>[];
      
      // Determine number of rows (5 or 6) based on block distribution?
      // For now, let's assume 6 rows to be safe, or detect lowest block.
      // Standard rosters often have 5 or 6 weeks.
      int gridRows = 6; 
      
      final dayWidth = (_calendarRight - _calendarLeft) / _gridCols;
      final dayHeight = (_calendarBottom - _calendarTop) / gridRows;

      // Temporary Map: (Row, Col) -> List<Block>
      final gridCells = <int, Map<int, List<EnhancedTextBlock>>>{};

      int droppedBlocks = 0;
      for (final block in blocks) {
         // Step 1: Normalize Coordinates
         final normX = block.centerX / block.pageSize.width;
         final normY = block.centerY / block.pageSize.height;
         
         // Debug print for significant blocks
         if (block.looksLikeDay || block.text.contains('Report')) {
             print('Block "${block.text}" at ($normX, $normY)');
         }

         // Filter out potential headers/footers outside grid
         if (normY < _calendarTop - 0.02 || normY > 0.98) {
             droppedBlocks++;
             continue;
         }

         // Step 3: Determine Column
         if (normX < _calendarLeft || normX > _calendarRight) {
             droppedBlocks++;
             continue;
         }
         
         int col = ((normX - _calendarLeft) / dayWidth).floor();
         col = col.clamp(0, _gridCols - 1);

         // Step 3: Determine Row
         // We allow small vertical overflow (tolerance)
         // Actually, "Center Point" strategy handles this mostly well. 
         // If center is in Row 1, it's Row 1.
         double relativeY = (normY - _calendarTop);
         int row = (relativeY / dayHeight).floor();
         
         if (row < 0) {
             droppedBlocks++;
             continue; // Too high up (header?)
         }
         if (row >= gridRows) {
             // If it's just barely below the last row, maybe include it?
             // But usually footer.
             droppedBlocks++;
             continue;
         }

         gridCells.putIfAbsent(row, () => {}).putIfAbsent(col, () => []).add(block);
      }
      print('Grid Assignment: Dropped $droppedBlocks blocks outside grid boundaries.');

      // Step 4: Process each Cell
      int cellsProcessed = 0;
      int cellsWithDates = 0;
      
      for (int r = 0; r < gridRows; r++) {
         if (!gridCells.containsKey(r)) continue;
         for (int c = 0; c < _gridCols; c++) {
              final cellBlocks = gridCells[r]?[c];
              if (cellBlocks == null || cellBlocks.isEmpty) continue;
              
              cellsProcessed++;

              // Step 5: De-Mix Content (Sort Y then X)
              cellBlocks.sort((a, b) {
                  double nyA = a.centerY / a.pageSize.height;
                  double nyB = b.centerY / b.pageSize.height;
                  if ((nyA - nyB).abs() > 0.01) return nyA.compareTo(nyB); // Significant Y diff
                  return a.centerX.compareTo(b.centerX);
              });
              
              // Determine Date for this cell
              // Search for day number in the top-left or top-most block
              DateTime? cellDate = _findDateInCell(cellBlocks, year, month);
              
              if (cellDate != null) {
                  days.add(TableRow(
                      blocks: cellBlocks,
                      averageY: 0, // Not used
                      associatedDate: cellDate
                  ));
                  cellsWithDates++;
                  print('Cell [$r,$c] -> Date: $cellDate. Events: ${cellBlocks.length}');
              } else {
                  print('Cell [$r,$c] -> No Date Found. Blocks: ${cellBlocks.map((b) => b.text).toList()}');
              }
         }
      }
      
      print('Grid Result: $cellsProcessed cells populated, $cellsWithDates valid days found.');
      return days;
  }

  DateTime? _findDateInCell(List<EnhancedTextBlock> blocks, int year, int month) {
      // 1. Look for explicit Date Pattern "Nov. 30" or "01"
      final datePattern = RegExp(r'^([A-Za-z]{3})\.?\s*(\d{1,2})');
      final dayPattern = RegExp(r'^(\d{1,2})$');
      
      // Check the first few blocks (usually date is at top)
      for (final block in blocks.take(3)) {
          String text = block.text.trim();
          
          // "Nov. 30"
          final matchFull = datePattern.firstMatch(text);
          if (matchFull != null) {
             String mStr = matchFull.group(1)!.toUpperCase().substring(0,3);
             int d = int.parse(matchFull.group(2)!);
             int m = _getMonthNumber(mStr) ?? month;
             
             // Handle Year Rollover
             int y = year;
             if (month == 12 && m == 1) {
               y++;
             } else if (month == 1 && m == 12) {
               y--;
             }
             
             return DateTime(y, m, d);
          }
          
          // "30"
          final matchDay = dayPattern.firstMatch(text);
          if (matchDay != null) {
              int d = int.parse(matchDay.group(1)!);
              if (d >= 1 && d <= 31) {
                  return DateTime(year, month, d);
              }
          }
          
          // "19 Report..." (Loose Start)
           final looseMatch = RegExp(r'^(\d{1,2})(\s+|$)').firstMatch(text);
           if (looseMatch != null) {
              int d = int.parse(looseMatch.group(1)!);
               if (d >= 1 && d <= 31) {
                  return DateTime(year, month, d);
              }
           }
      }
      return null;
  }
  
  int? _getMonthNumber(String abbr) {
      const map = {
      'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
      'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12
    };
    return map[abbr];
  }
}