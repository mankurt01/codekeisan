import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

List<dynamic> parseDailyDutiesForTest(String text) {
  final state = PdfUploadScreenStateTest();
  return state.parseDailyDuties(text);
}

List<dynamic> extractOffDaysForTest(String text) {
  final state = PdfUploadScreenStateTest();
  return state.extractOffDays(text);
}

class PdfUploadScreenStateTest {
  List<dynamic> parseDailyDuties(String text) {
    List<String> lines = text.split('\n');
    List duties = [];
    final condensedPattern = RegExp(r'^~?\s*(\d{2}:\d{2})\s+([A-Z]{3,6})\s+(\d{2}:\d{2})?(SB\d+|XQ\d+)?', caseSensitive: false);
    final flightCodePattern = RegExp(r'^[A-Z]{2}\d{3,4}');
    final offPattern = RegExp(r'^OFF\.?$', caseSensitive: false);
    String? currentDate;
    List<String> currentDuties = [];
    for (int i = 0; i < lines.length; i++) {
      String trimmed = lines[i].trim();
      if (trimmed.isEmpty) continue;
      if (offPattern.hasMatch(trimmed)) {
        if (currentDate != null) {
          duties.add({'date': currentDate, 'duties': currentDuties.isEmpty ? ['OFF'] : List.from(currentDuties)});
          currentDuties.clear();
        }
        currentDate = 'OFF';
        continue;
      }
      if (condensedPattern.hasMatch(trimmed)) {
        if (currentDate != null) {
          duties.add({'date': currentDate, 'duties': List.from(currentDuties)});
          currentDuties.clear();
        }
        currentDate = trimmed;
        continue;
      }
      if (flightCodePattern.hasMatch(trimmed)) {
        currentDuties.add(trimmed);
        continue;
      }
      if (currentDate != null) {
        currentDuties.add(trimmed);
      }
    }
    if (currentDate != null) {
      duties.add({'date': currentDate, 'duties': currentDuties.isEmpty ? ['OFF'] : List.from(currentDuties)});
    }
    return duties;
  }
  List<dynamic> extractOffDays(String text) {
    List<Map<String, dynamic>> offDays = [];
    final lines = text.split('\n');
    final offPatterns = [
      'OFF', 'OFF.', 'OFFB', 'BDAY', 'AVAC', 'Vac', 'COMM'
    ];
    final offPatternRegex = RegExp(r'^OFF\.?$', caseSensitive: false);
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (offPatternRegex.hasMatch(line)) {
        offDays.add({'type': 'OFF', 'line': i, 'raw': line});
        continue;
      }
      for (final pattern in offPatterns) {
        if (line.contains(pattern)) {
          offDays.add({'type': pattern, 'line': i, 'raw': line});
          break;
        }
      }
    }
    return offDays;
  }
}

void main() {
  test('Parse orcun.pdf extracted text', () async {
    final file = File('orcun.pdf');
    final lines = await file.readAsLines();
    final sampleText = lines.join('\n');
    final duties = parseDailyDutiesForTest(sampleText);
    final offDays = extractOffDaysForTest(sampleText);
    print('Duties:');
    for (var entry in duties) {
      print('${entry['date']}: ${entry['duties']}');
    }
    print('OffDays:');
    for (var off in offDays) {
      print(off);
    }
  });
}
