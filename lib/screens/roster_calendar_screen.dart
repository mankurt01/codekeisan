import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:icalendar_parser/icalendar_parser.dart';
import '../services/data_service.dart';
import '../services/layover_service.dart';
import '../models/layover_event.dart';
import '../constants/salary_rates.dart';

class RosterCalendarScreen extends StatefulWidget {
  const RosterCalendarScreen({super.key});

  @override
  State<RosterCalendarScreen> createState() => _RosterCalendarScreenState();
}

class _RosterCalendarScreenState extends State<RosterCalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _events = {};
  List<LayoverEvent> _layovers = [];
  String _userId = 'current_user'; // This would come from your auth service

  @override
  void initState() {
    super.initState();
    _loadIcsData();
  }

  Future<void> _loadIcsData() async {
    try {
      debugPrint('🔄 Starting ICS data loading...');
      final dataService = DataService();
      
      // Get roster history and find the latest entry with rawText
      final rosterHistory = await dataService.getRosterHistory();
      debugPrint('📚 Found ${rosterHistory.length} entries in roster history');
      
      // Find the latest entry that has rawText
      String? icsString;
      String? sourceFileName;
      
      for (int i = 0; i < rosterHistory.length; i++) {
        final result = rosterHistory.reversed.elementAt(i);
        debugPrint('📄 Checking entry ${i + 1}: ${result.fileName} (rawText: ${result.rawText?.length ?? 0} chars)');
        if (result.rawText != null && result.rawText!.isNotEmpty) {
          icsString = result.rawText;
          sourceFileName = result.fileName;
          debugPrint('✅ Selected ICS source: $sourceFileName');
          break;
        }
      }
      
      if (icsString == null || icsString.isEmpty) {
        debugPrint('❌ No ICS data found in roster history');
        return;
      }
      
      debugPrint('📊 Loading ICS from: $sourceFileName, length: ${icsString.length} chars');

      final iCalendar = ICalendar.fromString(icsString);
      debugPrint('✅ Parsed ICalendar with ${iCalendar.data.length} components');

      // Debug: Log all components
      int veventCount = 0;
      for (final component in iCalendar.data) {
        if (component['type'] == 'VEVENT') {
          veventCount++;
          final uid = component['uid'] as String? ?? 'NO_UID';
          final summary = component['summary'] as String? ?? 'NO_SUMMARY';
          debugPrint('📅 VEVENT $veventCount: $summary ($uid)');
        }
      }

      final parsedEvents = _parseEvents(iCalendar);
      final calculatedLayovers = _calculateLayovers(iCalendar);
      
      setState(() {
        _events = parsedEvents;
        _layovers = calculatedLayovers;
      });
      
      debugPrint('✅ Events parsing completed:');
      debugPrint('   📅 Events on ${_events.length} different dates');
      debugPrint('   🏨 Layovers calculated: ${_layovers.length}');
      
      // Debug: Log events by date
      for (final entry in _events.entries) {
        final dateStr = '${entry.key.day}/${entry.key.month}/${entry.key.year}';
        debugPrint('   📆 $dateStr: ${entry.value.length} events');
        for (final event in entry.value) {
          debugPrint('     - ${event['summary']} (${event['uid']})');
        }
      }
      
      // Debug: Log layovers
      for (final layover in _layovers) {
        debugPrint('   🏨 Layover: ${layover.toString()}');
      }
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading ICS: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Map<DateTime, List<dynamic>> _parseEvents(ICalendar iCalendar) {
    final events = <DateTime, List<dynamic>>{};
    int eventCount = 0;

    for (final component in iCalendar.data) {
      if (component['type'] == 'VEVENT') {
        final dtstart = component['dtstart'];
        if (dtstart != null) {
          DateTime? startDate = _parseEventDateTime(dtstart, component);
          
          if (startDate != null) {
            final date = DateTime(startDate.year, startDate.month, startDate.day);
            if (events[date] == null) {
              events[date] = [];
            }
            events[date]!.add(component);
            eventCount++;
            debugPrint('Added event on $date: ${component['summary']} (${component['uid']})');
          }
        }
      }
    }

    debugPrint('Total events parsed: $eventCount');
    return events;
  }

  /// Enhanced datetime parsing for various ICS formats
  DateTime? _parseEventDateTime(dynamic dtstart, Map<String, dynamic> component) {
    try {
      DateTime? startDate;
      
      if (dtstart.dt is DateTime) {
        startDate = dtstart.dt;
        debugPrint('DateTime object: $startDate');
      } else if (dtstart.dt is String) {
        String dateString = dtstart.dt;
        debugPrint('Parsing date string: $dateString');
        
        // Handle various ICS datetime formats
        if (dateString.contains('T')) {
          // ISO format with time: 20260228T210000Z
          if (dateString.endsWith('Z')) {
            startDate = DateTime.parse(dateString);
          } else {
            // Try parsing without Z
            startDate = DateTime.parse(dateString);
          }
        } else if (dateString.length == 8) {
          // Date only format: 20260228
          final year = int.parse(dateString.substring(0, 4));
          final month = int.parse(dateString.substring(4, 6));
          final day = int.parse(dateString.substring(6, 8));
          startDate = DateTime(year, month, day);
        } else {
          // Fallback to standard parsing
          startDate = DateTime.parse(dateString);
        }
        debugPrint('Successfully parsed: $dateString -> $startDate');
      }
      
      return startDate;
    } catch (e) {
      debugPrint('Error parsing datetime for event ${component['uid']}: $e');
      debugPrint('Raw dtstart: $dtstart');
      return null;
    }
  }

  List<LayoverEvent> _calculateLayovers(ICalendar iCalendar) {
    try {
      // Convert ICalendar components to the format expected by LayoverService
      final eventList = <Map<String, dynamic>>[];
      
      for (final component in iCalendar.data) {
        if (component['type'] == 'VEVENT') {
          eventList.add(component);
        }
      }
      
      // Extract layovers using the LayoverService
      return LayoverService.extractLayoversFromEvents(eventList, _userId);
    } catch (e) {
      debugPrint('Error calculating layovers: $e');
      return [];
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  List<LayoverEvent> _getLayoversForDay(DateTime day) {
    final targetDate = DateTime(day.year, day.month, day.day);
    return _layovers.where((layover) {
      final layoverDate = DateTime(layover.date.year, layover.date.month, layover.date.day);
      return layoverDate.isAtSameMomentAs(targetDate);
    }).toList();
  }

  /// Returns the primary event type for a day for color-coding.
  /// Priority: FLY > STANDBY > OFF > null
  String? _getDayEventType(DateTime day) {
    final dayEvents = _getEventsForDay(day);
    if (dayEvents.isEmpty) return null;
    bool hasFly = false;
    bool hasStandby = false;
    bool hasOff = false;
    for (final e in dayEvents) {
      final s = (e['summary'] as String? ?? '');
      if (s.startsWith('FLY')) hasFly = true;
      if (s.startsWith('STANDBY')) hasStandby = true;
      if (s.startsWith('OFF')) hasOff = true;
    }
    if (hasFly) return 'FLY';
    if (hasStandby) return 'STANDBY';
    if (hasOff) return 'OFF';
    return null;
  }

  Color _eventTypeColor(String? type, {double opacity = 0.35}) {
    switch (type) {
      case 'FLY':
        return const Color(0xFFED6C02).withValues(alpha: opacity);
      case 'STANDBY':
        return const Color(0xFFFFD600).withValues(alpha: opacity);
      case 'OFF':
        return const Color(0xFF4CAF50).withValues(alpha: opacity);
      default:
        return Colors.white.withValues(alpha: 0.08);
    }
  }

  /// Compute monthly summary stats for the currently focused month.
  Map<String, dynamic> _getMonthlySummary(DateTime month) {
    int flyDays = 0;
    int standbyDays = 0;
    int offDays = 0;
    int totalDutyMinutes = 0;

    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    for (DateTime d = start;
        !d.isAfter(end);
        d = d.add(const Duration(days: 1))) {
      final type = _getDayEventType(d);
      if (type == 'FLY') flyDays++;
      if (type == 'STANDBY') standbyDays++;
      if (type == 'OFF') offDays++;

      // Accumulate duty minutes
      final dayEvents = _getEventsForDay(d);
      for (final event in dayEvents) {
        final summary = (event['summary'] as String? ?? '');
        if (!summary.startsWith('FLY') && !summary.startsWith('STANDBY')) {
          continue;
        }
        final desc =
            (event['description'] as String? ?? '').replaceAll('\\n', '\n');
        final lines = desc.split('\n');
        String? checkIn;
        String? release;
        for (final line in lines) {
          final t = line.trim();
          final ci = RegExp(r'Check-in\s*(\d{2}:\d{2})').firstMatch(t);
          if (ci != null) checkIn = ci.group(1);
          final rel = RegExp(r'Release\s*(\d{2}:\d{2})').firstMatch(t);
          if (rel != null) release = rel.group(1);
        }
        if (checkIn != null && release != null) {
          final ci = _timeToMinutes(checkIn);
          final rel = _timeToMinutes(release);
          if (ci != null && rel != null) {
            int dur = rel - ci;
            if (dur < 0) dur += 24 * 60;
            if (summary.startsWith('STANDBY')) dur = (dur * 0.25).round();
            totalDutyMinutes += dur;
          }
        }
      }
    }
    return {
      'flyDays': flyDays,
      'standbyDays': standbyDays,
      'offDays': offDays,
      'dutyTime': _formatTime(totalDutyMinutes),
    };
  }

  Widget _buildMonthlySummary() {
    final summary = _getMonthlySummary(_focusedDay);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryChip('✈️', '${summary['flyDays']}', 'FLY',
              const Color(0xFFED6C02)),
          _buildSummaryChip('🟡', '${summary['standbyDays']}', 'SB',
              const Color(0xFFFFD600)),
          _buildSummaryChip('🟢', '${summary['offDays']}', 'OFF',
              const Color(0xFF4CAF50)),
          _buildSummaryChip(
              '⏱️', '${summary['dutyTime']}', 'DUTY', Colors.white70),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(
      String emoji, String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
              color: color, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style:
              TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        title: Text(
          'Roster Takvimi',
          style: TextStyle(
            color: Color(0xFFED6C02),
            fontSize: 24,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline, size: 22, color: Colors.orange[300]),
            tooltip: 'Yardım',
            onPressed: () => _showHelpDialog(context),
          ),
          IconButton(
            icon: Icon(Icons.home, size: 22, color: Colors.orange[300]),
            tooltip: 'Ana Sayfa',
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromRGBO(21, 123, 163, 1.0),
              Color.fromRGBO(146, 74, 26, 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 100),
            _buildMonthlySummary(),
            TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                final eventsForDay = _getEventsForDay(selectedDay);
                debugPrint('Selected day: $selectedDay, events: ${eventsForDay.length}');
                for (final event in eventsForDay) {
                  debugPrint('Event: ${event['summary']} - ${event['description']}');
                }
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                });
              },
              eventLoader: _getEventsForDay,
              calendarStyle: const CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Color(0xFFED6C02),
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: Colors.white,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: Colors.white,
                ),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Colors.white70),
                weekendStyle: TextStyle(color: Colors.white70),
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  final eventType = _getDayEventType(day);
                  final bgColor = _eventTypeColor(eventType);
                  return Container(
                    margin: const EdgeInsets.all(3.0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8.0),
                      border: eventType != null
                          ? Border.all(
                              color: _eventTypeColor(eventType, opacity: 0.7),
                              width: 1.2)
                          : null,
                    ),
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        color: eventType != null
                            ? Colors.white
                            : Colors.white60,
                        fontSize: 13,
                        fontWeight: eventType != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  );
                },
                todayBuilder: (context, day, focusedDay) {
                  return Container(
                    margin: const EdgeInsets.all(3.0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Text(
                      '${day.day}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  );
                },
                selectedBuilder: (context, day, focusedDay) {
                  return Container(
                    margin: const EdgeInsets.all(3.0),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFED6C02),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${day.day}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8.0),
            Expanded(
              child: _selectedDay != null
                  ? _buildEventList(_getEventsForDay(_selectedDay!), _getLayoversForDay(_selectedDay!))
                  : const Center(
                      child: Text(
                        'Bir tarih seçin',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventList(List<dynamic> events, List<LayoverEvent> layovers) {
    // Include FLY, STANDBY, and NON-FLY events
    final dutyEvents = events.where((event) {
      final summary = (event['summary'] as String? ?? '');
      return summary.startsWith('FLY') || summary.startsWith('STANDBY');
    }).toList();

    // Separate NON-FLY events (hotel/transport)
    final nonFlyEvents = events.where((event) {
      final summary = (event['summary'] as String? ?? '');
      return summary.startsWith('NON-FLY');
    }).toList();

    // Also include OFF events for visibility
    final offEvents = events.where((event) {
      final summary = (event['summary'] as String? ?? '');
      return summary.startsWith('OFF');
    }).toList();

    if (dutyEvents.isEmpty && layovers.isEmpty && nonFlyEvents.isEmpty && offEvents.isEmpty) {
      return const Center(
        child: Text(
          'Bu tarihte etkinlik yok',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    // Combine all events and layovers
    final totalItems = dutyEvents.length + nonFlyEvents.length + offEvents.length + layovers.length;

    return ListView.builder(
      itemCount: totalItems,
      itemBuilder: (context, index) {
        if (index < dutyEvents.length) {
          // Display duty event (FLY/STANDBY)
          final event = dutyEvents[index];
          final summary = (event['summary'] as String? ?? '');
          return Card(
            color: Colors.white.withAlpha(26),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: summary.startsWith('FLY')
                  ? _buildFlyEventContent(event)
                  : _buildStandbyEventContent(event),
            ),
          );
        } else if (index < dutyEvents.length + nonFlyEvents.length) {
          // Display NON-FLY event (hotel/transport)
          final nonFlyIndex = index - dutyEvents.length;
          final event = nonFlyEvents[nonFlyIndex];
          return Card(
            color: Colors.purple.withAlpha(40),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildNonFlyEventContent(event),
            ),
          );
        } else if (index < dutyEvents.length + nonFlyEvents.length + offEvents.length) {
          // Display OFF event
          final offIndex = index - dutyEvents.length - nonFlyEvents.length;
          final event = offEvents[offIndex];
          return Card(
            color: Colors.green.withAlpha(40),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildOffEventContent(event),
            ),
          );
        } else {
          // Display layover event
          final layoverIndex = index - dutyEvents.length - nonFlyEvents.length - offEvents.length;
          final layover = layovers[layoverIndex];
          return Card(
            color: Colors.orange.withAlpha(40),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildLayoverContent(layover),
            ),
          );
        }
      },
    );
  }

  Widget _buildLayoverContent(LayoverEvent layover) {
    final startTime = '${layover.layoverStartTime.hour.toString().padLeft(2, '0')}:${layover.layoverStartTime.minute.toString().padLeft(2, '0')}';
    final endTime = '${layover.reportingTime.hour.toString().padLeft(2, '0')}:${layover.reportingTime.minute.toString().padLeft(2, '0')}';
    final duration = LayoverService.formatDuration(layover.layoverDuration);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.hotel,
              color: Colors.orange,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'LAYOVER (${layover.location})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Layover Start   $startTime',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        Text(
          'Next Reporting  $endTime',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Text(
          'Duration : $duration',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        Text(
          'Type : ${layover.layoverType} (${layover.isInternational ? 'International' : 'Domestic'})',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        Text(
          'Payment : €${layover.paymentAmount.toStringAsFixed(2)}',
          style: const TextStyle(
            color: Colors.orange,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color.fromRGBO(21, 123, 163, 1.0),
                Color.fromRGBO(146, 74, 26, 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange[800],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.help_outline, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Roster Takvimi Nasıl Kullanılır?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHelpSection(
                        '📅 Genel Bakış',
                        'Bu sayfa roster takviminizi gösterir. ICS dosyasından yüklenen etkinlikleri takvim formatında görüntüler.',
                      ),
                      const SizedBox(height: 16),
                      _buildHelpSection(
                        '👆 Etkileşim',
                        '• Tarihleri tıklayarak o günün etkinliklerini görüntüleyin\n• Takvim formatını değiştirmek için üstteki butonları kullanın',
                      ),
                      const SizedBox(height: 16),
                      _buildHelpSection(
                        '📊 Görüntülenen Bilgiler',
                        '• Etkinlik başlığı ve açıklaması\n• Seçilen tarihin etkinlik listesi',
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  top: 16.0,
                  bottom: 24.0,
                  left: 24.0,
                  right: 24.0,
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFED6C02),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    'Anladım',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.orange,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildFlyEventContent(dynamic event) {
    final summary = event['summary'] as String? ?? '';
    final rawDescription = event['description'] as String? ?? '';
    final description = rawDescription.replaceAll('\\n', '\n');

    // Extract route from summary: FLY (AYT) or FLY (AYT-EZS-AYT)
    final routeMatch = RegExp(r'FLY \(([^)]+)\)').firstMatch(summary);
    final routeLabel =
        routeMatch != null ? routeMatch.group(1)! : 'Unknown Route';

    // ── Parse description into day-segments ─────────────────────────────────
    // A date header looks like:  "Mon, 20 Jul 2026"
    final dateHeaderRegex = RegExp(
      r'^(Mon|Tue|Wed|Thu|Fri|Sat|Sun),\s+\d+\s+\w+\s+\d{4}',
      caseSensitive: false,
    );

    final segments = <Map<String, dynamic>>[]; // {header, lines}
    Map<String, dynamic>? currentSeg;

    for (final rawLine in description.split('\n')) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty || trimmed.startsWith('- - -')) continue;

      if (dateHeaderRegex.hasMatch(trimmed)) {
        if (currentSeg != null) segments.add(currentSeg);
        currentSeg = {'header': trimmed, 'lines': <String>[]};
        continue;
      }

      if (currentSeg != null) {
        (currentSeg!['lines'] as List<String>).add(trimmed);
      } else {
        // Lines before first date header (e.g. preamble)
        currentSeg = {'header': null, 'lines': <String>[trimmed]};
      }
    }
    if (currentSeg != null) segments.add(currentSeg!);

    // Collect all flight legs for totals
    final allFlightLegs = <Map<String, String>>[];
    String? firstCheckIn;
    String? lastRelease;
    final flightRegex =
        RegExp(r'^\w+\s+(\d{2}:\d{2})\s+(\d{2}:\d{2})\s*(.+?)\s+(\w+)\s*$');

    for (final seg in segments) {
      for (final line in seg['lines'] as List<String>) {
        final ci = RegExp(r'Check-in\s*(\d{2}:\d{2})').firstMatch(line);
        if (ci != null) firstCheckIn ??= ci.group(1);
        final rel = RegExp(r'Release\s*(\d{2}:\d{2})').firstMatch(line);
        if (rel != null) lastRelease = rel.group(1);
        final fm = flightRegex.firstMatch(line);
        if (fm != null) {
          allFlightLegs.add({
            'route': fm.group(3)!.trim(),
            'departure': fm.group(1)!,
            'arrival': fm.group(2)!,
          });
        }
      }
    }

    final flightTime = _calculateFlightTime(allFlightLegs);
    final dutyTime = _calculateDutyTime(firstCheckIn, lastRelease);
    final nightDuty = _calculateNightDuty(firstCheckIn, lastRelease);
    final totalDutyTime = _calculateTotalDutyTimeUpToDate(_selectedDay!);
    final isMultiDay = segments.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Title bar ──────────────────────────────────────────────────────
        Row(
          children: [
            Icon(Icons.flight_takeoff,
                color: Colors.orange[300], size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'UÇUŞ ($routeLabel)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isMultiDay)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.5), width: 1),
                ),
                child: Text(
                  '${segments.length} GÜN',
                  style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Day segments ───────────────────────────────────────────────────
        ...segments.map((seg) => _buildDayFlightSegment(seg, flightRegex)),

        const Divider(color: Colors.white24, height: 20),

        // ── Totals ─────────────────────────────────────────────────────────
        _buildInfoRow('✈️ Flight Time', flightTime, Colors.white),
        _buildInfoRow('🕒 Duty Time', dutyTime, Colors.white),
        _buildInfoRow('🌙 Night Duty', nightDuty, Colors.white70),
        _buildInfoRow(
            'Σ Toplam Duty', totalDutyTime, Colors.white70),
        const SizedBox(height: 8),
        _buildDaysWorthWidget(dutyTime, nightDuty, totalDutyTime),
      ],
    );
  }

  /// Renders one date-segment (one calendar day) of a FLY event.
  Widget _buildDayFlightSegment(
      Map<String, dynamic> seg, RegExp flightRegex) {
    final header = seg['header'] as String?;
    final lines = seg['lines'] as List<String>;

    // Classify lines
    String? checkIn;
    String? release;
    String? releaseAirport;
    final flightLegs = <Map<String, String>>[];
    String? transportLine;
    String? hotelName;
    String? hotelCheckin;
    String? hotelCheckout;
    String? hotelAddress;
    String? hotelPhone;
    String? transportCompany;
    String? transportPhone;
    bool inHotelBlock = false;
    bool transportPhoneParsed = false;

    for (final line in lines) {
      // Check-in
      final ciMatch = RegExp(r'^Check-in\s+(\d{2}:\d{2})\s*(\w{3})?')
          .firstMatch(line);
      if (ciMatch != null) {
        checkIn = ciMatch.group(1);
        inHotelBlock = false;
        continue;
      }
      // Release
      final relMatch =
          RegExp(r'^Release\s+(\d{2}:\d{2})\s*(\w{3})?').firstMatch(line);
      if (relMatch != null) {
        release = relMatch.group(1);
        releaseAirport = relMatch.group(2);
        inHotelBlock = false;
        continue;
      }
      // Flight leg
      final fm = flightRegex.firstMatch(line);
      if (fm != null) {
        flightLegs.add({
          'route': fm.group(3)!.trim(),
          'departure': fm.group(1)!,
          'arrival': fm.group(2)!,
        });
        inHotelBlock = false;
        continue;
      }
      // Transport
      final transMatch =
          RegExp(r'^Transport\s+(\d{2}:\d{2})\s+(\d{2}:\d{2})\s+(.+)')
              .firstMatch(line);
      if (transMatch != null) {
        if (transportCompany == null) {
          transportCompany = transMatch.group(3)!.trim();
          transportLine =
              '${transMatch.group(1)} → ${transMatch.group(2)}  $transportCompany';
        }
        inHotelBlock = false;
        continue;
      }
      // Hotel
      final hotelMatch =
          RegExp(r'^Hotel\s+(\d{2}:\d{2})\s+(\d{2}:\d{2})\s+(.+)')
              .firstMatch(line);
      if (hotelMatch != null) {
        hotelCheckin = hotelMatch.group(1);
        hotelCheckout = hotelMatch.group(2);
        hotelName = hotelMatch.group(3)!.trim();
        inHotelBlock = true;
        continue;
      }
      // Address (follows Hotel line)
      if (line.startsWith('Address:')) {
        hotelAddress = line.substring(8).trim();
        continue;
      }
      // Phone — could be transport phone or hotel phone
      final phoneMatch =
          RegExp(r'Phone:\s*([+\d\s\(\)\-]+)').firstMatch(line);
      if (phoneMatch != null) {
        final phone = phoneMatch.group(1)!.trim();
        if (inHotelBlock && hotelPhone == null) {
          hotelPhone = phone;
        } else if (!inHotelBlock && !transportPhoneParsed) {
          transportPhone = phone;
          transportPhoneParsed = true;
        }
        continue;
      }
    }

    // A real layover is indicated by hotel and/or transport data, or by a
    // release away from the crew home base. A bare "Release 18:30 AYT" on a
    // same-day round trip back to base (e.g. AYT-BTS-AYT) is NOT a layover
    // and must not render the layover card.
    final isAwayFromBase = releaseAirport != null &&
        releaseAirport.toUpperCase() != LayoverService.homeBase;
    final hasLayoverSection =
        hotelName != null || transportLine != null || isAwayFromBase;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        if (header != null) ...[
          Container(
            margin: const EdgeInsets.only(top: 6, bottom: 4),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              header,
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
        // Check-in
        if (checkIn != null)
          _buildInfoRow('Check-in', checkIn!, Colors.white70),
        // Flight legs
        ...flightLegs.map((leg) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.flight, color: Colors.white38, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${leg['route']}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                    ),
                  ),
                  Text(
                    '${leg['departure']} → ${leg['arrival']}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            )),
        // Release
        if (release != null)
          _buildInfoRow(
            releaseAirport != null
                ? 'Release ($releaseAirport)'
                : 'Release',
            release!,
            hasLayoverSection ? Colors.orange[300]! : Colors.white70,
          ),
        // Embedded layover section
        if (hasLayoverSection)
          _buildEmbeddedLayoverSection(
            hotelName: hotelName,
            hotelCheckin: hotelCheckin,
            hotelCheckout: hotelCheckout,
            hotelAddress: hotelAddress,
            hotelPhone: hotelPhone,
            transportLine: transportLine,
            transportPhone: transportPhone,
            location: releaseAirport,
          ),
      ],
    );
  }

  /// Renders the hotel + transport card for an embedded layover.
  Widget _buildEmbeddedLayoverSection({
    String? hotelName,
    String? hotelCheckin,
    String? hotelCheckout,
    String? hotelAddress,
    String? hotelPhone,
    String? transportLine,
    String? transportPhone,
    String? location,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.orange.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Row(
            children: [
              const Icon(Icons.hotel, color: Colors.orange, size: 16),
              const SizedBox(width: 6),
              Text(
                location != null
                    ? 'LAYOVER — $location'
                    : 'LAYOVER',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Transport
          if (transportLine != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.directions_car,
                    color: Colors.white54, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    transportLine!,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
            if (transportPhone != null)
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Text(
                  '📞 $transportPhone',
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            const SizedBox(height: 6),
          ],
          // Hotel
          if (hotelName != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.bed, color: Colors.white70, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hotelName!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (hotelCheckin != null && hotelCheckout != null)
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 2),
                child: Text(
                  'Check-in $hotelCheckin  →  Check-out $hotelCheckout',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            if (hotelAddress != null)
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 2),
                child: Text(
                  '📍 $hotelAddress',
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            if (hotelPhone != null)
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 2),
                child: Text(
                  '📞 $hotelPhone',
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: TextStyle(
                color: valueColor,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }



  Widget _buildStandbyEventContent(dynamic event) {
    final summary = event['summary'] as String? ?? '';
    final description = (event['description'] as String? ?? '').replaceAll('\\n', '\n');

    // Extract location from summary: STANDBY (JNB)
    final locationMatch = RegExp(r'STANDBY \(([^)]+)\)').firstMatch(summary);
    final location = locationMatch != null ? locationMatch.group(1)! : 'Unknown';

    // Parse description lines
    final lines = description.split('\n');
    String? checkInTime;
    String? releaseTime;
    String? standbyLine;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('Check-in')) {
        // Handle both "Check-in06:50" and "Check-in    06:50"
        final timeMatch = RegExp(r'Check-in\s*(\d{2}:\d{2})').firstMatch(trimmed);
        if (timeMatch != null) {
          checkInTime = timeMatch.group(1);
        }
      } else if (trimmed.startsWith('Release')) {
        // Handle both "Release     16:41" and "Release16:41"
        final timeMatch = RegExp(r'Release\s*(\d{2}:\d{2})').firstMatch(trimmed);
        if (timeMatch != null) {
          releaseTime = timeMatch.group(1);
        }
      } else if (trimmed.startsWith('Standby')) {
        standbyLine = trimmed;
      }
    }

    // Calculate duty time (25% of the period between check-in and release for STANDBY), night duty, and cumulative duty time.
    // Night duty is credited at 25% as well for STANDBY: e.g. an SBY window
    // of 00:00-10:00 overlaps 4h of the 22:00-03:00 night window, which
    // counts as 1h of night duty, not 4h.
    final dutyTime = _calculateStandbyDutyTimeFromCheckIn(checkInTime, releaseTime);
    final nightDuty = _calculateNightDuty(checkInTime, releaseTime, multiplier: 0.25);
    final totalDutyTime = _calculateTotalDutyTimeUpToDate(_selectedDay!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STANDBY ($location)',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (checkInTime != null)
          Text(
            'Check-in   $checkInTime',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        if (standbyLine != null)
          Text(
            standbyLine,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        if (releaseTime != null)
          Text(
            'Release     $releaseTime',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        const SizedBox(height: 8),
        Text(
          'Duty Time : $dutyTime',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        Text(
          'Night Duty : $nightDuty',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        Text(
          'Total Duty Time : $totalDutyTime',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        const SizedBox(height: 8),
        _buildDaysWorthWidget(dutyTime, nightDuty, totalDutyTime),
      ],
    );
  }

  String _calculateFlightTime(List<Map<String, String>> flightLegs) {
    int totalMinutes = 0;
    for (final leg in flightLegs) {
      final depMinutes = _timeToMinutes(leg['departure']!);
      final arrMinutes = _timeToMinutes(leg['arrival']!);
      if (depMinutes != null && arrMinutes != null) {
        int duration = arrMinutes - depMinutes;
        if (duration < 0) duration += 24 * 60; // Handle next day
        totalMinutes += duration;
      }
    }
    return _formatTime(totalMinutes);
  }

  String _calculateDutyTime(String? checkInTime, String? releaseTime) {
    if (checkInTime == null || releaseTime == null) return '00:00';
    final checkInMinutes = _timeToMinutes(checkInTime);
    final releaseMinutes = _timeToMinutes(releaseTime);
    if (checkInMinutes == null || releaseMinutes == null) return '00:00';
    int duration = releaseMinutes - checkInMinutes;
    if (duration < 0) duration += 24 * 60; // Handle next day
    return _formatTime(duration);
  }

  String _calculateStandbyTime(String? offTime, String? offEndTime) {
    if (offTime == null || offEndTime == null) return '00:00';

    final startMinutes = _timeToMinutes(offTime);
    if (startMinutes == null) return '00:00';

    // Parse offEndTime like "22:00/+1"
    int? endMinutes;
    if (offEndTime.contains('/+1')) {
      final timePart = offEndTime.split('/')[0];
      endMinutes = _timeToMinutes(timePart);
      if (endMinutes != null) {
        endMinutes += 24 * 60; // Add one day
      }
    } else {
      endMinutes = _timeToMinutes(offEndTime);
    }

    if (endMinutes == null) return '00:00';

    int duration = endMinutes - startMinutes;
    if (duration < 0) duration += 24 * 60; // Handle next day (though +1 should prevent this)

    return _formatTime(duration);
  }

  String _calculateStandbyDutyTime(String? offTime, String? offEndTime) {
    if (offTime == null || offEndTime == null) return '00:00';

    final startMinutes = _timeToMinutes(offTime);
    if (startMinutes == null) return '00:00';

    // Parse offEndTime like "22:00/+1"
    int? endMinutes;
    if (offEndTime.contains('/+1')) {
      final timePart = offEndTime.split('/')[0];
      endMinutes = _timeToMinutes(timePart);
      if (endMinutes != null) {
        endMinutes += 24 * 60; // Add one day
      }
    } else {
      endMinutes = _timeToMinutes(offEndTime);
    }

    if (endMinutes == null) return '00:00';

    int duration = endMinutes - startMinutes;
    if (duration < 0) duration += 24 * 60; // Handle next day (though +1 should prevent this)

    // Duty time is 25% of the period
    final dutyMinutes = (duration * 0.25).round();
    return _formatTime(dutyMinutes);
  }

  String _calculateStandbyDutyTimeFromCheckIn(String? checkInTime, String? releaseTime) {
    if (checkInTime == null || releaseTime == null) return '00:00';
    final checkInMinutes = _timeToMinutes(checkInTime);
    final releaseMinutes = _timeToMinutes(releaseTime);
    if (checkInMinutes == null || releaseMinutes == null) return '00:00';
    int duration = releaseMinutes - checkInMinutes;
    if (duration < 0) duration += 24 * 60; // Handle next day
    // Duty time is 25% of the period for STANDBY
    final dutyMinutes = (duration * 0.25).round();
    return _formatTime(dutyMinutes);
  }

  String _calculateNightDuty(String? checkInTime, String? releaseTime,
      {double multiplier = 1.0}) {
    if (checkInTime == null || releaseTime == null) return '00:00';
    final checkInMinutes = _timeToMinutes(checkInTime);
    final releaseMinutes = _timeToMinutes(releaseTime);
    if (checkInMinutes == null || releaseMinutes == null) return '00:00';

    int startMinutes = checkInMinutes;
    int endMinutes = releaseMinutes;
    if (endMinutes < startMinutes) endMinutes += 24 * 60; // Handle next day

    int nightMinutes = 0;
    int current = startMinutes;
    while (current < endMinutes) {
      final hour = (current ~/ 60) % 24;
      if (hour >= 22 || hour <= 3) {  // Night hours: 22:00 to 03:00
        nightMinutes++;
      }
      current++;
    }
    // [multiplier] lets STANDBY days credit only 25% of the overlapped
    // night window, consistent with the 25% standby duty credit.
    return _formatTime((nightMinutes * multiplier).round());
  }

  int? _timeToMinutes(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length == 2) {
      try {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        return hours * 60 + minutes;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  String _formatTime(int minutes) {
    final int hours = minutes ~/ 60;
    final int mins = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  String _calculateTotalDutyTimeUpToDate(DateTime selectedDate) {
    int totalMinutes = 0;
    
    // Start from the 1st of the selected month
    final monthStart = DateTime(selectedDate.year, selectedDate.month, 1);
    
    // Loop through each day from 1st to selected date (inclusive)
    for (DateTime date = monthStart; 
         date.isBefore(selectedDate) || date.isAtSameMomentAs(DateTime(selectedDate.year, selectedDate.month, selectedDate.day)); 
         date = date.add(const Duration(days: 1))) {
      
      final eventsForDay = _getEventsForDay(date);
      final dutyEvents = eventsForDay.where((event) {
        final summary = (event['summary'] as String? ?? '');
        return summary.startsWith('FLY') || summary.startsWith('STANDBY');
      }).toList();
      
      // Calculate duty time for each event on this day
      for (final event in dutyEvents) {
        final summary = (event['summary'] as String? ?? '');
        final description = (event['description'] as String? ?? '').replaceAll('\\n', '\n');
        
        String? checkInTime;
        String? releaseTime;
        
        // Parse check-in and release times from description
        final lines = description.split('\n');
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('Check-in')) {
            // Handle both "Check-in06:50" and "Check-in    06:50"
            final timeMatch = RegExp(r'Check-in\s*(\d{2}:\d{2})').firstMatch(trimmed);
            if (timeMatch != null) {
              checkInTime = timeMatch.group(1);
            }
          } else if (trimmed.startsWith('Release')) {
            // Handle both "Release     16:41" and "Release16:41"
            final timeMatch = RegExp(r'Release\s*(\d{2}:\d{2})').firstMatch(trimmed);
            if (timeMatch != null) {
              releaseTime = timeMatch.group(1);
            }
          }
        }
        
        if (checkInTime != null && releaseTime != null) {
          final checkInMinutes = _timeToMinutes(checkInTime);
          final releaseMinutes = _timeToMinutes(releaseTime);
          
          if (checkInMinutes != null && releaseMinutes != null) {
            int duration = releaseMinutes - checkInMinutes;
            if (duration < 0) duration += 24 * 60; // Handle next day
            
            if (summary.startsWith('STANDBY')) {
              // For STANDBY, duty time is 25% of the period
              duration = (duration * 0.25).round();
            }
            
            totalMinutes += duration;
          }
        }
      }
    }
    
    return _formatTime(totalMinutes);
  }

  Future<Map<String, dynamic>> _calculateDaysWorth(String dutyTimeStr, String nightDutyStr, String totalDutyTimeStr) async {
    try {
      final dataService = DataService();
      final role = await dataService.getRoleSelection();
      
      if (role == null) {
        return {
          'dutyValue': 0.0,
          'nightValue': 0.0,
          'totalWorth': 0.0,
          'rateType': 'Unknown',
          'error': 'Role not found'
        };
      }

      // Convert time strings to minutes
      final dutyMinutes = _timeStringToMinutes(dutyTimeStr);
      final nightMinutes = _timeStringToMinutes(nightDutyStr);
      final totalMinutes = _timeStringToMinutes(totalDutyTimeStr);
      
      // Determine if we're in overtime (over 100 hours total)
      final isOvertime = totalMinutes > (100 * 60);
      
      // Get appropriate rates
      final rates = role == 'CCM' ? SalaryRates.ccmRates : SalaryRates.sccmRates;
      final dutyRate = isOvertime ? rates['overtime']! : rates['duty']!;
      final nightRate = rates['nightHour']!;
      
      // Calculate values
      final dutyValue = (dutyMinutes / 60.0) * dutyRate;
      final nightValue = (nightMinutes / 60.0) * nightRate;
      final totalWorth = dutyValue + nightValue;
      
      return {
        'dutyValue': dutyValue,
        'nightValue': nightValue,
        'totalWorth': totalWorth,
        'rateType': isOvertime ? 'Overtime' : 'Regular',
        'role': role,
      };
    } catch (e) {
      return {
        'dutyValue': 0.0,
        'nightValue': 0.0,
        'totalWorth': 0.0,
        'rateType': 'Error',
        'error': e.toString()
      };
    }
  }

  int _timeStringToMinutes(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length == 2) {
      try {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        return hours * 60 + minutes;
      } catch (e) {
        return 0;
      }
    }
    return 0;
  }

  Widget _buildDaysWorthWidget(String dutyTime, String nightDuty, String totalDutyTime) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _calculateDaysWorth(dutyTime, nightDuty, totalDutyTime),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            color: Colors.white24,
            margin: EdgeInsets.only(top: 8),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Calculating...',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          );
        }

        final data = snapshot.data ?? {};
        final dutyValue = data['dutyValue'] ?? 0.0;
        final nightValue = data['nightValue'] ?? 0.0;
        final totalWorth = data['totalWorth'] ?? 0.0;

        return Card(
          color: Colors.white24,
          margin: const EdgeInsets.only(top: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Day\'s Worth',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Duty Value    : €${dutyValue.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                Text(
                  'Night Value   : €${nightValue.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                  Text(
                  'Total Worth   : €${totalWorth.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build NON-FLY event content (hotel/transport information)
  Widget _buildNonFlyEventContent(dynamic event) {
    final summary = event['summary'] as String? ?? '';
    final description = (event['description'] as String? ?? '').replaceAll('\\n', '\n');

    // Extract location from summary: NON-FLY (COV)
    final locationMatch = RegExp(r'NON-FLY \(([^)]+)\)').firstMatch(summary);
    final location = locationMatch != null ? locationMatch.group(1)! : 'Unknown';

    // Parse hotel and transport information from the description
    final lines = description.split('\n');
    String? transportTime;
    String? hotelCheckin;
    String? hotelCheckout;
    String? hotelName;
    String? hotelAddress;
    String? hotelPhone;
    String? transportCompany;
    String? transportPhone;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('Transport')) {
        // Extract transport times: "Transport   18:55  19:28        SERTUR TURIZM"
        final transportMatch = RegExp(r'Transport\s+(\d{2}:\d{2})\s+(\d{2}:\d{2})\s+(.+)').firstMatch(trimmed);
        if (transportMatch != null) {
          transportTime = '${transportMatch.group(1)} - ${transportMatch.group(2)}';
          transportCompany = transportMatch.group(3)!.trim();
        }
      } else if (trimmed.startsWith('Hotel')) {
        // Extract hotel times: "Hotel       19:28  05:17        DIVAN HOTEL"
        final hotelMatch = RegExp(r'Hotel\s+(\d{2}:\d{2})\s+(\d{2}:\d{2})\s+(.+)').firstMatch(trimmed);
        if (hotelMatch != null) {
          hotelCheckin = hotelMatch.group(1);
          hotelCheckout = hotelMatch.group(2);
          hotelName = hotelMatch.group(3)!.trim();
        }
      } else if (trimmed.startsWith('Address:')) {
        hotelAddress = trimmed.substring(9).trim();
      } else if (trimmed.startsWith('Phone:')) {
        // Extract phone number pattern
        final phoneMatch = RegExp(r'Phone:\s*([+\d\s\(\)]+)').firstMatch(trimmed);
        if (phoneMatch != null) {
          if (hotelPhone == null) {
            hotelPhone = phoneMatch.group(1)!.trim();
          } else {
            transportPhone = phoneMatch.group(1)!.trim();
          }
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.local_taxi,
              color: Colors.purple,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'LAYOVER TRANSPORT ($location)',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (transportTime != null && transportCompany != null) ...[
          Text(
            'Transport: $transportTime',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            'Company: $transportCompany',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          if (transportPhone != null)
            Text(
              'Phone: $transportPhone',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          const SizedBox(height: 8),
        ],
        if (hotelName != null) ...[
          Text(
            'Hotel: $hotelName',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          if (hotelCheckin != null && hotelCheckout != null)
            Text(
              'Check-in: $hotelCheckin - Check-out: $hotelCheckout',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          if (hotelAddress != null)
            Text(
              'Address: $hotelAddress',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          if (hotelPhone != null)
            Text(
              'Hotel Phone: $hotelPhone',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
        ],
      ],
    );
  }

  /// Build OFF event content
  Widget _buildOffEventContent(dynamic event) {
    final summary = event['summary'] as String? ?? '';
    final description = (event['description'] as String? ?? '').replaceAll('\\n', '\n');
    
    // Extract location from summary: OFF (AYT)
    final locationMatch = RegExp(r'OFF \(([^)]+)\)').firstMatch(summary);
    final location = locationMatch != null ? locationMatch.group(1)! : 'Unknown';

    // Parse off time from description
    final lines = description.split('\n');
    String? offTime;
    String? offEndTime;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('Off')) {
        // Extract off times: "Off         21:00  21:00/+1     AYT          OFF"
        final offMatch = RegExp(r'Off\s+(\d{2}:\d{2})\s+(\d{2}:\d{2}[/+\d]*)').firstMatch(trimmed);
        if (offMatch != null) {
          offTime = offMatch.group(1);
          offEndTime = offMatch.group(2);
        }
      }
    }

    // Calculate off duration
    String offDuration = '00:00';
    if (offTime != null && offEndTime != null) {
      offDuration = _calculateStandbyTime(offTime, offEndTime);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.free_breakfast,
              color: Colors.green,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'OFF DUTY ($location)',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (offTime != null)
          Text(
            'Off Start: $offTime',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        if (offEndTime != null)
          Text(
            'Off End: $offEndTime',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        const SizedBox(height: 8),
        Text(
          'Duration: $offDuration',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        Text(
          'Rest Time - No Duty Hours',
          style: const TextStyle(color: Colors.green, fontSize: 14),
        ),
      ],
    );
  }
}
