import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalendarExportService {
  /// Generate ICS calendar file content for off days and layovers
  static String _generateICSContent(
    List<Map<String, dynamic>> offDays,
    List<Map<String, dynamic>> layovers,
    String rosterPeriod,
    String? crewIdentifier,
  ) {
    final StringBuffer ics = StringBuffer();
    final timestamp = DateTime.now().toUtc();
    final formattedTimestamp = '${timestamp.toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.')[0]}Z';
    
    // ICS Header
    ics.writeln('BEGIN:VCALENDAR');
    ics.writeln('VERSION:2.0');
    final crewPrefix = crewIdentifier != null ? '[$crewIdentifier] ' : '';
    ics.writeln('PRODID:-//Crew Roster Analyzer//Off Days Calendar//EN');
    ics.writeln('CALSCALE:GREGORIAN');
    ics.writeln('METHOD:PUBLISH');
    ics.writeln('X-WR-CALNAME:${crewPrefix}Crew Schedule - $rosterPeriod');
    ics.writeln('X-WR-CALDESC:Off days and layovers for crew ${crewIdentifier ?? 'Unknown'} - roster period $rosterPeriod');
    
    // Add off days as all-day events
    for (int i = 0; i < offDays.length; i++) {
      final offDay = offDays[i];
      final date = DateTime.parse(offDay['date']);
      final dateStr = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
      final uid = 'offday-$dateStr-$i@crewroster';
      
      ics.writeln('BEGIN:VEVENT');
      ics.writeln('UID:$uid');
      ics.writeln('DTSTAMP:$formattedTimestamp');
      ics.writeln('DTSTART;VALUE=DATE:$dateStr');
      ics.writeln('DTEND;VALUE=DATE:$dateStr');
      ics.writeln('SUMMARY:$crewPrefix${offDay['type']} - ${offDay['description']}');
      ics.writeln('DESCRIPTION:Off day from crew roster: ${offDay['description']}\\nDay: ${offDay['dayName']}\\nCrew: ${crewIdentifier ?? 'Unknown'}');
      ics.writeln('CATEGORIES:PERSONAL,OFF_DAYS');
      ics.writeln('TRANSP:TRANSPARENT');
      ics.writeln('STATUS:CONFIRMED');
      ics.writeln('END:VEVENT');
    }
    
    // Add layovers as all-day events
    for (int i = 0; i < layovers.length; i++) {
      final layover = layovers[i];
      final date = DateTime.parse(layover['date']);
      final dateStr = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
      final uid = 'layover-$dateStr-$i@crewroster';
      
      ics.writeln('BEGIN:VEVENT');
      ics.writeln('UID:$uid');
      ics.writeln('DTSTAMP:$formattedTimestamp');
      ics.writeln('DTSTART;VALUE=DATE:$dateStr');
      ics.writeln('DTEND;VALUE=DATE:$dateStr');
      ics.writeln('SUMMARY:${crewPrefix}Layover in ${layover['cityCode']}');
      ics.writeln('DESCRIPTION:${layover['description']} - ${layover['layoverId']}\\nDay: ${layover['dayName']}\\nCrew: ${crewIdentifier ?? 'Unknown'}');
      ics.writeln('CATEGORIES:WORK,LAYOVER');
      ics.writeln('TRANSP:TRANSPARENT');
      ics.writeln('STATUS:CONFIRMED');
      ics.writeln('LOCATION:${layover['cityCode']}');
      ics.writeln('END:VEVENT');
    }
    
    // ICS Footer
    ics.writeln('END:VCALENDAR');
    
    return ics.toString();
  }

  /// Export off days and layovers to calendar
  static Future<bool> exportToCalendar({
    required BuildContext context,
    required List<Map<String, dynamic>> offDays,
    required List<Map<String, dynamic>> layovers,
    required String rosterPeriod,
  }) async {
    try {
      if (offDays.isEmpty && layovers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No off days or layovers to export'),
            backgroundColor: Colors.orange,
          ),
        );
        return false;
      }
      
      // Get crew identifier from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final crewIdentifier = prefs.getString('user_identifier_code');
      
      final icsContent = _generateICSContent(offDays, layovers, rosterPeriod, crewIdentifier);
      
      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final sanitizedPeriod = rosterPeriod.replaceAll(RegExp(r'[^\w\-]'), '_');
      final file = File('${directory.path}/crew_schedule_$sanitizedPeriod.ics');
      
      // Write ICS content to file
      await file.writeAsString(icsContent, encoding: utf8);
      
      // Share the file
      final crewPrefix = crewIdentifier != null ? '[$crewIdentifier] ' : '';
            // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '${crewPrefix}Crew Schedule - Off Days & Layovers ($rosterPeriod)',
        text: 'Import this .ics file to your calendar app (iOS Calendar, Google Calendar, Outlook, etc.) to see your off days and layovers.\n\n'
              '👨‍✈️ Crew: ${crewIdentifier ?? 'Unknown'}\n'
              '📅 Off Days: ${offDays.length}\n'
              '🌍 Layovers: ${layovers.length}\n'
              '📋 Total Events: ${offDays.length + layovers.length}\n\n'
              'You can share this calendar with family and friends through your calendar app\'s sharing settings.',
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Calendar exported! ${offDays.length} off days, ${layovers.length} layovers',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
      return true;
      
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  /// Extract detailed layover information from PDF text
  static List<Map<String, dynamic>> extractLayoverDetails(String text, String rosterPeriod) {
    List<Map<String, dynamic>> layovers = [];
    final lines = text.split('\n');
    
    // First pass: Find H1, H2 patterns and their associated cities
    for (final line in lines) {
      final trimmedLine = line.trim();
      
      // Match patterns like "H1 CGN" or "H2 EZS" with date context
      final layoverMatch = RegExp(r'([A-Za-z]{3})(\d{1,2}).*?(H\d{1,2})\s+([A-Z]{3})').firstMatch(trimmedLine);
      if (layoverMatch != null) {
        final dayName = layoverMatch.group(1)!;
        final dayNumber = int.parse(layoverMatch.group(2)!);
        final layoverId = layoverMatch.group(3)!;
        final cityCode = layoverMatch.group(4)!;
        
        final layoverDate = _parseDate(rosterPeriod, dayNumber);
        
        if (layoverDate != null) {
          layovers.add({
            'date': layoverDate.toIso8601String(),
            'dayName': dayName,
            'cityCode': cityCode,
            'layoverId': layoverId,
            'description': 'Layover in $cityCode',
          });
        }
      }
    }
    
    // Sort by date
    layovers.sort((a, b) => a['date'].compareTo(b['date']));
    
    return layovers;
  }

  /// Parse date based on roster period
  static DateTime? _parseDate(String rosterPeriod, int dayNumber) {
    if (rosterPeriod.isEmpty) return null;
    
    // Parse roster period like "01Jan25-31Jan25" or "01Mar25-31Mar25"
    final periodRegex = RegExp(r'(\d{2})([A-Za-z]{3})(\d{2})-(\d{2})([A-Za-z]{3})(\d{2})');
    final match = periodRegex.firstMatch(rosterPeriod);
    
    if (match == null) return null;
    
    final startMonthStr = match.group(2)!;
    final yearStr = match.group(3)!;
    
    // Convert month string to number
    final monthMap = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
    };
    
    final month = monthMap[startMonthStr];
    if (month == null) return null;
    
    // Convert 2-digit year to 4-digit year (assuming 20xx)
    final year = 2000 + int.parse(yearStr);
    
    try {
      return DateTime(year, month, dayNumber);
    } catch (e) {
      return null;
    }
  }

  /// Get city name from airport code (basic mapping)
  static String getCityName(String airportCode) {
    final cityMap = {
      'CGN': 'Cologne',
      'EZS': 'Elazig',
      'IST': 'Istanbul',
      'SAW': 'Istanbul Sabiha',
      'ADB': 'Izmir',
      'AYT': 'Antalya',
      'ESB': 'Ankara',
      'TZX': 'Trabzon',
      'KYA': 'Konya',
      'MLX': 'Malatya',
      'VAN': 'Van',
      'BJV': 'Bodrum',
      'GZT': 'Gaziantep',
      'DIY': 'Diyarbakir',
      'SZF': 'Samsun',
      'KFS': 'Kastamonu',
      // Add more as needed
    };
    
    return cityMap[airportCode] ?? airportCode;
  }
}
